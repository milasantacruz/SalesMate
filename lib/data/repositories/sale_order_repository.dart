import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'dart:convert';
import '../models/sale_order_model.dart';
import '../models/sale_order_line_model.dart';
import '../models/order_totals_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import '../../core/di/injection_container.dart';
import '../../core/audit/audit_helper.dart';
import '../../core/audit/audit_event_service.dart';
import '../../core/tenant/tenant_storage_config.dart';
import '../../core/cache/custom_odoo_kv.dart';
import '../../core/services/order_totals_calculation_service.dart';
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
  late final OrderTotalsCalculationService _orderTotalsService;

  SaleOrderRepository(
    OdooEnvironment env,
    NetworkConnectivity netConn,
    OdooKv cache, {
    super.tenantCache,
  }) : super(env, netConn, cache) {
    // Inicializar _callQueue desde dependency injection
    _callQueue = getIt<OdooCallQueueRepository>();
    // Inicializar servicio de cálculo de totales
    _orderTotalsService = getIt<OrderTotalsCalculationService>();
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
    
    // ✅ Filtro temporal: solo órdenes de los últimos 6 meses
    final temporalDomain = TenantStorageConfig.getSaleOrdersDateDomain();
    if (temporalDomain.isNotEmpty) {
      domain.addAll(temporalDomain);
      final filterDate = TenantStorageConfig.getSaleOrdersFilterDate();
      if (filterDate != null) {
        print('📅 SALE_ORDER_REPO: Filtro temporal aplicado: últimos ${TenantStorageConfig.saleOrdersMonthsBack} meses (desde ${filterDate.toLocal()})');
      }
    }
    
    // ✅ Excluir órdenes temporales de cálculo (TEMP_CALC) desde el servidor
    domain.add('!');
    domain.add(['name', '=like', 'TEMP_CALC%']);
    
    // Filtro por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      // OR de 3 condiciones: name, partner display_name y RUT (partner_id.vat)
      domain.addAll([
        '|', '|',
        ['name', 'ilike', _searchTerm],
        ['partner_id', 'ilike', _searchTerm],
        ['partner_id.vat', 'ilike', _searchTerm],
      ]);
    }
    
    // Filtro por estado
    if (_state != null && _state!.isNotEmpty) {
      domain.add(['state', '=', _state]);
    }

    final activeUserId = _getActiveUserId();
    if (activeUserId != null) {
      domain.add(['user_id', '=', activeUserId]);
      print('👤 SALE_ORDER_REPO: Dominio filtrado por user_id=$activeUserId');
    }
    
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
    
    // Excluir órdenes temporales de cálculo (solo las que empiezan con TEMP_CALC)
    final beforeFilter = filteredRecords.length;
    final tempCalcOrders = filteredRecords.where((order) => order.name.startsWith('TEMP_CALC')).toList();
    filteredRecords = filteredRecords
        .where((order) => !order.name.startsWith('TEMP_CALC'))
        .toList();
    print('🔍 SALE_ORDER_REPO: Filtro TEMP_CALC - Total: $beforeFilter, TEMP_CALC: ${tempCalcOrders.length}, Restantes: ${filteredRecords.length}');
    if (tempCalcOrders.isNotEmpty && tempCalcOrders.length <= 5) {
      print('🔍 SALE_ORDER_REPO: Órdenes TEMP_CALC filtradas: ${tempCalcOrders.map((o) => o.name).join(", ")}');
    }

    // Helpers para búsqueda por RUT (normalizado) y texto
    String _normalizeRut(String s) => s
        .replaceAll('.', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .toLowerCase();
    String? _extractRutFromDisplay(String? display) {
      if (display == null || display.isEmpty) return null;
      final m = RegExp(r'(\d{1,3}(?:\.\d{3})+-[\dkK])').firstMatch(display);
      return m?.group(1);
    }

    // Filtro por término de búsqueda (name, partnerName y RUT normalizado)
    if (_searchTerm.isNotEmpty) {
      filteredRecords = filteredRecords.where((order) {
        final searchLower = _searchTerm.toLowerCase();
        final termNorm = _normalizeRut(_searchTerm);

        final orderName = order.name.toLowerCase();
        final partnerNameLower = (order.partnerName ?? '').toLowerCase();

        // Extraer RUT visible desde partnerName (display_name) si existe
        final partnerRutRaw = _extractRutFromDisplay(order.partnerName);
        final partnerRutNorm = partnerRutRaw != null ? _normalizeRut(partnerRutRaw) : '';

        final matchesText = orderName.contains(searchLower) || partnerNameLower.contains(searchLower);
        final matchesRut = partnerRutNorm.isNotEmpty && partnerRutNorm.contains(termNorm);
        return matchesText || matchesRut;
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
        
        // ✅ NORMALIZACIÓN: Detectar y normalizar order_lines como String en cache antigua
        bool needsCacheUpdate = false;
        final normalizedData = <dynamic>[];
        
        for (final record in cachedData) {
          if (record is Map) {
            final normalizedRecord = Map<String, dynamic>.from(record);
            
            // Detectar order_lines como String y normalizarlo
            if (normalizedRecord.containsKey('order_lines') && 
                normalizedRecord['order_lines'] is String) {
              try {
                final decoded = jsonDecode(normalizedRecord['order_lines'] as String);
                if (decoded is List) {
                  // Normalizar: convertir String a List de Maps
                  normalizedRecord['order_lines'] = decoded;
                  needsCacheUpdate = true;
                  print('✅ SALE_ORDER_REPO: Normalizando orden ${normalizedRecord['id']}: order_lines de String a List');
                }
              } catch (e) {
                print('⚠️ SALE_ORDER_REPO: Error normalizando order_lines: $e');
              }
            }
            
            normalizedData.add(normalizedRecord);
          } else {
            normalizedData.add(record);
          }
        }
        
        // Si hubo normalizaciones, regrabar el cache
        if (needsCacheUpdate) {
          print('✅ SALE_ORDER_REPO: Regrabando cache con datos normalizados...');
          try {
            if (tenantCache != null) {
              await tenantCache!.put(cacheKey, normalizedData);
            } else {
              await cache.put(cacheKey, normalizedData);
            }
            print('✅ SALE_ORDER_REPO: Cache normalizado correctamente');
          } catch (e) {
            print('⚠️ SALE_ORDER_REPO: Error regrabando cache normalizado: $e');
          }
        }
        
        // Usar datos normalizados para procesar
        final dataToProcess = needsCacheUpdate ? normalizedData : cachedData;
        
        // Convertir cada record a Map<String, dynamic> para evitar errores de tipo
        final cachedRecords = dataToProcess.map((record) {
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

        latestRecords = _applyLocalFilters(cachedRecords);
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
      }

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
        } catch (e) {
          print('⚠️ SALE_ORDER: Error calculando amount_total local: $e');
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
      print('🔧 SALE_ORDER_REPO: Enriquecido partner_shipping_id: $shippingId → [$shippingId, $shippingName]');
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
        }
      }
    } catch (e) {
      print('⚠️ SALE_ORDER: Error actualizando amount_total en cache: $e');
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
        try {
          final pending = await _callQueue.getPendingCount();
          print('📦 SALE_ORDER_REPO: Cola tras encolar create ${modelName}: pendientes=$pending');
        } catch (_) {}
        
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
      final connectionState = await netConn.checkNetConn();
      if (connectionState != netConnState.online) {
        print('📴 SALE_ORDER_REPO: Sin conexión - no se puede enviar cotización ahora');
        print(AuditHelper.formatAuditLog('SEND_QUOTATION_SKIPPED', details: 'Order ID: $orderId (offline)'));
        await getIt<AuditEventService>().recordWarning(
          category: 'sale-order',
          message: 'Envio de cotización omitido por falta de conexión',
          metadata: {
            'orderId': orderId,
          },
        );
        throw Exception('Sin conexión a internet. Conéctate antes de enviar la cotización.');
      }
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

  /// Calcula totales localmente usando la tarifa de la licencia y los impuestos cacheados
  /// 
  /// Ya no crea órdenes temporales en Odoo. Usa cálculo completamente local.
  Future<OrderTotals> calculateOrderTotals({
    required int partnerId, // Mantener para compatibilidad y cache key, pero no se usa para cálculo
    required List<SaleOrderLine> orderLines,
  }) async {
    // Generar clave de cache
    final cacheKey = _generateTotalsCacheKey(partnerId, orderLines);
    
    print('🧮 SALE_ORDER_REPO: ═══════════════════════════════════════════════');
    print('🧮 SALE_ORDER_REPO: CALCULANDO TOTALES LOCALMENTE');
    print('🧮 SALE_ORDER_REPO: Partner: $partnerId, Lines: ${orderLines.length}');
    print('🧮 SALE_ORDER_REPO: ═══════════════════════════════════════════════');
    
    try {
      // Verificar cache primero
      if (_totalsCache.containsKey(cacheKey)) {
        print('💾 SALE_ORDER_REPO: Totales encontrados en cache');
        return _totalsCache[cacheKey]!;
      }
      
      // Obtener companyId desde cache
      final companyId = _getCompanyIdFromCache();
      if (companyId == null) {
        print('⚠️ SALE_ORDER_REPO: No hay companyId en cache, usando cálculo fallback');
        final totals = _calculateLocalTotals(orderLines);
        // Guardar en cache
        _totalsCache[cacheKey] = totals;
        _cleanupCache();
        return totals;
      }
      
      print('✅ SALE_ORDER_REPO: Company ID obtenido: $companyId');
      print('💰 SALE_ORDER_REPO: Calculando totales con servicio local...');
      
      // Calcular totales localmente usando el servicio
      final totals = _orderTotalsService.calculateTotals(
        orderLines: orderLines,
        companyId: companyId,
      );
      
      // Guardar en cache
      _totalsCache[cacheKey] = totals;
      _cleanupCache();
      
      print('✅ SALE_ORDER_REPO: Totales calculados localmente:');
      print('   - Subtotal sin impuestos: ${totals.amountUntaxed}');
      print('   - Total de impuestos: ${totals.amountTax}');
      print('   - Total final: ${totals.amountTotal}');
      print('   - Grupos de impuestos: ${totals.taxGroups.length}');
      print('🧮 SALE_ORDER_REPO: ═══════════════════════════════════════════════');
      
      return totals;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error calculando totales localmente: $e');
      print('🔄 SALE_ORDER_REPO: Usando cálculo fallback simplificado...');
      
      // Fallback a cálculo simplificado
      final totals = _calculateLocalTotals(orderLines);
      
      // Guardar en cache
      _totalsCache[cacheKey] = totals;
      _cleanupCache();
      
      print('✅ SALE_ORDER_REPO: Totales calculados con fallback: ${totals.amountTotal}');
      return totals;
    }
  }
  
  /// Lee la lista de precios del partner
  /// 
  /// NOTA: Este método se mantiene porque se usa en _enrichOrderDataForCreate
  /// para enriquecer datos de órdenes al crearlas. No se usa para cálculo de totales.
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
  
  /// Obtiene el companyId desde cache (empresa_id de la licencia)
  /// Retorna null si no está disponible en cache
  int? _getCompanyIdFromCache() {
    try {
      final kv = getIt<CustomOdooKv>();
      final companyIdStr = kv.get('companyId');
      
      if (companyIdStr == null) {
        print('⚠️ SALE_ORDER_REPO: companyId no encontrado en cache');
        return null;
      }
      
      final companyId = int.tryParse(companyIdStr.toString());
      if (companyId == null) {
        print('⚠️ SALE_ORDER_REPO: companyId inválido en cache: $companyIdStr');
        return null;
      }
      
      print('✅ SALE_ORDER_REPO: companyId obtenido desde cache: $companyId');
      return companyId;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error obteniendo companyId desde cache: $e');
      return null;
    }
  }

  int? _getActiveUserId() {
    try {
      final kv = getIt<CustomOdooKv>();
      final userIdStr = kv.get('userId');
      if (userIdStr == null) {
        return null;
      }
      final cachedUserId = int.tryParse(userIdStr.toString());
      if (cachedUserId == null) {
        return null;
      }
      final sessionUserId = getIt<OdooSession>().userId;
      if (cachedUserId == sessionUserId) {
        // Fallback (admin) -> sin filtro para ver todo
        return null;
      }
      return cachedUserId;
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: Error obteniendo userId activo: $e');
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
      
      // Enriquecer datos con auditoría
      final enrichedData = _enrichOrderDataForWrite(orderData);
      
      // Verificar conectividad para aplicar patrón Local-First
      try {
        final state = await netConn.checkNetConn();
        print('🌐 DIAG_WRITE updateOrder net=${state.name}');
        if (state != netConnState.online) {
          // Modo offline: encolar operación y aplicar cambios localmente
          await _callQueue.updateRecord(modelName, orderId, enrichedData);
          await _applyLocalOrderUpdate(orderId, enrichedData);
          print('✅ SALE_ORDER_REPO: Orden $orderId actualizada localmente (offline)');
          return true;
        }
      } catch (_) {}
      
      // Modo online: ejecutar operación en servidor
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
            'kwargs': {},
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
        try {
          await env.orpc.callKw({
            'model': modelName,
            'method': 'write',
            'args': [[orderId], enrichedData],
            'kwargs': {},
          });
          print('🛒 SALE_ORDER_REPO: Write completado exitosamente');
        } catch (e) {
          print('❌ SALE_ORDER_REPO: Error en callKw: $e');
          print('❌ SALE_ORDER_REPO: Tipo de error: ${e.runtimeType}');
          
          // Intentar extraer más detalles del error de Odoo
          if (e is OdooException) {
            try {
              print('❌ SALE_ORDER_REPO: Error message: ${e.message}');
              print('❌ SALE_ORDER_REPO: Error toString completo: ${e.toString()}');
              
              // Intentar parsear el mensaje si contiene información estructurada
              final errorStr = e.toString();
              if (errorStr.contains('debug')) {
                try {
                  // Intentar extraer el debug del string
                  final debugMatch = RegExp(r'debug[:\s]+(Traceback[^\}]+)', multiLine: true).firstMatch(errorStr);
                  if (debugMatch != null) {
                    print('❌ SALE_ORDER_REPO: ========== ERROR DEBUG COMPLETO ==========');
                    print(debugMatch.group(1) ?? 'No se pudo extraer debug');
                    print('❌ SALE_ORDER_REPO: ===========================================');
                  }
                } catch (parseError) {
                  print('⚠️ SALE_ORDER_REPO: Error extrayendo debug: $parseError');
                }
              }
            } catch (logError) {
              print('⚠️ SALE_ORDER_REPO: Error al extraer detalles: $logError');
            }
          }
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
      try {
        final state = await netConn.checkNetConn();
        print('🌐 DIAG_WRITE createOrderLine net=${state.name}');
        if (state != netConnState.online) {
          // OFFLINE: Encolar operación y actualizar cache local
          final data = {
            'order_id': orderId,
            'product_id': productId,
            'product_uom_qty': quantity,
            if (priceUnit != null) 'price_unit': priceUnit,
          };
          await _callQueue.createRecord('sale.order.line', data);
          await _applyLocalLineCreate(orderId, productId, quantity, priceUnit);
          return -DateTime.now().millisecondsSinceEpoch; // id temporal negativo
        }
      } catch (_) {}
      
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
      try {
        final state = await netConn.checkNetConn();
        print('🌐 DIAG_WRITE updateOrderLine net=${state.name}');
        if (state != netConnState.online) {
          final data = <String, dynamic>{};
          if (quantity != null) data['product_uom_qty'] = quantity;
          if (priceUnit != null) data['price_unit'] = priceUnit;
          await _callQueue.updateRecord('sale.order.line', lineId, data);
          await _applyLocalLineUpdate(lineId, quantity: quantity, priceUnit: priceUnit);
          return;
        }
      } catch (_) {}
      
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
      try {
        final state = await netConn.checkNetConn();
        print('🌐 DIAG_WRITE deleteOrderLine net=${state.name}');
        if (state != netConnState.online) {
          await _callQueue.deleteRecord('sale.order.line', lineId);
          await _applyLocalLineDelete(lineId);
          return;
        }
      } catch (_) {}
      
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

  // === Helpers Local-First para líneas ===
  Future<void> _applyLocalLineCreate(int orderId, int productId, double qty, double? priceUnit) async {
    try {
      // Actualizar en memoria
      final idx = latestRecords.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        final order = latestRecords[idx];
        final newLine = SaleOrderLine(
          id: null,
          productId: productId,
          productName: '',
          productCode: null,
          quantity: qty,
          priceUnit: priceUnit ?? 0,
          priceSubtotal: (priceUnit ?? 0) * qty,
          taxesIds: const [],
        );
        final updated = order.copyWith(orderLines: List<SaleOrderLine>.from(order.orderLines)..add(newLine));
        latestRecords[idx] = updated;
        await _persistLatestRecords();
      }
    } catch (_) {}
  }

  Future<void> _applyLocalLineUpdate(int lineId, {double? quantity, double? priceUnit}) async {
    try {
      for (int i = 0; i < latestRecords.length; i++) {
        final order = latestRecords[i];
        final lineIdx = order.orderLines.indexWhere((l) => l.id == lineId);
        if (lineIdx >= 0) {
          final line = order.orderLines[lineIdx];
          final newQty = quantity ?? line.quantity;
          final newPrice = priceUnit ?? line.priceUnit;
          final updatedLine = line.copyWith(
            quantity: newQty,
            priceUnit: newPrice,
            priceSubtotal: newQty * newPrice,
          );
          final newLines = List<SaleOrderLine>.from(order.orderLines);
          newLines[lineIdx] = updatedLine;
          latestRecords[i] = order.copyWith(orderLines: newLines);
          await _persistLatestRecords();
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _applyLocalLineDelete(int lineId) async {
    try {
      for (int i = 0; i < latestRecords.length; i++) {
        final order = latestRecords[i];
        final newLines = order.orderLines.where((l) => l.id != lineId).toList();
        if (newLines.length != order.orderLines.length) {
          latestRecords[i] = order.copyWith(orderLines: newLines);
          await _persistLatestRecords();
          break;
        }
      }
    } catch (_) {}
  }

  /// Aplica cambios localmente a una orden (para modo offline)
  Future<void> _applyLocalOrderUpdate(int orderId, Map<String, dynamic> orderData) async {
    try {
      final idx = latestRecords.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        final order = latestRecords[idx];
        
        // Actualizar campos según orderData
        int? partnerShippingId = order.partnerShippingId;
        String? partnerShippingName = order.partnerShippingName;
        String? state = order.state;
        String? name = order.name;
        
        // Extraer partner_shipping_id
        if (orderData.containsKey('partner_shipping_id')) {
          final shippingIdValue = orderData['partner_shipping_id'];
          if (shippingIdValue is int) {
            partnerShippingId = shippingIdValue;
          } else if (shippingIdValue is List && shippingIdValue.isNotEmpty) {
            partnerShippingId = (shippingIdValue[0] as num?)?.toInt();
            if (shippingIdValue.length > 1 && shippingIdValue[1] is String) {
              partnerShippingName = shippingIdValue[1] as String;
            }
          }
        }
        
        // Extraer partner_shipping_name si viene separado
        if (orderData.containsKey('partner_shipping_name')) {
          partnerShippingName = orderData['partner_shipping_name'] as String?;
        }
        
        // Extraer state
        if (orderData.containsKey('state')) {
          state = orderData['state'] as String?;
        }
        
        // Extraer name
        if (orderData.containsKey('name')) {
          name = orderData['name'] as String?;
        }
        
        // Crear orden actualizada
        final updated = order.copyWith(
          partnerShippingId: partnerShippingId,
          partnerShippingName: partnerShippingName,
          state: state,
          name: name,
        );
        
        latestRecords[idx] = updated;
        await _persistLatestRecords();
        print('✅ SALE_ORDER_REPO: Orden $orderId actualizada localmente');
      }
    } catch (e) {
      print('⚠️ SALE_ORDER_REPO: Error aplicando actualización local: $e');
    }
  }

  Future<void> _persistLatestRecords() async {
    try {
      final cacheKey = 'sale_orders';
      final serialized = latestRecords.map((o) => o.toJson()).toList();
      if (tenantCache != null) {
        await tenantCache!.put(cacheKey, serialized);
      } else {
        await cache.put(cacheKey, serialized);
      }
    } catch (_) {}
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