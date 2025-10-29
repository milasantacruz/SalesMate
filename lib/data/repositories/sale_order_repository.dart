import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/sale_order_model.dart';
import '../models/sale_order_line_model.dart';
import '../models/order_totals_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import '../../core/di/injection_container.dart';
import '../../core/audit/audit_helper.dart';
import '../../core/tenant/tenant_storage_config.dart';
import 'odoo_call_queue_repository.dart';

/// Repository para manejar operaciones con Sale Orders en Odoo con soporte offline
class SaleOrderRepository extends OfflineOdooRepository<SaleOrder> {
  final String modelName = 'sale.order';
  late final OdooCallQueueRepository _callQueue;
  String _searchTerm = '';
  String? _state;
  int _limit = 80;
  int _offset = 0;
  
  // Cache para totales calculados
  final Map<String, OrderTotals> _totalsCache = {};

  SaleOrderRepository(
    OdooEnvironment env,
    NetworkConnectivity netConn,
    OdooKv cache, {
    super.tenantCache,
  }) : super(env, netConn, cache) {
    // Inicializar _callQueue desde dependency injection
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => SaleOrder.oFields;

  @override
  SaleOrder fromJson(Map<String, dynamic> json) => SaleOrder.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    try {
      print('🛒 SALE_ORDER_REPO: Buscando órdenes de venta...');
      
      final domain = _buildDomain();
      print('🔍 SALE_ORDER_REPO: Domain: $domain');
      print('📋 SALE_ORDER_REPO: Fields: $oFields');
      print('📊 SALE_ORDER_REPO: Limit: $_limit, Offset: $_offset');
      
      // Primero buscar los IDs
      final searchResult = await env.orpc.callKw({
        'model': modelName,
        'method': 'search',
        'args': [],
        'kwargs': {
          'domain': domain,
          'limit': _limit,
          'offset': _offset,
          'order': 'date_order desc',
        },
      });
      
      final ids = searchResult as List<dynamic>;
      print('🔍 SALE_ORDER_REPO: IDs encontrados: $ids');
      
      if (ids.isEmpty) {
        print('⚠️ SALE_ORDER_REPO: No se encontraron IDs');
        return [];
      }
      
      // Luego leer los datos de esos IDs
      final readResult = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [ids],
        'kwargs': {
          'fields': oFields,
        },
      });
      
      final records = readResult as List<dynamic>;
      print('✅ SALE_ORDER_REPO: ${records.length} órdenes encontradas');
      
      if (records.isNotEmpty) {
        print('📄 SALE_ORDER_REPO: Primera orden: ${records.first}');
      }
      
      return records;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error en searchRead: $e');
      print('❌ SALE_ORDER_REPO: Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Enriquecer datos de orden para creación con auditoría automática
  Future<Map<String, dynamic>> _enrichOrderDataForCreate(Map<String, dynamic> originalData) async {
    final enrichedData = Map<String, dynamic>.from(originalData);
    
    // Inyectar datos de auditoría automático
    final auditData = AuditHelper.getCreateAuditData();
    enrichedData.addAll(auditData);
    
    print('🔍 SALE_ORDER_REPO: Datos de auditoría incluidos: $auditData');
    
    // Inyectar pricelist_id si no viene, usando el partner
    if (!enrichedData.containsKey('pricelist_id') && enrichedData['partner_id'] != null) {
      final partnerId = (enrichedData['partner_id'] as num).toInt();
      final pricelistId = await _getPartnerPricelistId(partnerId);
      if (pricelistId != null) {
        enrichedData['pricelist_id'] = pricelistId;
        print('🧮 SALE_ORDER_REPO: Inyectado pricelist_id=$pricelistId para partner $partnerId');
      }
    }
    
    return enrichedData;
  }

  /// Enriquecer datos de orden para actualización con auditoría automática
  Map<String, dynamic> _enrichOrderDataForWrite(Map<String, dynamic> originalData) {
    final enrichedData = Map<String, dynamic>.from(originalData);
    
    // NO inyectar user_id en actualizaciones - Odoo no permite modificar este campo
    // Solo agregar otros datos de auditoría si es necesario
    print('🔍 SALE_ORDER_REPO: Datos de actualización sin user_id (campo protegido)');
    
    return enrichedData;
  }

  /// Construye el dominio de búsqueda basado en filtros
  List<dynamic> _buildDomain() {
    final domain = <dynamic>[];
    
    // Filtro por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      domain.addAll([
        '|',
        ['name', 'ilike', _searchTerm],
        ['partner_id', 'ilike', _searchTerm],
      ]);
    }
    
    // Filtro por estado
    if (_state != null && _state!.isNotEmpty) {
      domain.add(['state', '=', _state]);
    }
    
    // Si no hay filtros, devolver dominio vacío para obtener todas las órdenes
    // Si hay filtros, devolver el dominio construido
    return domain;
  }

  /// Configura parámetros de búsqueda y filtrado
  void setSearchParams({
    String searchTerm = '',
    String? state,
    int limit = 80,
    int offset = 0,
  }) {
    _searchTerm = searchTerm;
    _state = state;
    _limit = limit;
    _offset = offset;
  }

  @override
  Future<void> fetchRecords() async {
    try {
      print('🛒 SALE_ORDER_REPO: Fetching records from server...');
      
      if (await netConn.checkNetConn() == netConnState.online) {
        print('🌐 SALE_ORDER_REPO: Online - fetching from server');
        final serverRecords = await _getAllRecordsFromServer();
        
        // Guardar en caché local (guardar datos JSON, no objetos)
        final jsonData = serverRecords.map((record) => record.toJson()).toList();
        
        // ✅ FIX: Usar tenantCache cuando esté disponible
        if (tenantCache != null) {
          await tenantCache!.put('sale_orders', jsonData);
          print('💾 SALE_ORDER_REPO: Records cached locally usando tenantCache');
        } else {
          await cache.put('sale_orders', jsonData);
          print('💾 SALE_ORDER_REPO: Records cached locally usando cache normal');
        }
        
        // Aplicar filtros locales
        final filteredRecords = _applyLocalFilters(serverRecords);
        latestRecords = filteredRecords;
        
      } else {
        print('📱 SALE_ORDER_REPO: Offline - loading from cache');
        await loadRecords();
      }
      
      print('✅ SALE_ORDER_REPO: ${latestRecords.length} records loaded');
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error fetching records: $e');
      // En caso de error, intentar cargar desde caché
      await loadRecords();
    }
  }

  /// Obtiene todos los registros del servidor
  Future<List<SaleOrder>> _getAllRecordsFromServer() async {
    try {
      // ✅ PASO 1: Obtener órdenes básicas del servidor
      final result = await searchRead();
      final basicOrders = result.map((record) => fromJson(record)).toList();
      print('✅ SALE_ORDER_REPO: ${basicOrders.length} órdenes básicas obtenidas');
      
      // ✅ PASO 2: Enriquecer cada orden con sus líneas (en paralelo)
      print('🔍 SALE_ORDER_REPO: Enriqueciendo órdenes con líneas...');
      final enrichedOrders = await Future.wait(
        basicOrders.map((order) => _enrichOrderWithLines(order)),
      );
      
      final ordersWithLines = enrichedOrders.where((o) => o.orderLines.isNotEmpty).length;
      print('✅ SALE_ORDER_REPO: $ordersWithLines/${enrichedOrders.length} órdenes enriquecidas con líneas');
      
      return enrichedOrders;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error getting records from server: $e');
      // ✅ FIX: Lanzar error para que fetchRecords() lo capture y llame a loadRecords()
      rethrow;
    }
  }

  /// ✅ BUG-007: Enriquece una orden con sus líneas desde el servidor
  Future<SaleOrder> _enrichOrderWithLines(SaleOrder order) async {
    if (order.orderLineIds.isEmpty) {
      return order;
    }
    
    try {
      final linesResult = await env.orpc.callKw({
        'model': 'sale.order.line',
        'method': 'read',
        'args': [order.orderLineIds],
        'kwargs': {
          'fields': [
            'id',
            'product_id',
            'name',
            'product_uom_qty',
            'price_unit',
            'price_subtotal',
            'tax_id'
          ],
        },
      });
      
      if (linesResult is List) {
        final orderLines = linesResult
            .map((lineData) => SaleOrderLine.fromJson(lineData))
            .toList();
        print('✅ SALE_ORDER_REPO: Órden ${order.id} enriquecida con ${orderLines.length} líneas');
        return order.copyWith(orderLines: orderLines);
      }
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: Error enriqueciendo orden ${order.id}: $e');
      // Fallback: retornar orden sin líneas en caso de error
    }
    
    return order;
  }

  /// Aplica filtros locales a los registros
  List<SaleOrder> _applyLocalFilters(List<SaleOrder> allRecords) {
    var filteredRecords = allRecords;
    
    // Filtro por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      filteredRecords = filteredRecords.where((order) {
        final searchLower = _searchTerm.toLowerCase();
        return order.name.toLowerCase().contains(searchLower) ||
               (order.partnerName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }
    
    // Filtro por estado
    if (_state != null && _state!.isNotEmpty) {
      filteredRecords = filteredRecords.where((order) => order.state == _state).toList();
    }
    
    return filteredRecords;
  }

  Future<void> loadRecords() async {
    try {
      print('📱 SALE_ORDER_REPO: Loading records from cache...');
      
      // Intentar primero con tenantCache
      final cacheKey = 'sale_orders';
      List<dynamic>? cachedData;
      
      if (tenantCache != null) {
        cachedData = tenantCache!.get(cacheKey) as List?;
      }
      
      // Si no se encontró en tenantCache, intentar con cache normal
      if (cachedData == null) {
        cachedData = cache.get(cacheKey) as List<dynamic>?;
      }
      
      if (cachedData != null) {
        
        // Convertir cada record a Map<String, dynamic> para evitar errores de tipo
        final cachedRecords = cachedData.map((record) {
          try {
            if (record is Map) {
              // Limpiar el Map para asegurar tipos correctos
              final cleanedRecord = <String, dynamic>{};
              
              for (final key in record.keys) {
                final value = record[key];
                
                // Caso especial: order_line puede tener diferentes formatos
                if (key == 'order_line') {
                  if (value is List) {
                    final ids = <int>[];
                    for (final item in value) {
                      if (item is int) {
                        // Ya es un ID
                        ids.add(item);
                      } else if (item is List && item.length == 3 && item[0] == 0 && item[1] == 0) {
                        // Es una tupla de Odoo: [0, 0, {id: 123, ...}]
                        final data = item[2];
                        if (data is Map && data.containsKey('id')) {
                          final id = data['id'];
                          if (id is int) {
                            ids.add(id);
                          }
                        }
                      } else if (item is Map) {
                        // Es un registro completo: {id: 123, ...}
                        final id = item['id'];
                        if (id is int) {
                          ids.add(id);
                        }
                      }
                    }
                    cleanedRecord[key] = ids;
                  } else {
                    cleanedRecord[key] = [];
                  }
                } else if (key == 'id') {
                  // ID puede ser temporal (negativo) o real (positivo)
                  cleanedRecord[key] = value;
                } else if (value is List && value.isNotEmpty) {
                  // Es un campo Many2one: [id, name]
                  if (value.length == 2 && value[0] is num) {
                    cleanedRecord[key] = value; // Mantener como List
                  } else {
                    cleanedRecord[key] = value;
                  }
                } else if (value is num) {
                  cleanedRecord[key] = value;
                } else if (value is String || value is bool || value == null) {
                  cleanedRecord[key] = value;
                } else {
                  cleanedRecord[key] = value.toString();
                }
              }
              
              return fromJson(cleanedRecord);
            } else {
              throw Exception('Invalid record format in cache: ${record.runtimeType}');
            }
          } catch (e) {
            print('⚠️ SALE_ORDER_REPO: Error parseando record: $e');
            print('⚠️ SALE_ORDER_REPO: Record tipo: ${record.runtimeType}');
            print('⚠️ SALE_ORDER_REPO: Record contenido: $record');
            rethrow;
          }
        }).toList();
        
        // DIAG_BUG_008: métricas de order_lines en cache antes de filtros
        try {
          final total = cachedRecords.length;
          final withLines = cachedRecords.where((r) => (r.orderLines).isNotEmpty).length;
          print('DIAG_BUG_008 loadRecords(): cachedRecords total=$total, withLines=$withLines');
        } catch (_) {}

        latestRecords = _applyLocalFilters(cachedRecords);
        try {
          final total = latestRecords.length;
          final withLines = latestRecords.where((r) => r.orderLines.isNotEmpty).length;
          print('DIAG_BUG_008 loadRecords(): latestRecords total=$total, withLines=$withLines');
          // DIAG: muestrear primeros 3 para amount_total
          for (var i = 0; i < (total < 3 ? total : 3); i++) {
            final o = latestRecords[i];
            print('DIAG_PRICE loadRecords sample[$i]: id=${o.id}, amount_total=${o.amountTotal}, lines=${o.orderLines.length}');
          }
        } catch (_) {}
        print('✅ SALE_ORDER_REPO: ${latestRecords.length} records loaded from cache');
      } else {
        latestRecords = [];
        print('⚠️ SALE_ORDER_REPO: No cached data found');
      }
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error loading from cache: $e');
      latestRecords = [];
    }
  }

  /// Guarda en cache local ANTES de enviar al servidor
  Future<String> _saveToLocalCacheFirst(Map<String, dynamic> orderData) async {
    try {
      final tempId = DateTime.now().millisecondsSinceEpoch;
      
      // ✅ ENRIQUECER: Convertir campos Many2one de int a [id, name]
      final enrichedOrderData = await _enrichMany2oneFieldsForCache(orderData);
      
      // ✅ GENERAR nombre temporal para órdenes offline
      final tempOrderNumber = 'TEMPO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      
      final tempOrder = Map<String, dynamic>.from(enrichedOrderData)
        ..putIfAbsent('id', () => -tempId)  // ID temporal negativo
        ..putIfAbsent('state', () => 'draft')  // Estado temporal
        ..putIfAbsent('name', () => tempOrderNumber);  // ✅ Nombre temporal
      
      // ✅ BUG-008 (extensión): si vienen líneas desde la UI, preservarlas en cache
      if (enrichedOrderData['order_lines'] is List) {
        tempOrder['order_lines'] = List.from(enrichedOrderData['order_lines'] as List);
        print('DIAG_BUG_008 _saveToLocalCacheFirst(): preservando order_lines=${(tempOrder['order_lines'] as List).length} en cache temporal');
      }

      // DIAG: Precio inicial del registro temporal
      try {
        final amt = tempOrder['amount_total'];
        final linesLen = (tempOrder['order_lines'] as List?)?.length ?? 0;
        print('DIAG_PRICE _saveToLocalCacheFirst: amount_total=$amt, order_lines.len=$linesLen');
      } catch (_) {}

      // ✅ BUG Precio en tarjeta: calcular amount_total local si falta
      if (tempOrder['amount_total'] == null) {
        try {
          double computedTotal = 0.0;
          final lines = tempOrder['order_lines'] as List?;
          if (lines != null && lines.isNotEmpty) {
            for (final line in lines) {
              if (line is Map) {
                final m = Map<String, dynamic>.from(line);
                final subtotal = (m['price_subtotal'] as num?)?.toDouble();
                if (subtotal != null) {
                  computedTotal += subtotal;
                } else {
                  final qty = (m['product_uom_qty'] as num?)?.toDouble() ?? 0.0;
                  final price = (m['price_unit'] as num?)?.toDouble() ?? 0.0;
                  computedTotal += qty * price;
                }
              }
            }
          }
          tempOrder['amount_total'] = computedTotal;
          print('DIAG_PRICE _saveToLocalCacheFirst: amount_total computed=$computedTotal');
        } catch (e) {
          print('DIAG_PRICE _saveToLocalCacheFirst: error computing amount_total: $e');
        }
      }
      
      print('✅ SALE_ORDER: Datos enriquecidos para cache - Many2one fields convertidos');
      print('✅ SALE_ORDER: Nombre temporal asignado: $tempOrderNumber');
      
      // Obtener cache actual
      final cacheKey = 'sale_orders';
      List<dynamic> cachedData = [];
      
      if (tenantCache != null) {
        cachedData = tenantCache!.get(cacheKey, defaultValue: []) as List? ?? [];
        print('💾 SALE_ORDER: Cache actual tiene ${cachedData.length} elementos');
      } else {
        cachedData = cache.get(cacheKey, defaultValue: []) as List<dynamic>? ?? [];
        print('💾 SALE_ORDER: Cache normal tiene ${cachedData.length} elementos');
      }
      
      // Agregar al inicio de la lista
      cachedData.insert(0, tempOrder);
      
      // Guardar de vuelta en cache
      if (tenantCache != null) {
        await tenantCache!.put(cacheKey, cachedData);
        print('💾 SALE_ORDER: Guardado en tenantCache');
      } else {
        await cache.put(cacheKey, cachedData);
        print('💾 SALE_ORDER: Guardado en cache normal');
      }
      
      print('✅ SALE_ORDER: Guardado localmente con ID temporal: -$tempId');
      return tempId.toString();
    } catch (e) {
      print('⚠️ SALE_ORDER: Error guardando en cache local: $e');
      // Retornar timestamp como fallback
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }
  
  /// ✅ NUEVO: Enriquece campos Many2one de int a [id, name] para cache
  Future<Map<String, dynamic>> _enrichMany2oneFieldsForCache(Map<String, dynamic> orderData) async {
    final enriched = Map<String, dynamic>.from(orderData);
    
    // Enriquecer partner_id
    if (enriched.containsKey('partner_id') && enriched['partner_id'] is int) {
      final partnerId = enriched['partner_id'] as int;
      final partnerName = enriched['partner_name'] as String? ?? 'Unknown Partner';
      enriched['partner_id'] = [partnerId, partnerName];
      print('🔧 SALE_ORDER: Enriquecido partner_id: $partnerId → [$partnerId, $partnerName]');
    }
    
    // Enriquecer partner_shipping_id
    if (enriched.containsKey('partner_shipping_id') && enriched['partner_shipping_id'] is int) {
      final shippingId = enriched['partner_shipping_id'] as int;
      final shippingName = enriched['partner_shipping_name'] as String? ?? 'Unknown Address';
      enriched['partner_shipping_id'] = [shippingId, shippingName];
      print('🔧 SALE_ORDER: Enriquecido partner_shipping_id: $shippingId → [$shippingId, $shippingName]');
    }
    
    // Enriquecer user_id
    if (enriched.containsKey('user_id') && enriched['user_id'] is int) {
      final userId = enriched['user_id'] as int;
      enriched['user_id'] = [userId, 'User #$userId'];
      print('🔧 SALE_ORDER: Enriquecido user_id: $userId → [$userId, User #$userId]');
    }
    
    return enriched;
  }

  /// Actualiza ID temporal con ID real del servidor en cache
  Future<void> _updateCacheWithRealId(String tempIdStr, int serverId) async {
    try {
      final tempId = -int.parse(tempIdStr);
      
      final cacheKey = 'sale_orders';
      List<dynamic>? cachedData;
      
      if (tenantCache != null) {
        cachedData = tenantCache!.get(cacheKey) as List?;
      } else {
        cachedData = cache.get(cacheKey) as List<dynamic>?;
      }
      
      if (cachedData != null) {
        final index = cachedData.indexWhere((o) => o is Map && o['id'] == tempId);
        if (index >= 0) {
          // Actualizar con ID real
          final updatedOrder = Map<String, dynamic>.from(cachedData[index])
            ..['id'] = serverId
            ..['state'] = 'sent';
          
          cachedData[index] = updatedOrder;
          
          if (tenantCache != null) {
            await tenantCache!.put(cacheKey, cachedData);
          } else {
            await cache.put(cacheKey, cachedData);
          }
          
          print('✅ SALE_ORDER: Cache actualizado: temporal $tempId → real $serverId');
        } else {
          print('⚠️ SALE_ORDER: No se encontró orden temporal $tempId en cache');
        }
      }
    } catch (e) {
      print('⚠️ SALE_ORDER: Error actualizando cache: $e');
    }
  }

  /// ✅ BUG-007: Actualiza cache con orden completa (incluyendo líneas)
  Future<void> _updateCacheWithCompleteOrder(SaleOrder completeOrder) async {
    try {
      final cacheKey = 'sale_orders';
      List<dynamic>? cachedData;
      
      if (tenantCache != null) {
        cachedData = tenantCache!.get(cacheKey) as List?;
      } else {
        cachedData = cache.get(cacheKey) as List<dynamic>?;
      }
      
      if (cachedData != null) {
        print('DIAG_BUG_008 updateCacheWithCompleteOrder(): before put - orderId=${completeOrder.id}, lines=${completeOrder.orderLines.length}');
        final index = cachedData.indexWhere((o) => o is Map && o['id'] == completeOrder.id);
        if (index >= 0) {
          // Actualizar con orden completa (incluye líneas)
          cachedData[index] = completeOrder.toJson();
          
          if (tenantCache != null) {
            await tenantCache!.put(cacheKey, cachedData);
          } else {
            await cache.put(cacheKey, cachedData);
          }
          
          print('✅ SALE_ORDER: Cache actualizado con líneas completas para orden ${completeOrder.id}');
          print('DIAG_BUG_008 updateCacheWithCompleteOrder(): after put - cache length=${cachedData.length}');
        } else {
          print('⚠️ SALE_ORDER: No se encontró orden ${completeOrder.id} en cache');
        }
      }
    } catch (e) {
      print('⚠️ SALE_ORDER: Error actualizando cache con líneas: $e');
    }
  }

  /// Actualiza amount_total en memoria y cache persistente para una orden dada
  Future<void> updateAmountTotalInCache(int orderId, double amountTotal) async {
    try {
      // Actualizar en memoria
      final idx = latestRecords.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        latestRecords[idx] = latestRecords[idx].copyWith(amountTotal: amountTotal);
        print('DIAG_PRICE updateAmountTotalInCache: memoria actualizada id=$orderId total=$amountTotal');
      }

      // Actualizar en cache persistente
      final cacheKey = 'sale_orders';
      List<dynamic>? cachedData;
      if (tenantCache != null) {
        cachedData = tenantCache!.get(cacheKey) as List?;
      } else {
        cachedData = cache.get(cacheKey) as List<dynamic>?;
      }
      if (cachedData != null) {
        final cidx = cachedData.indexWhere((o) => o is Map && o['id'] == orderId);
        if (cidx >= 0) {
          final updated = Map<String, dynamic>.from(cachedData[cidx])
            ..['amount_total'] = amountTotal;
          cachedData[cidx] = updated;
          if (tenantCache != null) {
            await tenantCache!.put(cacheKey, cachedData);
          } else {
            await cache.put(cacheKey, cachedData);
          }
          print('DIAG_PRICE updateAmountTotalInCache: cache actualizado id=$orderId total=$amountTotal');
        }
      }
    } catch (e) {
      print('DIAG_PRICE updateAmountTotalInCache: error $e');
    }
  }

  /// Crea una nueva orden de venta (directamente en servidor cuando online)
  Future<String> createSaleOrder(Map<String, dynamic> orderData) async {
    try {
      print('🛒 SALE_ORDER_REPO: Creando nueva orden de venta...');
      print(AuditHelper.formatAuditLog('CREATE_SALE_ORDER', details: 'Creating new order'));
      print('🔵 REQUEST BODY CREATE SALE ORDER (antes de enriquecer): $orderData');

      // Enriquecer datos con auditoría y pricelist
      final enrichedData = await _enrichOrderDataForCreate(orderData);
      
      print('🔵 REQUEST BODY CREATE SALE ORDER (final): $enrichedData');

      // PASO 1: SIEMPRE guardar primero en cache local
      final tempId = await _saveToLocalCacheFirst(enrichedData);
      print('💾 SALE_ORDER: Guardado local con ID temporal: $tempId');

      // PASO 2: Si hay conectividad, intentar enviar al servidor
      if (await netConn.checkNetConn() == netConnState.online) {
        print('🌐 SALE_ORDER_REPO: ONLINE - Creando orden directamente en servidor');
        
        // ✅ FILTRAR: Remover campos de enriquecimiento antes de enviar a Odoo
        final cleanOrderData = Map<String, dynamic>.from(enrichedData)
          ..remove('partner_name')
          ..remove('partner_shipping_name')
          ..remove('order_lines'); // ✅ solo cache
        
        print('🧹 SALE_ORDER_REPO: Datos filtrados (removidos campos de enriquecimiento)');
        print('🧹 SALE_ORDER_REPO: Datos que se enviarán: $cleanOrderData');
        
        // Crear directamente en Odoo usando callKw
        print('🔥 SALE_ORDER_REPO: ===== INICIANDO CREACIÓN REAL =====');
        print('🔥 SALE_ORDER_REPO: Modelo: $modelName');
        print('🔥 SALE_ORDER_REPO: Método: create');
        print('🔥 SALE_ORDER_REPO: Cliente HTTP: ${env.orpc.runtimeType}');
        print('🔥 SALE_ORDER_REPO: URL base: ${env.orpc.baseURL}');
        
        dynamic serverId;
        try {
          serverId = await env.orpc.callKw({
            'model': modelName,
            'method': 'create',
            'args': [cleanOrderData],  // ✅ Usar datos filtrados
            'kwargs': {},
          });
          
          print('🔥 SALE_ORDER_REPO: ===== RESPUESTA RECIBIDA =====');
          print('🔥 SALE_ORDER_REPO: Respuesta raw: $serverId');
          print('🔥 SALE_ORDER_REPO: Tipo de respuesta: ${serverId.runtimeType}');
          
          final serverIdStr = serverId.toString();
          print('🔥 SALE_ORDER_REPO: ID convertido a string: $serverIdStr');
          print('🔥 SALE_ORDER_REPO: ===== FIN CREACIÓN REAL =====');
          
          // PASO 3: Actualizar cache local con ID real
          await _updateCacheWithRealId(tempId, serverId as int);
          
          print('✅ SALE_ORDER_REPO: Orden creada en servidor con ID: $serverIdStr');
          print(AuditHelper.formatAuditLog('CREATE_SALE_ORDER_SUCCESS', details: 'Server ID: $serverIdStr'));
          
          return serverIdStr;
        } catch (e) {
          print('❌ SALE_ORDER_REPO: Error en callKw (creación real): $e');
          print('❌ SALE_ORDER_REPO: Error tipo: ${e.runtimeType}');
          print('⚠️ SALE_ORDER_REPO: Servidor falló, pero pedido ya está en cache local');
          print('⚠️ SALE_ORDER_REPO: Pedido quedará con ID temporal y se sincronizará más tarde');
          
          // El pedido YA está en cache local con ID temporal
          // No re-lanzar el error, retornar ID temporal
          return tempId;
        }
      } else {
        print('📱 SALE_ORDER_REPO: OFFLINE - Usando sistema offline');
        
        // Encolar para sincronización posterior
        await _callQueue.createRecord(modelName, enrichedData);
        
        print('✅ SALE_ORDER_REPO: Orden guardada localmente (ID temporal: $tempId)');
        print('✅ SALE_ORDER_REPO: Orden encolada para sincronización');
        print(AuditHelper.formatAuditLog('CREATE_SALE_ORDER_SUCCESS', details: 'Local ID: $tempId'));
        
        return tempId;
      }
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error creando orden: $e');
      print(AuditHelper.formatAuditLog('CREATE_SALE_ORDER_ERROR', details: 'Error: $e'));
      rethrow;
    }
  }

  /// Envía una cotización (draft → sent)
  Future<bool> sendQuotation(int orderId) async {
    try {
      print('📧 SALE_ORDER_REPO: Enviando cotización $orderId...');
      print(AuditHelper.formatAuditLog('SEND_QUOTATION', details: 'Order ID: $orderId'));
      print('📧 SALE_ORDER_REPO: Estado actual antes de envío - obtieniendo datos...');

      // Verificar estado actual antes del envío
      final currentState = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[orderId]],
        'kwargs': {
          'fields': ['id', 'name', 'state', 'partner_id'],
        },
      });

      if (currentState is List && currentState.isNotEmpty) {
        final orderData = currentState.first as Map<String, dynamic>;
        print('📧 SALE_ORDER_REPO: Estado ANTES de envío: ${orderData['state']}');
        print('📧 SALE_ORDER_REPO: Nombre orden: ${orderData['name']}');
      }

      print('📧 SALE_ORDER_REPO: Llamando action_quotation_send...');
      try {
        await env.orpc.callKw({
          'model': modelName,
          'method': 'action_quotation_send',
          'args': [[orderId]],
          'kwargs': {},
        });
        print('✅ SALE_ORDER_REPO: action_quotation_send ejecutado sin excepción');
      } catch (e) {
        print('⚠️ SALE_ORDER_REPO: action_quotation_send falló: $e');
        print('🔄 SALE_ORDER_REPO: Intentando cambio de estado manual...');
      }
      
      // Si action_quotation_send no funciona, cambiar estado manualmente
      await env.orpc.callKw({
        'model': modelName,
        'method': 'write',
        'args': [[orderId], {'state': 'sent'}],
        'kwargs': {},
      });
      print('✅ SALE_ORDER_REPO: Estado cambiado manualmente a sent');

      // Verificar estado después del envío
      print('📧 SALE_ORDER_REPO: Verificando estado después del envío...');
      final afterState = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[orderId]],
        'kwargs': {
          'fields': ['id', 'name', 'state', 'partner_id'],
        },
      });

      if (afterState is List && afterState.isNotEmpty) {
        final orderData = afterState.first as Map<String, dynamic>;
        print('📧 SALE_ORDER_REPO: Estado DESPUÉS de envío: ${orderData['state']}');
        
        if (orderData['state'] == 'sent') {
          print('✅ SALE_ORDER_REPO: ⭐ Estado correctamente cambiado a SENT ⭐');
        } else {
          print('⚠️ SALE_ORDER_REPO: ⚠️ Estado NO cambió - sigue siendo: ${orderData['state']} ⚠️');
          // Intentar debug adicional
          print('📧 SALE_ORDER_REPO: Datos completos de la orden después del envío: $orderData');
        }
      }

      print('✅ SALE_ORDER_REPO: Proceso sendQuotation completado');
      return true;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error enviando cotización: $e');
      print('❌ SALE_ORDER_REPO: Tipo de error: ${e.runtimeType}');
      if (e is OdooException) {
      print('❌ SALE_ORDER_REPO: Error detalles: ${e.message}');
        
        // Re-lanzar con mensaje más claro
        if (e.message.contains('no email template') ||
            e.message.contains('no partner email')) {
          throw Exception('La orden no puede ser enviada: Falta dirección de email del cliente');
        } else {
          throw Exception('Error enviando cotización: ${e.message}');
        }
      }
      return false;
    }
  }

  /// Actualiza el estado de una orden de venta usando métodos específicos de Odoo
  Future<bool> updateOrderState(int orderId, String newState) async {
    try {
      print('🛒 SALE_ORDER_REPO: Actualizando estado de orden $orderId a $newState');
      print(AuditHelper.formatAuditLog('UPDATE_ORDER_STATE', details: 'Order ID: $orderId, New State: $newState'));

      if (newState == 'sale') {
        // Para confirmar orden, usar método específico
        await env.orpc.callKw({
          'model': modelName,
          'method': 'action_confirm',
          'args': [[orderId]],
          'kwargs': {},
        });
        print('✅ SALE_ORDER_REPO: Orden confirmada exitosamente usando action_confirm');
      } else {
        // Para otros estados usar write directamente
        await env.orpc.callKw({
          'model': modelName,
          'method': 'write',
          'args': [[orderId], {'state': newState}],
          'kwargs': {},
        });
        print('✅ SALE_ORDER_REPO: Estado actualizado exitosamente');
      }

      return true;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error actualizando estado: $e');
      if (e is OdooException) {
        print('❌ SALE_ORDER_REPO: Error detalles: ${e.message}');
        
        // Verificar si el error es por falta de datos requeridos
        if (e.message.contains('missing required field') || 
            e.message.contains('is required') ||
            e.message.contains('no lines') ||
            e.message.contains('no partner')) {
          throw Exception('La orden no puede ser confirmada: ${e.message}');
        }
      }
      return false;
    }
  }

  /// Calcula totales usando funciones de Odoo con cache
  Future<OrderTotals> calculateOrderTotals({
    required int partnerId,
    required List<SaleOrderLine> orderLines,
  }) async {
    // Generar clave de cache
    final cacheKey = _generateTotalsCacheKey(partnerId, orderLines);
    
    print('🧮 SALE_ORDER_REPO: ⚠️ CALCULANDO TOTALES - Partner: $partnerId, Lines: ${orderLines.length}');
    print('🧮 SALE_ORDER_REPO: ⚠️ Stack trace: ${StackTrace.current.toString().split('\n').take(5).join('\n')}');
    
    try {
      
      // Verificar cache primero
      if (_totalsCache.containsKey(cacheKey)) {
        print('💾 SALE_ORDER_REPO: Totales encontrados en cache');
        return _totalsCache[cacheKey]!;
      }
      
      print('🧮 SALE_ORDER_REPO: Calculando totales con Odoo...');
      print('🧮 SALE_ORDER_REPO: Partner ID: $partnerId');
      print('🧮 SALE_ORDER_REPO: Order lines: ${orderLines.length}');
      
      // Obtener pricelist del partner
      final pricelistId = await _getPartnerPricelistId(partnerId);
      print('🧮 SALE_ORDER_REPO: Pricelist ID for partner $partnerId => $pricelistId');

      // Crear datos temporales de la orden (incluye pricelist)
      final tempOrderData = _buildTempOrderData(partnerId, pricelistId, orderLines);
      print('🧮 SALE_ORDER_REPO: Temp order data: $tempOrderData');
      
      int? tempOrderId;
      try {
        // Crear una orden temporal para calcular totales
        print('🧮 SALE_ORDER_REPO: ===== INICIANDO CREACIÓN TEMPORAL =====');
        print('🧮 SALE_ORDER_REPO: Datos temporales: $tempOrderData');
        print('🧮 SALE_ORDER_REPO: Modelo: sale.order');
        print('🧮 SALE_ORDER_REPO: Método: create');
        print('🧮 SALE_ORDER_REPO: Cliente HTTP: ${env.orpc.runtimeType}');
        print('🧮 SALE_ORDER_REPO: URL base: ${env.orpc.baseURL}');
        
        try {
          tempOrderId = await env.orpc.callKw({
            'model': 'sale.order',
            'method': 'create',
            'args': [tempOrderData], // ← Usar tempOrderData en lugar de duplicar
            'kwargs': {},
          });
          
          print('🧮 SALE_ORDER_REPO: ===== RESPUESTA TEMPORAL RECIBIDA =====');
          print('🧮 SALE_ORDER_REPO: Respuesta raw: $tempOrderId');
          print('🧮 SALE_ORDER_REPO: Tipo de respuesta: ${tempOrderId.runtimeType}');
          print('🧮 SALE_ORDER_REPO: Es int: ${tempOrderId is int}');
          print('🧮 SALE_ORDER_REPO: Es String: ${tempOrderId is String}');
          print('🧮 SALE_ORDER_REPO: Es List: ${tempOrderId is List}');
          print('🧮 SALE_ORDER_REPO: Es Map: ${tempOrderId is Map}');
          print('🧮 SALE_ORDER_REPO: ===== FIN CREACIÓN TEMPORAL =====');
        } catch (e) {
          print('❌ SALE_ORDER_REPO: Error en callKw: $e');
          print('❌ SALE_ORDER_REPO: Error tipo: ${e.runtimeType}');
          // Re-lanzar para que el catch exterior lo maneje
          rethrow;
        }
        
        print('🧮 SALE_ORDER_REPO: Orden temporal creada con ID: $tempOrderId');
        
        // Leer los totales calculados
        final orderData = await env.orpc.callKw({
          'model': 'sale.order',
          'method': 'read',
          'args': [[tempOrderId], ['amount_untaxed', 'amount_tax', 'amount_total']],
          'kwargs': {},
        });
        
        final order = (orderData as List).first as Map<String, dynamic>;
        print('🧮 SALE_ORDER_REPO: Totales de la orden temporal: $order');
        
        // Obtener impuestos agrupados
        final taxGroups = await _getTaxGroupsFromOrder(tempOrderId!);
        
        // Crear resultado antes de eliminar
        final result = OrderTotals(
          amountUntaxed: (order['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
          amountTax: (order['amount_tax'] as num?)?.toDouble() ?? 0.0,
          amountTotal: (order['amount_total'] as num?)?.toDouble() ?? 0.0,
          taxGroups: taxGroups,
        );
        
        // Guardar en cache
        _totalsCache[cacheKey] = result;
        _cleanupCache(); // Limpiar cache si es muy grande
        
        print('✅ SALE_ORDER_REPO: Totales calculados con Odoo: ${result.amountTotal}');
        return result;
        
      } finally {
        // Asegurar que la orden temporal se elimine SIEMPRE
        if (tempOrderId != null) {
          try {
            print('🧮 SALE_ORDER_REPO: FINALLY - Eliminando orden temporal $tempOrderId...');
            await env.orpc.callKw({
              'model': 'sale.order',
              'method': 'unlink',
              'args': [[tempOrderId]],
              'kwargs': {},
            });
            print('🧮 SALE_ORDER_REPO: FINALLY - Orden temporal $tempOrderId eliminada exitosamente');
          } catch (e) {
            print('❌ SALE_ORDER_REPO: FINALLY - Error eliminando orden temporal $tempOrderId: $e');
            print('❌ SALE_ORDER_REPO: FINALLY - Error type: ${e.runtimeType}');
            print('❌ SALE_ORDER_REPO: FINALLY - Error details: $e');
          }
        } else {
          print('🧮 SALE_ORDER_REPO: FINALLY - No hay orden temporal que eliminar (tempOrderId es null)');
        }
      }
      
    } catch (e) {
        print('⚠️ SALE_ORDER_REPO: Error con cálculo de Odoo: $e');
        print('🔄 SALE_ORDER_REPO: Usando cálculo local como fallback...');
        
        // Fallback a cálculo local
        final totals = _calculateLocalTotals(orderLines);
        
        // Guardar en cache
        _totalsCache[cacheKey] = totals;
        _cleanupCache();
        
        print('✅ SALE_ORDER_REPO: Totales calculados localmente: ${totals.amountTotal}');
        return totals;
      }
  }
  
  /// Obtiene impuestos agrupados desde una orden existente
  Future<List<TaxGroup>> _getTaxGroupsFromOrder(int orderId) async {
    try {
      final taxGroups = await env.orpc.callKw({
        'model': 'sale.order',
        'method': '_get_tax_amount_by_group',
        'args': [orderId],
        'kwargs': {},
      });
      
      return (taxGroups as List).map((group) => TaxGroup.fromJson(group)).toList();
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: Error obteniendo grupos de impuestos desde orden: $e');
      return [];
    }
  }
  
  /// Construye datos temporales de orden para cálculos
  Map<String, dynamic> _buildTempOrderData(int partnerId, int? pricelistId, List<SaleOrderLine> orderLines) {
    final tempId = DateTime.now().millisecondsSinceEpoch; // ID único temporal
    
    // Obtener user_id de forma segura
    int? userId;
    try {
      if (getIt.isRegistered<OdooSession>()) {
        userId = getIt<OdooSession>().userId;
      }
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: No se pudo obtener userId de OdooSession: $e');
    }
    
    return {
      'name': 'TEMP_CALC_$tempId', // Nombre único para identificar órdenes temporales
      'partner_id': partnerId,
      if (userId != null) 'user_id': userId, // Solo agregar si está disponible
      if (pricelistId != null) 'pricelist_id': pricelistId,
      'order_line': orderLines.map((line) => [
        0, 0, {
          'product_id': line.productId,
          'product_uom_qty': line.quantity,
          // No enviar price_unit ni tax_id: dejar que Odoo los calcule con la pricelist
        }
      ]).toList(),
    };
  }

  /// Lee la lista de precios del partner
  Future<int?> _getPartnerPricelistId(int partnerId) async {
    try {
      final read = await env.orpc.callKw({
        'model': 'res.partner',
        'method': 'read',
        'args': [[partnerId]],
        'kwargs': {
          'fields': ['property_product_pricelist'],
        },
      });
      if (read is List && read.isNotEmpty) {
        final data = read.first as Map<String, dynamic>;
        final value = data['property_product_pricelist'];
        if (value is List && value.isNotEmpty) {
          return (value[0] as num).toInt();
        }
        print('🧮 SALE_ORDER_REPO: Pricelist ID for partner $partnerId => $value');
      }
      
      return null;
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: Error leyendo pricelist del partner $partnerId: $e');
      return null;
    }
  }
  
  /// Fallback: cálculo local de totales
  OrderTotals _calculateLocalTotals(List<SaleOrderLine> orderLines) {
    final subtotal = orderLines.fold(0.0, (sum, line) => sum + line.subtotal);
    final taxAmount = subtotal * 0.19; // 19% por defecto
    final total = subtotal + taxAmount;
    
    return OrderTotals(
      amountUntaxed: subtotal,
      amountTax: taxAmount,
      amountTotal: total,
      taxGroups: [
        TaxGroup(
          name: 'Impuestos (19%)',
          amount: taxAmount,
          base: subtotal,
        ),
      ],
    );
  }
  
  /// Genera una clave única para el cache de totales
  String _generateTotalsCacheKey(int partnerId, List<SaleOrderLine> orderLines) {
    final linesKey = orderLines
        .map((line) => '${line.productId}:${line.quantity}:${line.priceUnit}:${line.taxesIds.join(',')}')
        .join('|');
    return 'totals_${partnerId}_$linesKey';
  }
  
  /// Limpia el cache si tiene más de 50 entradas
  void _cleanupCache() {
    if (_totalsCache.length > 50) {
      print('🧹 SALE_ORDER_REPO: Limpiando cache de totales (${_totalsCache.length} entradas)');
      _totalsCache.clear();
    }
  }
  
  /// Limpia el cache de totales (método público)
  void clearTotalsCache() {
    _totalsCache.clear();
    print('🧹 SALE_ORDER_REPO: Cache de totales limpiado');
  }

  /// Obtiene órdenes de venta por partner
  Future<List<SaleOrder>> getOrdersByPartner(int partnerId) async {
    try {
      print('🛒 SALE_ORDER_REPO: Buscando órdenes para partner $partnerId...');
      
      final domain = [
        ['partner_id', '=', partnerId]
      ];
      
      final searchResult = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': oFields,
          'order': 'date_order desc',
          'limit': 100,
        },
      });
      
      final records = searchResult as List<dynamic>;
      final orders = records.map((record) => fromJson(record)).toList();
      
      print('✅ SALE_ORDER_REPO: ${orders.length} órdenes encontradas para partner $partnerId');
      return orders;
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error obteniendo órdenes por partner: $e');
      return [];
    }
  }

  /// Obtiene una orden de venta específica por ID, incluyendo sus líneas
  Future<SaleOrder?> getOrderById(int orderId) async {
    try {
      print('🛒 SALE_ORDER_REPO: Obteniendo orden $orderId...');
      
      // ✅ PASO 1: Buscar en latestRecords (cache en memoria)
      final cachedOrder = latestRecords.where((order) => order.id == orderId).firstOrNull;
      
      if (cachedOrder != null) {
        print('✅ SALE_ORDER_REPO: Orden $orderId encontrada en latestRecords (cache memoria)');
        print('DIAG_BUG_008 getOrderById($orderId): source=latestRecords, lines=${cachedOrder.orderLines.length}, lineIds=${cachedOrder.orderLineIds.length}');
        
        // Si la orden en cache no tiene líneas, intentar obtenerlas del servidor (solo si hay conexión)
        if (cachedOrder.orderLines.isEmpty && cachedOrder.orderLineIds.isNotEmpty) {
          // Verificar si hay conexión antes de intentar obtener líneas del servidor
          if (await netConn.checkNetConn() == netConnState.online) {
            print('🔍 SALE_ORDER_REPO: Orden sin líneas en cache, obteniendo líneas del servidor (online)...');
            try {
              final linesResult = await env.orpc.callKw({
                'model': 'sale.order.line',
                'method': 'read',
                'args': [cachedOrder.orderLineIds],
                'kwargs': {
                  'fields': [
                    'id',
                    'product_id',
                    'name',
                    'product_uom_qty',
                    'price_unit',
                    'price_subtotal',
                    'tax_id'
                  ],
                },
              });

              if (linesResult is List) {
                final orderLines = linesResult
                    .map((lineData) => SaleOrderLine.fromJson(lineData))
                    .toList();
                print('✅ SALE_ORDER_REPO: ${orderLines.length} líneas obtenidas del servidor');
                
                // ✅ BUG-007: Actualizar cache con orden completa (con líneas)
                final completeOrder = cachedOrder.copyWith(orderLines: orderLines);
                await _updateCacheWithCompleteOrder(completeOrder);
                
                // ✅ CRÍTICO: También actualizar latestRecords en memoria
                final index = latestRecords.indexWhere((order) => order.id == orderId);
                if (index >= 0) {
                  latestRecords[index] = completeOrder;
                  print('✅ SALE_ORDER: latestRecords actualizado con líneas en memoria');
                }
                
                return completeOrder;
              }
            } catch (e) {
              print('⚠️ SALE_ORDER_REPO: No se pudieron obtener líneas del servidor: $e');
              // Retornar orden sin líneas en lugar de fallar completamente
              return cachedOrder;
            }
          } else {
            print('📱 SALE_ORDER_REPO: Modo offline - orden sin líneas en cache, retornando orden básica');
            return cachedOrder;
          }
        }
        
        // Si la orden ya tiene líneas en cache, retornarla directamente
        return cachedOrder;
      }
      
      // ✅ PASO 2: Si no está en latestRecords, cargar desde Hive (TenantAwareCache)
      print('🔍 SALE_ORDER_REPO: Orden no en latestRecords, buscando en cache persistente...');
      await loadRecords(); // Esto actualiza latestRecords desde TenantAwareCache
      
      // Intentar otra vez después de cargar desde Hive
      final reloadedOrder = latestRecords.where((order) => order.id == orderId).firstOrNull;
      if (reloadedOrder != null) {
        print('✅ SALE_ORDER_REPO: Orden $orderId encontrada después de cargar desde cache persistente');
        print('DIAG_BUG_008 getOrderById($orderId): source=persistentCache, lines=${reloadedOrder.orderLines.length}, lineIds=${reloadedOrder.orderLineIds.length}');
        return reloadedOrder;
      }
      
      // ✅ PASO 3: Intentar desde servidor (solo si hay conexión)
      if (await netConn.checkNetConn() == netConnState.online) {
        print('🌐 SALE_ORDER_REPO: Intento desde servidor...');
        
        final result = await env.orpc.callKw({
          'model': modelName,
          'method': 'read',
          'args': [[orderId]],
          'kwargs': {
            'fields': oFields,
          },
        });
        
        if (result is List && result.isNotEmpty) {
          var order = fromJson(result.first);
          print('✅ SALE_ORDER_REPO: Orden $orderId obtenida del servidor, obteniendo líneas...');

          // Ahora, obtén los detalles de las líneas de pedido
          if (order.orderLineIds.isNotEmpty) {
            final linesResult = await env.orpc.callKw({
              'model': 'sale.order.line',
              'method': 'read',
              'args': [order.orderLineIds],
              'kwargs': {
                'fields': [
                  'id',
                  'product_id',
                  'name',
                  'product_uom_qty',
                  'price_unit',
                  'price_subtotal',
                  'tax_id'
                ],
              },
            });

            if (linesResult is List) {
              print('🔍 SALE_ORDER_REPO: Raw lines data from Odoo: $linesResult');
              final orderLines = linesResult
                  .map((lineData) {
                    print('🔍 SALE_ORDER_REPO: Processing line data: $lineData');
                    return SaleOrderLine.fromJson(lineData);
                  })
                  .toList();
              order = order.copyWith(orderLines: orderLines);
              print('✅ SALE_ORDER_REPO: ${orderLines.length} líneas obtenidas para orden $orderId');
            }
          }
          
          return order;
        }
        
        print('⚠️ SALE_ORDER_REPO: Orden $orderId no encontrada en servidor');
        return null;
      } else {
        print('📱 SALE_ORDER_REPO: Modo offline y orden $orderId no en cache');
        return null;
      }
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error obteniendo orden $orderId: $e');
      
      // ✅ FALLBACK: Intentar cache si falló servidor
      print('🔄 SALE_ORDER_REPO: Intentando cargar desde cache persistente (fallback)...');
      try {
        await loadRecords(); // Cargar desde TenantAwareCache a latestRecords
        
        final cachedOrder = latestRecords.where((order) => order.id == orderId).firstOrNull;
        if (cachedOrder != null) {
          print('✅ SALE_ORDER_REPO: Orden $orderId recuperada de cache (fallback)');
          return cachedOrder;
        }
      } catch (cacheError) {
        print('❌ SALE_ORDER_REPO: Error en fallback de cache: $cacheError');
      }
      
      print('❌ SALE_ORDER_REPO: Orden $orderId no encontrada en cache ni en servidor');
      return null;
    }
  }

  /// Actualiza una orden de venta existente
  Future<bool> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      print('🛒 SALE_ORDER_REPO: Actualizando orden $orderId...');
      print('🛒 SALE_ORDER_REPO: Order data original: $orderData');
      
      // Enriquecer datos con auditoría
      final enrichedData = _enrichOrderDataForWrite(orderData);
      print('🛒 SALE_REPO: Order data enriquecida: $enrichedData');
      
      // Si se está intentando cambiar el estado a 'sale', usar action_confirm
      if (enrichedData['state'] == 'sale') {
        print('🛒 SALE_ORDER_REPO: Cambiando estado a sale, usando action_confirm...');
        
        // Primero actualizar otros campos si los hay (sin state)
        final otherData = Map<String, dynamic>.from(enrichedData);
        otherData.remove('state');
        
        if (otherData.isNotEmpty) {
          await env.orpc.callKw({
            'model': modelName,
            'method': 'write',
            'args': [[orderId], otherData],
          });
          print('🛒 SALE_ORDER_REPO: Otros campos actualizados antes de confirmar');
        }
        
        // Luego confirmar la orden
        await env.orpc.callKw({
          'model': modelName,
          'method': 'action_confirm',
          'args': [[orderId]],
          'kwargs': {},
        });
        
        print('✅ SALE_ORDER_REPO: Orden $orderId confirmada exitosamente');
      } else {
        // Para otros cambios, usar write normal con datos enriquecidos
        print('🛒 SALE_ORDER_REPO: Llamando write con orderId: $orderId');
        print('🛒 SALE_ORDER_REPO: Enriched data: $enrichedData');
        print('🛒 SALE_ORDER_REPO: Usando cliente: ${env.orpc.runtimeType}');
        
        try {
          await env.orpc.callKw({
            'model': modelName,
            'method': 'write',
            'args': [[orderId], enrichedData],
          });
          print('🛒 SALE_ORDER_REPO: Write completado exitosamente');
        } catch (e) {
          print('❌ SALE_ORDER_REPO: Error en callKw: $e');
          print('❌ SALE_ORDER_REPO: Tipo de error: ${e.runtimeType}');
          rethrow;
        }
        
        print('✅ SALE_ORDER_REPO: Orden $orderId actualizada');
      }
      
      return true;
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error actualizando orden $orderId: $e');
      if (e is OdooException) {
        print('❌ SALE_ORDER_REPO: Error detalles: ${e.message}');
        
        // Re-lanzar con mensaje más claro para la UI
        if (e.message.contains('missing required field') || 
            e.message.contains('is required') ||
            e.message.contains('no lines') ||
            e.message.contains('no partner')) {
          throw Exception('La orden no puede ser confirmada: Verifica que tenga cliente y productos');
        } else {
          throw Exception('Error del servidor: ${e.message}');
        }
      }
      throw Exception('Error inesperado al actualizar orden');
    }
  }

  /// Actualiza una orden de venta existente (offline/online según conectividad)
  Future<void> updateSaleOrder(SaleOrder order) async {
    await _callQueue.updateRecord(modelName, order.id, order.toJson());
  }

  /// Elimina permanentemente una orden de venta (offline/online según conectividad)
  Future<void> deleteSaleOrder(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }

  /// Crea una nueva línea de orden usando sale.order.line.create
  Future<int> createOrderLine({
    required int orderId,
    required int productId,
    required double quantity,
    double? priceUnit,
  }) async {
    try {
      print('🛒 SALE_ORDER_REPO: Creando línea para orden $orderId, producto $productId');
      
      final data = {
        'order_id': orderId,
        'product_id': productId,
        'product_uom_qty': quantity,
      };
      
      if (priceUnit != null) {
        data['price_unit'] = priceUnit;
      }
      
      final result = await env.orpc.callKw({
        'model': 'sale.order.line',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });
      
      print('✅ SALE_ORDER_REPO: Línea creada con ID: $result');
      return result;
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error creando línea: $e');
      rethrow;
    }
  }

  /// Actualiza una línea de orden existente usando sale.order.line.write
  Future<void> updateOrderLine({
    required int lineId,
    double? quantity,
    double? priceUnit,
  }) async {
    try {
      print('🛒 SALE_ORDER_REPO: Actualizando línea $lineId');
      
      final data = <String, dynamic>{};
      if (quantity != null) {
        data['product_uom_qty'] = quantity;
      }
      if (priceUnit != null) {
        data['price_unit'] = priceUnit;
      }
      
      await env.orpc.callKw({
        'model': 'sale.order.line',
        'method': 'write',
        'args': [
          [lineId],
          data,
        ],
        'kwargs': {},
      });
      
      print('✅ SALE_ORDER_REPO: Línea $lineId actualizada');
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error actualizando línea: $e');
      rethrow;
    }
  }

  /// Elimina una línea de orden usando sale.order.line.unlink
  Future<void> deleteOrderLine(int lineId) async {
    try {
      print('🛒 SALE_ORDER_REPO: Eliminando línea $lineId');
      
      await env.orpc.callKw({
        'model': 'sale.order.line',
        'method': 'unlink',
        'args': [[lineId]],
        'kwargs': {},
      });
      
      print('✅ SALE_ORDER_REPO: Línea $lineId eliminada');
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error eliminando línea: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchIncrementalRecords(String since) async {
    print('🔄 SALE_ORDER_REPO: Fetch incremental desde $since');
    
    // ✅ v2.0: Aplicar filtrado temporal (6 meses) para reducir tamaño de cache
    final temporalDomain = TenantStorageConfig.getSaleOrdersDateDomain();
    final filterDate = TenantStorageConfig.getSaleOrdersFilterDate();
    if (filterDate != null) {
      print('📅 SALE_ORDER_REPO: Filtro temporal aplicado: últimos ${TenantStorageConfig.saleOrdersMonthsBack} meses (desde ${filterDate.toLocal()})');
    } else {
      print('📅 SALE_ORDER_REPO: Sin filtro temporal (todas las fechas)');
    }
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['state', '!=', 'cancel'],
          ['write_date', '>', since], // 👈 Filtro de fecha incremental
          ...temporalDomain, // ✅ v2.0: Filtrar por fecha (últimos 6 meses)
        ],
        'fields': oFields,
        'limit': 1000, // Alto límite (usualmente pocos cambios)
        'offset': 0,
        'order': 'write_date asc',
      },
    });
    
    final records = response as List<dynamic>;
    print('🔄 SALE_ORDER_REPO: ${records.length} registros incrementales obtenidos');
    
    // Convertir cada record a Map<String, dynamic> para evitar errores de tipo
    return records.map((record) => Map<String, dynamic>.from(record)).toList();
  }
}