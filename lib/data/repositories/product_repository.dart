import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/product_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';

/// Repository para manejar operaciones con Products en Odoo con soporte offline
class ProductRepository extends OfflineOdooRepository<Product> {
  final String modelName = 'product.product';
  
  // Parámetros de búsqueda y filtrado
  String _searchTerm = '';
  String? _type;
  int _limit = 80;
  int _offset = 0;

  ProductRepository(OdooEnvironment env, NetworkConnectivity netConn, OdooKv cache)
      : super(env, netConn, cache);

  @override
  List<String> get oFields => Product.oFields;

  @override
  Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);

  @override
  Future<List<dynamic>> searchRead() async {
    // Construcción del dominio dinámico
    final List<dynamic> domain = [
      ['active', '=', true],
      ['sale_ok', '=', true], // Solo productos que se pueden vender
    ];

    // Filtro por término de búsqueda (código o nombre del producto)
    if (_searchTerm.isNotEmpty) {
      domain.addAll([
        '|',
        ['name', 'ilike', _searchTerm],
        ['default_code', 'ilike', _searchTerm]
      ]);
    }

    // Filtro por tipo de producto
    if (_type != null && _type!.isNotEmpty) {
      domain.add(['type', '=', _type!]);
    }

    print('🔍 PRODUCT_REPO: Domain: $domain');
    print('🔍 PRODUCT_REPO: Fields: $oFields');
    
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
    
    print('🔍 PRODUCT_REPO: Response length: ${response is List ? response.length : 'N/A'}');
    return response as List<dynamic>;
  }

  /// Configura los parámetros de búsqueda y filtrado
  void setSearchParams({
    int limit = 80,
    int offset = 0,
    String searchTerm = '',
    String? type,
  }) {
    _limit = limit;
    _offset = offset;
    _searchTerm = searchTerm;
    _type = type;
  }

  /// Sobrescribe fetchRecords para implementar filtrado local offline
  @override
  Future<void> fetchRecords() async {
    try {
      if (await netConn.checkNetConn() == netConnState.online) {
        // ONLINE: Obtener datos frescos del servidor con filtros aplicados
        final recordsJson = await searchRead();
        print('🔍 PRODUCT_REPO: recordsJson length: ${recordsJson.length}');
        final records =
            recordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
        print('🔍 PRODUCT_REPO: records length after fromJson: ${records.length}');

        // Guardar en caché para uso offline (SIN filtros aplicados)
        // Primero obtenemos todos los datos sin filtros para la caché
        try {
          final allRecordsJson = await _getAllRecordsFromServer();
          final allRecords = allRecordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
          await cache.put('Product_records', allRecords.map((r) => r.toJson()).toList());
          print('🔍 PRODUCT_REPO: Cache updated successfully');
        } catch (e) {
          print('🔍 PRODUCT_REPO: Error updating cache: $e');
        }
        
        // Actualizar la lista local con los datos filtrados
        latestRecords = records;
        print('🔍 PRODUCT_REPO: latestRecords assigned: ${latestRecords.length}');
      } else {
        // OFFLINE: Cargar datos desde la caché local y aplicar filtros localmente
        final cachedData = cache.get('Product_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final allCachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
        } else {
          latestRecords = <Product>[];
        }
      }
    } on OdooException {
      // Si hay un error de Odoo (ej. sesión expirada), lo relanzamos
      rethrow;
    } catch (_) {
      // Para otros errores (ej. de red), intentamos cargar desde caché como fallback
      try {
        final cachedData = cache.get('Product_records', defaultValue: <Map<String, dynamic>>[]);
        if (cachedData is List) {
          final allCachedRecords = cachedData.map((json) => fromJson(json as Map<String, dynamic>)).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
        } else {
          latestRecords = <Product>[];
        }
      } catch (cacheErr) {
        // Si la caché también falla, emitimos una lista vacía
        latestRecords = <Product>[];
      }
    }
  }

  /// Obtiene todos los registros del servidor sin filtros (para caché)
  Future<List<dynamic>> _getAllRecordsFromServer() async {
    print('🔍 PRODUCT_REPO: _getAllRecordsFromServer() called');
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['active', '=', true],
          ['sale_ok', '=', true],
        ], // Solo productos activos y vendibles
        'fields': oFields,
        'limit': 1000, // Límite alto para obtener más datos
        'offset': 0,
      },
    });
    print('🔍 PRODUCT_REPO: _getAllRecordsFromServer() response length: ${response is List ? response.length : 'N/A'}');
    return response as List<dynamic>;
  }

  /// Aplica filtros localmente a los datos en caché
  List<Product> _applyLocalFilters(List<Product> allRecords) {
    List<Product> filteredRecords = allRecords;

    // Aplicar filtro por término de búsqueda
    if (_searchTerm.isNotEmpty) {
      filteredRecords = filteredRecords.where((product) {
        final nameMatch = product.name.toLowerCase().contains(_searchTerm.toLowerCase());
        final codeMatch = (product.defaultCode ?? '').toLowerCase().contains(_searchTerm.toLowerCase());
        return nameMatch || codeMatch;
      }).toList();
    }

    // Aplicar filtro por tipo
    if (_type != null && _type!.isNotEmpty) {
      filteredRecords = filteredRecords.where((product) => product.type == _type).toList();
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
      filteredRecords = <Product>[];
    }

    return filteredRecords;
  }

  /// Dispara la carga de records desde el servidor (con soporte offline)
  Future<void> loadRecords() async {
    print('📦 PRODUCT_REPO: Iniciando loadRecords() con soporte offline');
    print('📦 PRODUCT_REPO: Modelo: $modelName');
    print('📦 PRODUCT_REPO: Filtros - searchTerm: "$_searchTerm", type: "$_type"');

    try {
      print('⏳ PRODUCT_REPO: Llamando fetchRecords()...');
      await fetchRecords(); // Usa nuestro método sobrescrito con filtrado local
      print('✅ PRODUCT_REPO: fetchRecords() ejecutado');
      print('📊 PRODUCT_REPO: Records actuales: ${latestRecords.length}');
    } catch (e) {
      print('❌ PRODUCT_REPO: Error en loadRecords(): $e');
      print('❌ PRODUCT_REPO: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Obtiene productos por tipo
  Future<List<Product>> getProductsByType(String type) async {
    setSearchParams(type: type);
    await loadRecords();
    return latestRecords;
  }

  /// Busca productos por nombre o código
  Future<List<Product>> searchProducts(String searchTerm) async {
    setSearchParams(searchTerm: searchTerm);
    await loadRecords();
    return latestRecords;
  }

  /// Obtiene un producto por ID
  Future<Product?> getProductById(int id) async {
    await loadRecords();
    try {
      return latestRecords.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }
}

