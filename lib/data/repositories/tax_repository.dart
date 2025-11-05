import 'package:odoo_repository/odoo_repository.dart';
import '../models/tax_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';
import '../../core/cache/custom_odoo_kv.dart';

/// Repository para manejar operaciones con Taxes (account.tax) en Odoo
class TaxRepository extends OfflineOdooRepository<Tax> {
  final String modelName = 'account.tax';
  late final OdooCallQueueRepository _callQueue;

  TaxRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache) {
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => Tax.oFields;

  @override
  Tax fromJson(Map<String, dynamic> json) => Tax.fromJson(json);

  /// Implementación requerida por OfflineOdooRepository
  /// En este caso, no se usa directamente ya que cacheamos por companyId
  @override
  Future<List<dynamic>> searchRead() async {
    // Este método no se usa directamente para TaxRepository
    // En su lugar, usamos cacheTaxes() y getCachedTaxes()
    return [];
  }

  /// Cachea todos los impuestos de venta para una company específica
  /// 
  /// Si hay conexión, obtiene todos los impuestos desde Odoo y los guarda en cache.
  /// Si no hay conexión, no hace nada.
  /// 
  /// [companyId] ID de la empresa/company
  Future<void> cacheTaxes(int companyId) async {
    try {
      print('🏢 TAX_REPO: Iniciando cacheo de impuestos para company $companyId...');
      
      // Verificar conectividad
      final connState = await netConn.checkNetConn();
      if (connState != netConnState.online) {
        print('⚠️ TAX_REPO: Sin conexión - no se puede cachear impuestos');
        return;
      }
      
      // Obtener todos los impuestos de venta para esta company
      final result = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['active', '=', true],
            ['company_id', '=', companyId],
            ['type_tax_use', '=', 'sale'],
          ],
          'fields': oFields,
          'order': 'id asc',
        },
      });

      final taxes = (result as List).map((item) => fromJson(item)).toList();
      
      if (taxes.isEmpty) {
        print('⚠️ TAX_REPO: No se encontraron impuestos para cachear');
        return;
      }
      
      // Serializar a JSON - asegurar que companyId esté correcto
      final taxesJson = taxes.map((tax) {
        final json = tax.toJson();
        // Asegurar que company_id esté guardado como int para simplificar el cache
        json['company_id'] = companyId;
        return json;
      }).toList();
      
      // Guardar en cache
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'taxes_$companyId';
      await kv.put(cacheKey, taxesJson);
      
      print('✅ TAX_REPO: ${taxes.length} impuestos cacheados para company $companyId');
      
      // Verificar que se guardó correctamente
      final verifyCache = kv.get(cacheKey);
      if (verifyCache is List) {
        print('🔍 TAX_REPO: Verificación cache - impuestos guardados: ${verifyCache.length}');
        if (verifyCache.isNotEmpty) {
          print('🔍 TAX_REPO: Primer impuesto del cache: ${verifyCache.first}');
        }
      }
    } catch (e) {
      print('❌ TAX_REPO: Error cacheando impuestos para company $companyId: $e');
      // No relanzar error - el cacheo no debe bloquear operaciones
    }
  }

  /// Obtiene los impuestos desde cache
  /// 
  /// Retorna lista vacía si no hay cache o si hay error.
  /// 
  /// [companyId] ID de la empresa/company
  List<Tax> getCachedTaxes(int companyId) {
    try {
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'taxes_$companyId';
      final cachedData = kv.get(cacheKey);
      
      print('🔍 TAX_REPO: Cache data type: ${cachedData.runtimeType}');
      print('🔍 TAX_REPO: Cache data is null: ${cachedData == null}');
      
      if (cachedData == null) {
        print('⚠️ TAX_REPO: No hay cache para company $companyId');
        return [];
      }
      
      if (cachedData is List) {
        print('🔍 TAX_REPO: Cache data length: ${cachedData.length}');
        if (cachedData.isNotEmpty) {
          print('🔍 TAX_REPO: Primer impuesto del cache: ${cachedData.first}');
        }
        
        final taxes = cachedData
            .map((item) {
              try {
                // Asegurar que el JSON tenga el formato correcto
                final itemMap = Map<String, dynamic>.from(item as Map);
                // Normalizar company_id al formato [id, ''] que espera fromJson
                if (itemMap.containsKey('company_id')) {
                  final cidValue = itemMap['company_id'];
                  if (cidValue is int) {
                    itemMap['company_id'] = [cidValue, ''];
                  } else if (cidValue is List && cidValue.isNotEmpty) {
                    // Ya está en formato [id, ''], mantenerlo
                    itemMap['company_id'] = cidValue;
                  } else {
                    // Si no tiene formato válido, usar el companyId del parámetro
                    itemMap['company_id'] = [companyId, ''];
                  }
                } else {
                  // Si no está presente, agregarlo
                  itemMap['company_id'] = [companyId, ''];
                }
                
                // Deserializar el impuesto
                final deserializedTax = fromJson(itemMap);
                // Asegurar que companyId esté correcto
                if (deserializedTax.companyId == null || deserializedTax.companyId != companyId) {
                  return deserializedTax.copyWith(companyId: companyId);
                }
                return deserializedTax;
              } catch (e) {
                print('⚠️ TAX_REPO: Error deserializando impuesto: $e');
                return null;
              }
            })
            .whereType<Tax>()
            .toList();
        print('✅ TAX_REPO: ${taxes.length} impuestos obtenidos desde cache');
        return taxes;
      }
      
      print('⚠️ TAX_REPO: Cache tiene formato incorrecto para company $companyId');
      return [];
    } catch (e) {
      print('❌ TAX_REPO: Error leyendo cache de impuestos para company $companyId: $e');
      return [];
    }
  }

  /// Obtiene un impuesto específico por ID desde cache
  /// 
  /// Retorna null si no se encuentra.
  /// 
  /// [taxId] ID del impuesto
  /// [companyId] ID de la empresa/company
  Tax? getTaxById(int taxId, int companyId) {
    try {
      final cachedTaxes = getCachedTaxes(companyId);
      final tax = cachedTaxes.firstWhere(
        (t) => t.id == taxId,
        orElse: () => throw StateError('Tax not found'),
      );
      print('✅ TAX_REPO: Impuesto encontrado: ${tax.name} (ID: $taxId)');
      return tax;
    } catch (e) {
      print('⚠️ TAX_REPO: Impuesto $taxId no encontrado en cache para company $companyId');
      return null;
    }
  }

  /// Limpia el cache de impuestos para una company
  /// 
  /// Útil para forzar refresco de datos.
  /// 
  /// [companyId] ID de la empresa/company
  Future<void> clearTaxesCache(int companyId) async {
    try {
      final kv = getIt<CustomOdooKv>();
      final cacheKey = 'taxes_$companyId';
      await kv.delete(cacheKey);
      print('✅ TAX_REPO: Cache limpiado para company $companyId');
    } catch (e) {
      print('❌ TAX_REPO: Error limpiando cache de impuestos para company $companyId: $e');
    }
  }
}

