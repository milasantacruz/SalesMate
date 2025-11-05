import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/product_model.dart';
import 'offline_odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import 'odoo_call_queue_repository.dart';
import '../../core/di/injection_container.dart';
import '../../core/cache/custom_odoo_kv.dart';

/// Repository para manejar operaciones con Products en Odoo con soporte offline
class ProductRepository extends OfflineOdooRepository<Product> {
  final String modelName = 'product.product';
  late final OdooCallQueueRepository _callQueue;
  
  // Parámetros de búsqueda y filtrado
  String _searchTerm = '';
  String? _type;
  int _limit = 80;
  int _offset = 0;

  ProductRepository(
    OdooEnvironment env,
    NetworkConnectivity netConn,
    OdooKv cache, {
    super.tenantCache,
  }) : super(env, netConn, cache) {
    // Inicializar _callQueue desde dependency injection
    _callQueue = getIt<OdooCallQueueRepository>();
  }

  @override
  List<String> get oFields => Product.oFields;

  @override
  Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);

  /// Obtiene tarifa_id de la licencia desde cache
  int? _getTarifaIdFromLicense() {
    try {
      final kv = getIt<CustomOdooKv>();
      final tarifaIdStr = kv.get('tarifaId');
      if (tarifaIdStr != null) {
        final tarifaId = int.tryParse(tarifaIdStr.toString());
        print('💰 PRODUCT_REPO: tarifa_id obtenido de licencia: $tarifaId');
        return tarifaId;
      }
      print('⚠️ PRODUCT_REPO: No se encontró tarifa_id en cache');
      return null;
    } catch (e) {
      print('❌ PRODUCT_REPO: Error obteniendo tarifa_id: $e');
      return null;
    }
  }

  @override
  Future<List<dynamic>> searchRead() async {
    // Obtener tarifa_id de la licencia (solo para referencia, no para filtrar)
    final tarifaId = _getTarifaIdFromLicense();
    
    // Construcción del dominio dinámico
    final List<dynamic> domain = [
      ['active', '=', true],
      ['sale_ok', '=', true], // Solo productos que se pueden vender
    ];

    // ✅ Mostrar TODOS los productos vendibles (sin filtro de tarifa)
    // La tarifa se usará solo para calcular precios (ver Fase 2)
    print('💰 PRODUCT_REPO: Mostrando todos los productos vendibles');
    if (tarifaId != null) {
      print('💰 PRODUCT_REPO: Tarifa de licencia (solo para cálculo de precio): $tarifaId');
    } else {
      print('⚠️ PRODUCT_REPO: No hay tarifa_id configurada (se usará list_price por defecto)');
    }

    // Filtro por término de búsqueda (código o nombre del producto)
    if (_searchTerm.isNotEmpty) {
      domain.addAll([
        '|',
        ['name', 'ilike', _searchTerm],
        ['default_code', 'ilike', _searchTerm]
      ]);
    }

    // Filtro por tipo de producto con nueva lógica (type + is_storable)
    if (_type != null && _type!.isNotEmpty) {
      if (_type == 'product') {
        // Producto: type=consu AND is_storable=true
        domain.addAll([
          ['type', '=', 'consu'],
          ['is_storable', '=', true],
        ]);
      } else if (_type == 'consu') {
        // Consumible: type=consu AND is_storable=false
        domain.addAll([
          ['type', '=', 'consu'],
          ['is_storable', '=', false],
        ]);
      } else if (_type == 'service') {
        // Servicio: type=service AND is_storable=false
        domain.addAll([
          ['type', '=', 'service'],
          ['is_storable', '=', false],
        ]);
      } else {
        domain.add(['type', '=', _type!]);
      }
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
        
        try {
          print('🔍 PRODUCT_REPO: Iniciando conversión de ${recordsJson.length} items...');
          final records =
              recordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
          print('🔍 PRODUCT_REPO: records length after fromJson: ${records.length}');

          // ✅ PRIMERO: Actualizar la lista local INMEDIATAMENTE
          latestRecords = records;
          print('✅ PRODUCT_REPO: latestRecords assigned IMMEDIATELY: ${latestRecords.length}');
        } catch (conversionError) {
          print('❌ PRODUCT_REPO: Error convirtiendo records: $conversionError');
          latestRecords = [];
          rethrow;
        }

        // DESPUÉS: Guardar en caché para uso offline (en background, no bloquea)
        // Obtenemos todos los datos sin filtros para la caché
        try {
          final allRecordsJson = await _getAllRecordsFromServer();
          final allRecords = allRecordsJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
          
          // 🔍 DIAGNÓSTICO: Verificar qué cache se está usando para guardar
          print('🔍 DIAGNÓSTICO PRODUCT (SAVE): tenantCache != null: ${tenantCache != null}');
          
          if (tenantCache != null) {
            print('🔍 DIAGNÓSTICO PRODUCT (SAVE): Guardando en tenantCache');
            await tenantCache!.put('Product_records', allRecords.map((r) => r.toJson()).toList());
            print('✅ PRODUCT_REPO: Cache guardado usando tenantCache con ${allRecords.length} records');
          } else {
            print('🔍 DIAGNÓSTICO PRODUCT (SAVE): Guardando en cache normal');
            await cache.put('Product_records', allRecords.map((r) => r.toJson()).toList());
            print('✅ PRODUCT_REPO: Cache guardado usando cache normal con ${allRecords.length} records');
          }
        } catch (e) {
          print('⚠️ PRODUCT_REPO: Error updating full cache (latestRecords still valid): $e');
        }
      } else {
        // OFFLINE: Cargar datos desde la caché local y aplicar filtros localmente
        print('📴 DIAGNÓSTICO PRODUCT: Modo OFFLINE - cargando desde cache');
        
        // 🔍 DIAGNÓSTICO: Verificar qué cache se está usando
        print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): tenantCache != null: ${tenantCache != null}');
        
        dynamic cachedData;
        if (tenantCache != null) {
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Buscando en tenantCache');
          cachedData = tenantCache!.get('Product_records');
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Datos encontrados en tenantCache: ${cachedData != null}');
          if (cachedData != null) {
            print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Tipo: ${cachedData.runtimeType}');
            print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Es List: ${cachedData is List}');
            if (cachedData is List) {
              print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Length: ${cachedData.length}');
            }
          }
        } else {
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): tenantCache es null, usando cache normal');
        }
        
        if (cachedData == null) {
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Intentando con cache normal...');
          cachedData = cache.get('Product_records', defaultValue: <Map<String, dynamic>>[]);
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Datos encontrados en cache normal: ${cachedData != null}');
        }
        
        cachedData ??= <Map<String, dynamic>>[];
        
        if (cachedData is List) {
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Convirtiendo ${cachedData.length} elementos...');
          // ✅ FIX: Usar Map.from() en lugar de cast directo
          final allCachedRecords = cachedData.map((json) => fromJson(Map<String, dynamic>.from(json))).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): Después de filtros: ${latestRecords.length}');
        } else {
          latestRecords = <Product>[];
          print('🔍 DIAGNÓSTICO PRODUCT (OFFLINE): cachedData NO es List');
        }
      }
    } on OdooException {
      // Si hay un error de Odoo (ej. sesión expirada), lo relanzamos
      rethrow;
    } catch (e) {
      // Para otros errores (ej. de red), intentamos cargar desde caché como fallback
      print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Error capturado, intentando cargar desde cache');
      print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Error tipo: ${e.runtimeType}');
      print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): tenantCache != null: ${tenantCache != null}');
      
      try {
        dynamic cachedData;
        
        if (tenantCache != null) {
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Buscando en tenantCache');
          cachedData = tenantCache!.get('Product_records');
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Datos encontrados en tenantCache: ${cachedData != null}');
          if (cachedData != null && cachedData is List) {
            print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Length: ${cachedData.length}');
          }
        }
        
        if (cachedData == null) {
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Intentando con cache normal...');
          cachedData = cache.get('Product_records', defaultValue: <Map<String, dynamic>>[]);
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Datos encontrados en cache normal: ${cachedData != null}');
        }
        
        cachedData ??= <Map<String, dynamic>>[];
        
        if (cachedData is List) {
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Convirtiendo ${cachedData.length} elementos...');
          // ✅ FIX: Usar Map.from() en lugar de cast directo
          final allCachedRecords = cachedData.map((json) => fromJson(Map<String, dynamic>.from(json))).toList();
          // Aplicar filtros localmente
          latestRecords = _applyLocalFilters(allCachedRecords);
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Después de filtros: ${latestRecords.length}');
        } else {
          latestRecords = <Product>[];
          print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): cachedData NO es List');
        }
      } catch (cacheErr) {
        // Si la caché también falla, emitimos una lista vacía
        print('🔍 DIAGNÓSTICO PRODUCT (ERROR CATCH): Error en cache: $cacheErr');
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

    // Aplicar filtro por tipo con nueva lógica (type + is_storable)
    if (_type != null && _type!.isNotEmpty) {
      if (_type == 'product') {
        filteredRecords = filteredRecords
            .where((p) => p.type == 'consu' && p.isStorable == true)
            .toList();
      } else if (_type == 'consu') {
        filteredRecords = filteredRecords
            .where((p) => p.type == 'consu' && p.isStorable == false)
            .toList();
      } else if (_type == 'service') {
        filteredRecords = filteredRecords
            .where((p) => p.type == 'service' && p.isStorable == false)
            .toList();
      } else {
        filteredRecords = filteredRecords.where((p) => p.type == _type).toList();
      }
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

  /// Crea un nuevo producto (offline/online según conectividad)
  Future<String> createProduct(Product product) async {
    return await _callQueue.createRecord(modelName, product.toJson());
  }

  /// Actualiza un producto existente (offline/online según conectividad)
  Future<void> updateProduct(Product product) async {
    await _callQueue.updateRecord(modelName, product.id, product.toJson());
  }

  /// Elimina permanentemente un producto (offline/online según conectividad)
  Future<void> deleteProduct(int id) async {
    await _callQueue.deleteRecord(modelName, id);
  }

  /// Obtiene registros incrementales para sincronización
  Future<List<Map<String, dynamic>>> fetchIncrementalRecords(String since) async {
    print('🔄 PRODUCT_REPO: Fetch incremental desde $since');
    
    final response = await env.orpc.callKw({
      'model': modelName,
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [
          ['active', '=', true],
          ['sale_ok', '=', true],
          ['write_date', '>', since], // 👈 Filtro de fecha incremental
        ],
        'fields': oFields,
        'limit': 1000, // Alto límite (usualmente pocos cambios)
        'offset': 0,
        'order': 'write_date asc',
      },
    });
    
    final records = response as List<dynamic>;
    print('🔄 PRODUCT_REPO: ${records.length} registros incrementales obtenidos');
    
    // Convertir cada record a Map<String, dynamic> para evitar errores de tipo
    return records.map((record) => Map<String, dynamic>.from(record)).toList();
  }
}

