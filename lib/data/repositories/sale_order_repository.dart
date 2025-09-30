import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/sale_order_model.dart';
import '../models/sale_order_line_model.dart';
import '../models/order_totals_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import '../../core/di/injection_container.dart';

/// Repository para manejar operaciones con Sale Orders en Odoo con soporte offline
class SaleOrderRepository extends OfflineOdooRepository<SaleOrder> {
  final String modelName = 'sale.order';
  String _searchTerm = '';
  String? _state;
  int _limit = 80;
  int _offset = 0;
  
  // Cache para totales calculados
  final Map<String, OrderTotals> _totalsCache = {};

  SaleOrderRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache);

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
        await cache.put('sale_orders', jsonData);
        print('💾 SALE_ORDER_REPO: Records cached locally');
        
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
      final result = await searchRead();
      return result.map((record) => fromJson(record)).toList();
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error getting records from server: $e');
      return [];
    }
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
      
      final cachedData = cache.get('sale_orders') as List<dynamic>?;
      if (cachedData != null) {
        final cachedRecords = cachedData.map((record) => fromJson(record)).toList();
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

  /// Crea una nueva orden de venta
  Future<Map<String, dynamic>> createSaleOrder(Map<String, dynamic> orderData) async {
    try {
      print('🛒 SALE_ORDER_REPO: Creando nueva orden de venta...');
      // Log explícito del cuerpo de la petición
      print('🔵 REQUEST BODY CREATE SALE ORDER (antes de enriquecer): $orderData');

      // Inyectar pricelist_id si no viene, usando el partner
      if (!orderData.containsKey('pricelist_id') && orderData['partner_id'] != null) {
        final partnerId = (orderData['partner_id'] as num).toInt();
        final pricelistId = await _getPartnerPricelistId(partnerId);
        if (pricelistId != null) {
          orderData = Map<String, dynamic>.from(orderData);
          orderData['pricelist_id'] = pricelistId;
          print('🧮 SALE_ORDER_REPO: Inyectado pricelist_id=$pricelistId para partner $partnerId');
        }
      }

      print('🔵 REQUEST BODY CREATE SALE ORDER (final): $orderData');

      final response = await env.orpc.callKw({
        'model': modelName,
        'method': 'create',
        'args': [orderData],
        'kwargs': {},
      });

      final orderId = response as int;
      print('✅ SALE_ORDER_REPO: Orden creada exitosamente con ID: $orderId');

      // Obtener los datos completos de la orden creada
      final orderDetails = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[orderId]],
        'kwargs': {
          'fields': oFields,
        },
      });

      final createdOrderData = (orderDetails as List).first as Map<String, dynamic>;
      print('📋 SALE_ORDER_REPO: Datos de la orden creada: $createdOrderData');

      return {
        'success': true,
        'order_id': orderId,
        'order_data': createdOrderData,
      };
    } on OdooException catch (e) {
      print('❌ SALE_ORDER_REPO: Error de Odoo al crear orden: $e');
      return {
        'success': false,
        'error': 'Error del servidor: ${e.message}',
      };
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error general al crear orden: $e');
      return {
        'success': false,
        'error': 'Error inesperado: $e',
      };
    }
  }

  /// Actualiza el estado de una orden de venta
  Future<bool> updateOrderState(int orderId, String newState) async {
    try {
      print('🛒 SALE_ORDER_REPO: Actualizando estado de orden $orderId a $newState');

      await env.orpc.callKw({
        'model': modelName,
        'method': 'write',
        'args': [[orderId], {'state': newState}],
        'kwargs': {},
      });

      print('✅ SALE_ORDER_REPO: Estado actualizado exitosamente');
      return true;
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error actualizando estado: $e');
      return false;
    }
  }

  /// Calcula totales usando funciones de Odoo con cache
  Future<OrderTotals> calculateOrderTotals({
    required int partnerId,
    required List<SaleOrderLine> orderLines,
  }) async {
    try {
      // Generar clave de cache
      final cacheKey = _generateTotalsCacheKey(partnerId, orderLines);
      
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
      
      try {
        // Crear una orden temporal para calcular totales
        print('🧮 SALE_ORDER_REPO: Creando orden temporal para cálculo...');
        final tempOrderId = await env.orpc.callKw({
          'model': 'sale.order',
          'method': 'create',
          'args': [tempOrderData], // ← Usar tempOrderData en lugar de duplicar
          'kwargs': {},
        });
        
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
        final taxGroups = await _getTaxGroupsFromOrder(tempOrderId);
        
        // Eliminar la orden temporal
        await env.orpc.callKw({
          'model': 'sale.order',
          'method': 'unlink',
          'args': [[tempOrderId]],
          'kwargs': {},
        });
        
        final totals = OrderTotals(
          amountUntaxed: (order['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
          amountTax: (order['amount_tax'] as num?)?.toDouble() ?? 0.0,
          amountTotal: (order['amount_total'] as num?)?.toDouble() ?? 0.0,
          taxGroups: taxGroups,
        );
        
        // Guardar en cache
        _totalsCache[cacheKey] = totals;
        _cleanupCache(); // Limpiar cache si es muy grande
        
        print('✅ SALE_ORDER_REPO: Totales calculados con Odoo: ${totals.amountTotal}');
        return totals;
        
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
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error calculando totales: $e');
      // Fallback a cálculo local
      return _calculateLocalTotals(orderLines);
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
    return {
      'partner_id': partnerId,
      'user_id': getIt<OdooSession>().userId, // Agregar user_id para evitar AccessError
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

  /// Obtiene una orden de venta específica por ID
  Future<SaleOrder?> getOrderById(int orderId) async {
    try {
      print('🛒 SALE_ORDER_REPO: Obteniendo orden $orderId...');
      
      final result = await env.orpc.callKw({
        'model': modelName,
        'method': 'read',
        'args': [[orderId]],
        'kwargs': {
          'fields': oFields,
        },
      });
      
      if (result is List && result.isNotEmpty) {
        final order = fromJson(result.first);
        print('✅ SALE_ORDER_REPO: Orden $orderId obtenida');
        return order;
      }
      
      print('⚠️ SALE_ORDER_REPO: Orden $orderId no encontrada');
      return null;
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error obteniendo orden $orderId: $e');
      return null;
    }
  }

  /// Actualiza una orden de venta existente
  Future<bool> updateOrder(int orderId, Map<String, dynamic> orderData) async {
    try {
      print('🛒 SALE_ORDER_REPO: Actualizando orden $orderId...');
      
      await env.orpc.callKw({
        'model': modelName,
        'method': 'write',
        'args': [[orderId], orderData],
      });
      
      print('✅ SALE_ORDER_REPO: Orden $orderId actualizada');
      return true;
      
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error actualizando orden $orderId: $e');
      return false;
    }
  }
}