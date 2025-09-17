import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/sale_order_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';

/// Repository para manejar operaciones con Sale Orders en Odoo con soporte offline
class SaleOrderRepository extends OfflineOdooRepository<SaleOrder> {
  final String modelName = 'sale.order';
  
  // Parámetros de búsqueda y filtrado
  String _searchTerm = '';
  String? _state;
  int _limit = 80;
  int _offset = 0;

  SaleOrderRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache);

  @override
  List<String> get oFields => SaleOrder.oFields;

  @override
  SaleOrder fromJson(Map<String, dynamic> json) => SaleOrder.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    // Construcción del dominio dinámico
    final List<dynamic> domain = [];

    // Filtro por término de búsqueda (nombre del pedido o nombre del cliente)
    if (_searchTerm.isNotEmpty) {
      domain.addAll([
        '|',
        ['name', 'ilike', _searchTerm],
        ['partner_id', 'ilike', _searchTerm]
      ]);
    }

    // Filtro por estado
    if (_state != null && _state!.isNotEmpty) {
      domain.add(['state', '=', _state!]);
    }

    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': domain,
        'fields': oFields,
        'limit': _limit,
        'offset': _offset,
      },
    });
    return response as List<dynamic>;
  }

  /// Configura los parámetros de búsqueda y filtrado
  void setSearchParams({
    int limit = 80,
    int offset = 0,
    String searchTerm = '',
    String? state,
  }) {
    _limit = limit;
    _offset = offset;
    _searchTerm = searchTerm;
    _state = state;
  }

  /// Sobrescribe fetchRecords para implementar filtrado local offline
  @override
  Future<void> fetchRecords() async {
    try {
      if (await netConn.checkNetConn() == netConnState.online) {
        // ONLINE: Obtener datos frescos del servidor con filtros aplicados
        final recordsJson = await searchRead();
        final records =
            recordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();

        // Guardar en caché para uso offline (SIN filtros aplicados)
        // Primero obtenemos todos los datos sin filtros para la caché
        final allRecordsJson = await _getAllRecordsFromServer();
        final allRecords = allRecordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
        await cache.put('SaleOrder_records', allRecords.map((r) => r.toJson()).toList());
        
        // Actualizar la lista local con los datos filtrados
        latestRecords = records;
      } else {
        // OFFLINE: Cargar datos desde la caché local y aplicar filtros localmente
        final cachedData = cache.get('SaleOrder_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final allCachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
        } else {
          latestRecords = <SaleOrder>[];
        }
      }
    } on OdooException {
      // Si hay un error de Odoo (ej. sesión expirada), lo relanzamos
      rethrow;
    } catch (_) {
      // Para otros errores (ej. de red), intentamos cargar desde caché como fallback
      try {
        final cachedData = cache.get('SaleOrder_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final allCachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
        } else {
          latestRecords = <SaleOrder>[];
        }
      } catch (cacheErr) {
        // Si la caché también falla, emitimos una lista vacía
        latestRecords = <SaleOrder>[];
      }
    }
  }

  /// Obtiene todos los registros del servidor sin filtros (para caché)
  Future<List<dynamic>> _getAllRecordsFromServer() async {
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [], // Sin filtros para obtener todos los datos
        'fields': oFields,
        'limit': 1000, // Límite alto para obtener más datos
        'offset': 0,
      },
    });
    return response as List<dynamic>;
  }

  /// Aplica filtros localmente a los datos en caché
  List<SaleOrder> _applyLocalFilters(List<SaleOrder> allRecords) {
    List<SaleOrder> filteredRecords = allRecords;

    // Aplicar filtro por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      filteredRecords = filteredRecords.where((order) {
        final nameMatch = order.name.toLowerCase().contains(_searchTerm.toLowerCase());
        final partnerMatch = (order.partnerName ?? '').toLowerCase().contains(_searchTerm.toLowerCase());
        return nameMatch || partnerMatch;
      }).toList();
    }

    // Aplicar filtro por estado
    if (_state != null && _state!.isNotEmpty) {
      filteredRecords = filteredRecords.where((order) => order.state == _state).toList();
    }

    // Aplicar límite y offset
    final startIndex = _offset;
    final endIndex = startIndex + _limit;
    if (startIndex < filteredRecords.length) {
      filteredRecords = filteredRecords.sublist(
        startIndex,
        endIndex > filteredRecords.length ? filteredRecords.length : endIndex,
      );
    } else {
      filteredRecords = <SaleOrder>[];
    }

    return filteredRecords;
  }

  /// Dispara la carga de records desde el servidor (con soporte offline)
  Future<void> loadRecords() async {
    print('🛒 SALE_ORDER_REPO: Iniciando loadRecords() con soporte offline');
    print('🛒 SALE_ORDER_REPO: Modelo: $modelName');
    print('🛒 SALE_ORDER_REPO: Filtros - searchTerm: "$_searchTerm", state: "$_state"');

    try {
      print('⏳ SALE_ORDER_REPO: Llamando fetchRecords()...');
      await fetchRecords(); // Usa nuestro método sobrescrito con filtrado local
      print('✅ SALE_ORDER_REPO: fetchRecords() ejecutado');
      print('📊 SALE_ORDER_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ SALE_ORDER_REPO: Error en loadRecords(): $e');
      print('❌ SALE_ORDER_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }
}
