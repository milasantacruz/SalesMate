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

  /// Cachea todos los items de una pricelist para uso offline
  /// 
  /// Si hay conexión, obtiene todos los items desde Odoo y los guarda en cache.
  /// Si no hay conexión, no hace nada.
  /// 
  /// [pricelistId] ID de la pricelist/tarifa a cachear
  Future<void> cachePricelistItems(int pricelistId) async {
    try {
      print('💰 PRICELIST_REPO: Iniciando cacheo de items para pricelist $pricelistId...');
      
      // Verificar conectividad
      final connState = await netConn.checkNetConn();
      if (connState != netConnState.online) {
        print('⚠️ PRICELIST_REPO: Sin conexión - no se puede cachear items');
        return;
      }
      
      // Obtener todos los items de la pricelist
      final items = await getPricelistItems(pricelistId);
      
      if (items.isEmpty) {
        print('⚠️ PRICELIST_REPO: No se encontraron items para cachear');
        return;
      }
      
      // Serializar a JSON - asegurar que pricelistId esté correcto
      // Guardar pricelist_id como int para simplificar el cache
      final itemsJson = items.map((item) {
        final json = item.toJson();
        // Sobrescribir pricelist_id para guardarlo como int (más simple para cache)
        json['pricelist_id'] = pricelistId;
        return json;
      }).toList();
      
      // Guardar en cache
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'pricelist_items_$pricelistId';
      await kv.put(cacheKey, itemsJson);
      
      print('✅ PRICELIST_REPO: ${items.length} items cacheados para pricelist $pricelistId');
    } catch (e) {
      print('❌ PRICELIST_REPO: Error cacheando items de pricelist $pricelistId: $e');
      // No relanzar error - el cacheo no debe bloquear operaciones
    }
  }

  /// Obtiene los items de pricelist desde cache
  /// 
  /// Retorna lista vacía si no hay cache o si hay error.
  /// 
  /// [pricelistId] ID de la pricelist/tarifa
  List<PricelistItem> getCachedPricelistItems(int pricelistId) {
    try {
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'pricelist_items_$pricelistId';
      final cachedData = kv.get(cacheKey);
      
      print('🔍 PRICELIST_REPO: Cache data type: ${cachedData.runtimeType}');
      print('🔍 PRICELIST_REPO: Cache data is null: ${cachedData == null}');
      
      if (cachedData == null) {
        print('⚠️ PRICELIST_REPO: No hay cache para pricelist $pricelistId');
        return [];
      }
      
      if (cachedData is List) {
        print('🔍 PRICELIST_REPO: Cache data length: ${cachedData.length}');
        if (cachedData.isNotEmpty) {
          print('🔍 PRICELIST_REPO: Primer item del cache: ${cachedData.first}');
        }
        
        final items = cachedData
            .map((item) {
              try {
                // Asegurar que el JSON tenga el formato correcto
                final itemMap = Map<String, dynamic>.from(item as Map);
                // El pricelist_id puede venir como int (del cache) o como [id, '']
                // Normalizar al formato [id, ''] que espera fromJson
                if (itemMap.containsKey('pricelist_id')) {
                  final pidValue = itemMap['pricelist_id'];
                  if (pidValue is int) {
                    itemMap['pricelist_id'] = [pidValue, ''];
                  } else if (pidValue is List && pidValue.isNotEmpty) {
                    // Ya está en formato [id, ''], mantenerlo
                    itemMap['pricelist_id'] = pidValue;
                  } else {
                    // Si no tiene formato válido, usar el pricelistId del parámetro
                    itemMap['pricelist_id'] = [pricelistId, ''];
                  }
                } else {
                  // Si no está presente, agregarlo
                  itemMap['pricelist_id'] = [pricelistId, ''];
                }
                
                // Deserializar el item
                final deserializedItem = fromJson(itemMap);
                // Asegurar que pricelistId esté correcto (fromJson lo establece en 0)
                if (deserializedItem.pricelistId == 0) {
                  return deserializedItem.copyWith(pricelistId: pricelistId);
                }
                return deserializedItem;
              } catch (e) {
                print('⚠️ PRICELIST_REPO: Error deserializando item: $e');
                return null;
              }
            })
            .whereType<PricelistItem>()
            .toList();
        print('✅ PRICELIST_REPO: ${items.length} items obtenidos desde cache');
        return items;
      }
      
      print('⚠️ PRICELIST_REPO: Cache tiene formato incorrecto para pricelist $pricelistId');
      return [];
    } catch (e) {
      print('❌ PRICELIST_REPO: Error leyendo cache de pricelist $pricelistId: $e');
      return [];
    }
  }

  /// Limpia el cache de items de una pricelist
  /// 
  /// Útil para forzar refresco de datos.
  /// 
  /// [pricelistId] ID de la pricelist/tarifa
  Future<void> clearPricelistItemsCache(int pricelistId) async {
    try {
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'pricelist_items_$pricelistId';
      await kv.delete(cacheKey);
      print('✅ PRICELIST_REPO: Cache limpiado para pricelist $pricelistId');
    } catch (e) {
      print('❌ PRICELIST_REPO: Error limpiando cache de pricelist $pricelistId: $e');
    }
  }

  /// Obtiene el precio calculado para un producto desde la tarifa de la licencia
  /// 
  /// Lógica:
  /// 1. Obtiene tarifaId desde cache de licencia
  /// 2. Busca PricelistItem para el producto (cache primero, luego Odoo)
  /// 3. Si encuentra item: calcula precio con item.calculatePrice()
  /// 4. Si no encuentra: retorna null (usar basePrice como fallback)
  /// 
  /// [productId] ID del producto específico
  /// [productTmplId] ID de la plantilla del producto (puede ser null)
  /// [basePrice] Precio base del producto (product.listPrice)
  /// 
  /// Retorna el precio calculado o null si no hay item en tarifa
  Future<double?> getCalculatedPriceForProduct({
    required int productId,
    required int? productTmplId,
    required double basePrice,
  }) async {
    try {
      // 1. Obtener tarifaId desde cache de licencia
      final kv = getIt<CustomOdooKv>();
      final tarifaIdStr = kv.get('tarifaId');
      
      if (tarifaIdStr == null) {
        print('⚠️ PRICELIST_REPO: No hay tarifa_id configurada - usando precio base');
        return null; // Usar basePrice
      }
      
      final tarifaId = int.tryParse(tarifaIdStr.toString());
      if (tarifaId == null) {
        print('⚠️ PRICELIST_REPO: tarifa_id inválido - usando precio base');
        return null; // Usar basePrice
      }
      
      print('💰 PRICELIST_REPO: Calculando precio para producto $productId (tarifa: $tarifaId)');
      
      // 2. Buscar PricelistItem (primero desde cache)
      PricelistItem? item;
      
      // Intentar desde cache primero
      final cachedItems = getCachedPricelistItems(tarifaId);
      print('🔍 PRICELIST_REPO: Items en cache: ${cachedItems.length}');
      if (cachedItems.isNotEmpty) {
        print('🔍 PRICELIST_REPO: Primeros 3 items en cache:');
        for (var i = 0; i < cachedItems.length && i < 3; i++) {
          final cachedItem = cachedItems[i];
          print('   - Item ${cachedItem.id}: productId=${cachedItem.productId}, productTmplId=${cachedItem.productTmplId}');
        }
        // ✅ CORRECCIÓN: Buscar primero por product_tmpl_id (más común en Odoo)
        if (productTmplId != null) {
          try {
            item = cachedItems.firstWhere(
              (i) => i.productTmplId == productTmplId && i.productTmplId != null,
            );
            print('✅ PRICELIST_REPO: Item encontrado en cache por product_tmpl_id: ${item.id}');
          } catch (e) {
            // No encontrado por template, buscar por product_id específico (menos común)
            try {
              item = cachedItems.firstWhere(
                (i) => i.productId == productId && i.productId != null,
              );
              print('✅ PRICELIST_REPO: Item encontrado en cache por product_id: ${item.id}');
            } catch (e) {
              // No encontrado por ninguno
              print('⚠️ PRICELIST_REPO: No se encontró item en cache para producto $productId');
            }
          }
        } else {
          // Si no hay productTmplId, buscar solo por productId
          try {
            item = cachedItems.firstWhere(
              (i) => i.productId == productId && i.productId != null,
            );
            print('✅ PRICELIST_REPO: Item encontrado en cache por product_id: ${item.id}');
          } catch (e) {
            print('⚠️ PRICELIST_REPO: No se encontró item en cache para producto $productId');
          }
        }
      }
      
      // Si no se encontró en cache, intentar desde Odoo (solo si hay conexión)
      if (item == null) {
        final connState = await netConn.checkNetConn();
        if (connState == netConnState.online) {
          // ✅ CORRECCIÓN: Buscar primero por template (más común)
          if (productTmplId != null) {
            item = await getPricelistItemForProductTemplate(tarifaId, productTmplId);
          }
          
          // Si no hay por template, buscar por productId específico
          if (item == null) {
            item = await getPricelistItemForProduct(tarifaId, productId);
          }
          
          if (item != null) {
            print('✅ PRICELIST_REPO: Item obtenido desde Odoo: ${item.id}');
          }
        } else {
          print('⚠️ PRICELIST_REPO: Sin conexión y no hay cache - usando precio base');
        }
      }
      
      // 3. Calcular precio
      if (item != null) {
        final calculatedPrice = item.calculatePrice(basePrice);
        print('✅ PRICELIST_REPO: Precio calculado: $basePrice -> $calculatedPrice (item: ${item.id})');
        return calculatedPrice;
      } else {
        print('ℹ️ PRICELIST_REPO: No hay item en tarifa para producto $productId - usando precio base');
        return null; // Usar basePrice
      }
    } catch (e) {
      print('❌ PRICELIST_REPO: Error calculando precio para producto $productId: $e');
      return null; // En caso de error, usar basePrice
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
