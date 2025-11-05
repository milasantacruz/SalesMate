import 'package:odoo_repository/odoo_repository.dart';
import '../models/pricelist_item_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';
import '../../core/cache/custom_odoo_kv.dart';

/// Repository para manejar operaciones con Pricelist Items en Odoo
class PricelistRepository extends OfflineOdooRepository<PricelistItem> {
  final String modelName = 'product.pricelist.item';
  late final OdooCallQueueRepository _callQueue;

  PricelistRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache) {
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => [
        'id',
        'name',
        'product_id',
        'product_tmpl_id',
        'fixed_price',
        'percent_price',
        'min_quantity',
      ];

  @override
  PricelistItem fromJson(Map<String, dynamic> json) => PricelistItem.fromJson(json);

  /// Obtiene los items de una lista de precios específica
  Future<List<PricelistItem>> getPricelistItems(int pricelistId) async {
    try {
      print('💰 PRICELIST_REPO: Obteniendo items para pricelist $pricelistId...');
      
      final result = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['pricelist_id', '=', pricelistId]
          ],
          'fields': oFields,
          'order': 'min_quantity asc, id asc',
        },
      });

      final items = (result as List).map((item) => fromJson(item)).toList();
      print('✅ PRICELIST_REPO: ${items.length} items encontrados para pricelist $pricelistId');
      
      return items;
    } catch (e) {
      print('❌ PRICELIST_REPO: Error obteniendo items de pricelist $pricelistId: $e');
      return [];
    }
  }

  /// Obtiene el item de lista de precios para un producto específico
  Future<PricelistItem?> getPricelistItemForProduct(int pricelistId, int productId) async {
    try {
      print('💰 PRICELIST_REPO: Obteniendo item para producto $productId en pricelist $pricelistId...');
      
      final result = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['pricelist_id', '=', pricelistId],
            ['product_id', '=', productId],
            ['active', '=', true],
          ],
          'fields': oFields,
          'limit': 1,
        },
      });

      if (result is List && result.isNotEmpty) {
        final item = fromJson(result.first);
        print('✅ PRICELIST_REPO: Item encontrado para producto $productId: ${item.name}');
        return item;
      }
      
      print('⚠️ PRICELIST_REPO: No se encontró item específico para producto $productId');
      return null;
    } catch (e) {
      print('❌ PRICELIST_REPO: Error obteniendo item para producto $productId: $e');
      return null;
    }
  }

  /// Obtiene el item de lista de precios para una plantilla de producto
  Future<PricelistItem?> getPricelistItemForProductTemplate(int pricelistId, int productTmplId) async {
    try {
      print('💰 PRICELIST_REPO: Obteniendo item para plantilla $productTmplId en pricelist $pricelistId...');
      
      final result = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['pricelist_id', '=', pricelistId],
            ['product_tmpl_id', '=', productTmplId],
            ['active', '=', true],
          ],
          'fields': oFields,
          'limit': 1,
        },
      });

      if (result is List && result.isNotEmpty) {
        final item = fromJson(result.first);
        print('✅ PRICELIST_REPO: Item encontrado para plantilla $productTmplId: ${item.name}');
        return item;
      }
      
      print('⚠️ PRICELIST_REPO: No se encontró item específico para plantilla $productTmplId');
      return null;
    } catch (e) {
      print('❌ PRICELIST_REPO: Error obteniendo item para plantilla $productTmplId: $e');
      return null;
    }
  }

  /// Obtiene la lista de precios de un partner
  Future<int?> getPartnerPricelistId(int partnerId) async {
    try {
      print('💰 PRICELIST_REPO: Obteniendo pricelist para partner $partnerId...');
      
      final result = await env.orpc.callKw({
        'model': 'res.partner',
        'method': 'read',
        'args': [[partnerId]],
        'kwargs': {
          'fields': ['property_product_pricelist'],
        },
      });

      if (result is List && result.isNotEmpty) {
        final data = result.first as Map<String, dynamic>;
        final pricelistValue = data['property_product_pricelist'];
        
        if (pricelistValue is List && pricelistValue.isNotEmpty) {
          final pricelistId = (pricelistValue[0] as num).toInt();
          print('✅ PRICELIST_REPO: Pricelist encontrado para partner $partnerId: $pricelistId');
          return pricelistId;
        }
      }
      
      print('⚠️ PRICELIST_REPO: No se encontró pricelist para partner $partnerId');
      return null;
    } catch (e) {
      print('❌ PRICELIST_REPO: Error obteniendo pricelist para partner $partnerId: $e');
      return null;
    }
  }

  /// Obtiene el nombre de una tarifa/pricelist por su ID
  /// Primero intenta leer desde cache (para modo offline)
  /// Si no está en cache y hay conexión, obtiene desde Odoo y guarda en cache
  Future<String?> getPricelistName(int pricelistId) async {
    try {
      print('💰 PRICELIST_REPO: Obteniendo nombre de pricelist $pricelistId...');
      
      // 1. Intentar leer desde cache primero (modo offline)
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'pricelist_name_$pricelistId';
      final cachedName = kv.get(cacheKey);
      
      if (cachedName != null && cachedName is String) {
        print('✅ PRICELIST_REPO: Nombre obtenido desde cache: $cachedName');
        return cachedName;
      }
      
      print('💰 PRICELIST_REPO: No encontrado en cache, intentando desde Odoo...');
      
      // 2. Verificar conectividad antes de hacer llamada a Odoo
      final netConn = getIt<NetworkConnectivity>();
      final connState = await netConn.checkNetConn();
      
      if (connState != netConnState.online) {
        print('⚠️ PRICELIST_REPO: Sin conexión y no hay cache - retornando null');
        return null;
      }
      
      // 3. Obtener desde Odoo (solo si hay conexión)
      final result = await env.orpc.callKw({
        'model': 'product.pricelist',
        'method': 'read',
        'args': [[pricelistId]],
        'kwargs': {
          'fields': ['name'],
        },
      });

      if (result is List && result.isNotEmpty) {
        final data = result.first as Map<String, dynamic>;
        final name = data['name'] as String?;
        
        if (name != null && name.isNotEmpty) {
          // Guardar en cache para uso offline futuro
          await kv.put(cacheKey, name);
          print('✅ PRICELIST_REPO: Nombre obtenido desde Odoo y guardado en cache: $name');
          return name;
        }
      }
      
      print('⚠️ PRICELIST_REPO: No se encontró nombre para pricelist $pricelistId');
      return null;
    } catch (e) {
      print('❌ PRICELIST_REPO: Error obteniendo nombre de pricelist $pricelistId: $e');
      
      // En caso de error, intentar retornar desde cache como fallback
      try {
        final kv = getIt<CustomOdooKv>();
        final cacheKey = 'pricelist_name_$pricelistId';
        final cachedName = kv.get(cacheKey);
        if (cachedName != null && cachedName is String) {
          print('✅ PRICELIST_REPO: Fallback - usando nombre desde cache: $cachedName');
          return cachedName;
        }
      } catch (cacheError) {
        print('⚠️ PRICELIST_REPO: Error accediendo cache como fallback: $cacheError');
      }
      
      return null;
    }
  }

  @override
  Future<List<dynamic>> searchRead() async {
    // Implementación básica para compatibilidad
    return [];
  }

  /// Crea un nuevo pricelist item (offline/online según conectividad)
  Future<String> createPricelistItem(PricelistItem item) async {
    return await _callQueue.createRecord(modelName, item.toJson());
  }

  /// Actualiza un pricelist item existente (offline/online según conectividad)
  Future<void> updatePricelistItem(PricelistItem item) async {
    await _callQueue.updateRecord(modelName, item.id, item.toJson());
  }

  /// Elimina permanentemente un pricelist item (offline/online según conectividad)
  Future<void> deletePricelistItem(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }
}
