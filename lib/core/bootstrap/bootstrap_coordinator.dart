import 'dart:async';

import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../http/odoo_client_mobile.dart';

import '../di/injection_container.dart';
import '../network/network_connectivity.dart';
import '../cache/custom_odoo_kv.dart';
import '../session/session_ready.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/sale_order_repository.dart';
import '../../data/repositories/shipping_address_repository.dart';
import 'bootstrap_state.dart';
import '../sync/sync_marker_store.dart';

/// Coordinador de Bootstrap de caché para datasets críticos
class BootstrapCoordinator {
  final NetworkConnectivity _netConn;
  final CustomOdooKv _cache;
  final PartnerRepository _partnerRepo;
  final ProductRepository _productRepo;
  final EmployeeRepository _employeeRepo;
  final SaleOrderRepository _saleOrderRepo;
  final ShippingAddressRepository _shippingAddressRepo;

  BootstrapCoordinator()
      : _netConn = getIt<NetworkConnectivity>(),
        _cache = getIt<CustomOdooKv>(),
        _partnerRepo = getIt<PartnerRepository>(),
        _productRepo = getIt<ProductRepository>(),
        _employeeRepo = getIt<EmployeeRepository>(),
        _saleOrderRepo = getIt<SaleOrderRepository>(),
        _shippingAddressRepo = getIt<ShippingAddressRepository>();

  /// Callback de progreso
  void Function(BootstrapState)? onProgress;

  /// Estado actual del bootstrap (compartido entre métodos paralelos)
  late BootstrapState _currentState;

  /// Módulos mínimos requeridos para considerar la app "offline ready"
  final Set<BootstrapModule> _minimumModules = {
    BootstrapModule.partners,
    BootstrapModule.products,
    BootstrapModule.employees,
    BootstrapModule.shippingAddresses,
  };

  Future<BootstrapState> run({int pageSize = 200}) async {
    final started = DateTime.now();
    _currentState = BootstrapState(
      modules: {
        for (final m in BootstrapModule.values)
          m: ModuleBootstrapStatus(module: m),
      },
      startedAt: started,
    );

    void report() {
      if (onProgress != null) {
        print('📢 BOOTSTRAP_COORDINATOR: Reportando progreso a BLoC');
        print('   - Partners: ${_currentState.modules[BootstrapModule.partners]?.completed}');
        print('   - Products: ${_currentState.modules[BootstrapModule.products]?.completed}');
        print('   - Employees: ${_currentState.modules[BootstrapModule.employees]?.completed}');
        print('   - Shipping Addresses: ${_currentState.modules[BootstrapModule.shippingAddresses]?.completed}');
        print('   - Sale Orders: ${_currentState.modules[BootstrapModule.saleOrders]?.completed}');
        onProgress!(_currentState);
      } else {
        print('⚠️ BOOTSTRAP_COORDINATOR: onProgress callback es null');
      }
    }

    // Requiere estar online
    if (await _netConn.checkNetConn() != netConnState.online) {
      // No modificamos nada si no hay red
      report();
      return _currentState;
    }

      // 🔄 Esperar a que complete la re-autenticación silenciosa (si está en progreso)
      print('⏳ BOOTSTRAP_COORDINATOR: Esperando re-autenticación...');
      await SessionReadyCoordinator.waitIfReauthenticationInProgress();
      print('✅ BOOTSTRAP_COORDINATOR: Re-autenticación completada');

      // Asegurar que existe una sesión válida antes de iniciar bootstrap
      await _ensureSessionValid();

      try {
      // Ejecutar en paralelo los módulos mínimos para maximizar chances antes de desconexión
      // Con timeout de 30 segundos
      await Future.wait([
        _bootstrapPartners(pageSize).then((_) { 
          print('✅ COORDINATOR: Partners completado en paralelo');
          report();
        }),
        _bootstrapProducts(pageSize).then((_) { 
          print('✅ COORDINATOR: Products completado en paralelo');
          report();
        }),
        _bootstrapEmployees(pageSize).then((_) { 
          print('✅ COORDINATOR: Employees completado en paralelo');
          report();
        }),
        _bootstrapShippingAddresses(pageSize).then((_) { 
          print('✅ COORDINATOR: Shipping Addresses completado en paralelo');
          report();
        }),
      ]).timeout(const Duration(seconds: 30), onTimeout: () async {
        print('⏰ BOOTSTRAP_COORDINATOR: Timeout de 30s alcanzado');
        return [];
      });

      // Luego ejecutar órdenes (no bloquea el mínimo offline)
      await _bootstrapSaleOrders(pageSize);
      report();
    } catch (e) {
      print('⏰ BOOTSTRAP_COORDINATOR: Error o timeout durante bootstrap: $e');
    }

    _currentState = _currentState.copyWith(completedAt: DateTime.now());
    await _cache.put('bootstrap_last_completed_at', _currentState.completedAt!.toIso8601String());
    
    // 📌 Registrar marcadores de sincronización para incremental sync
    await _registerSyncMarkers();
    
    report();
    return _currentState;
  }

  /// Registra marcadores de sincronización después del bootstrap completo
  /// 
  /// Esto permite que futuras reconexiones usen sincronización incremental
  /// en lugar de bootstrap completo
  Future<void> _registerSyncMarkers() async {
    try {
      print('📌 BOOTSTRAP_COORDINATOR: Registrando marcadores de sincronización...');
      
      final markerStore = getIt<SyncMarkerStore>();
      final now = DateTime.now().toUtc();
      
      await markerStore.setMultipleMarkers({
        'res.partner': now,
        'product.product': now,
        'hr.employee': now,
        'res.partner.delivery': now,
        'sale.order': now,
      });
      
      print('✅ BOOTSTRAP_COORDINATOR: Marcadores de sincronización registrados');
      print('   📅 Timestamp: ${now.toIso8601String()}');
    } catch (e) {
      print('❌ BOOTSTRAP_COORDINATOR: Error registrando marcadores: $e');
      // No relanzar error, no es crítico
    }
  }


  /// Espera hasta que el OdooClient tenga una sesión válida (sessionId no vacío)
  /// y que las cookies estén completamente procesadas
  Future<void> _ensureSessionValid({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final client = getIt<OdooClient>();
      final start = DateTime.now();
      print('🔒 BOOTSTRAP_COORDINATOR: Esperando sesión válida...');
      
      while (true) {
        final sid = client.sessionId; // OdooSession
        final hasValidSession = sid != null && sid.id.isNotEmpty;
        
        // Verificar también que las cookies estén disponibles en el CookieClient
        bool hasValidCookies = false;
        try {
          if (client.httpClient is CookieClient) {
            final cookieClient = client.httpClient as CookieClient;
            final cookies = cookieClient.getCookies();
            hasValidCookies = cookies.containsKey('session_id') && 
              cookies['session_id']!.isNotEmpty;
            print('🍪 BOOTSTRAP_COORDINATOR: Cookies disponibles: ${hasValidCookies ? "SÍ" : "NO"}');
            if (cookies.isNotEmpty) {
              print('🍪 BOOTSTRAP_COORDINATOR: Cookies encontradas: ${cookies.keys.join(", ")}');
            }
          }
        } catch (e) {
          print('⚠️ BOOTSTRAP_COORDINATOR: Error verificando cookies: $e');
        }
        
        if (hasValidSession && hasValidCookies) {
          print('✅ BOOTSTRAP_COORDINATOR: SessionId y cookies válidos encontrados');
          print('   - SessionId: ${sid.id.substring(0, 8)}...');
          print('   - Cookies: OK');
          // Delay adicional para asegurar que las cookies estén procesadas
          await Future.delayed(const Duration(milliseconds: 1000));
          print('🔒 BOOTSTRAP_COORDINATOR: Sesión lista para bootstrap');
          break;
        }
        
        if (DateTime.now().difference(start) >= timeout) {
          print('⏳ BOOTSTRAP_COORDINATOR: Timeout esperando sessionId y cookies válidos');
          print('   - SessionId válido: ${hasValidSession ? "SÍ" : "NO"}');
          print('   - Cookies válidas: ${hasValidCookies ? "SÍ" : "NO"}');
          break;
        }
        
        print('⏳ BOOTSTRAP_COORDINATOR: Esperando sessionId y cookies... (${DateTime.now().difference(start).inSeconds}s)');
        print('   - SessionId: ${hasValidSession ? "OK" : "PENDIENTE"}');
        print('   - Cookies: ${hasValidCookies ? "OK" : "PENDIENTE"}');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('⚠️ BOOTSTRAP_COORDINATOR: No se pudo verificar sesión antes de bootstrap: $e');
    }
  }

  bool isMinimumReady(BootstrapState state) {
    return _minimumModules
        .every((m) => state.modules[m]?.completed == true);
  }

    Future<void> _bootstrapPartners(int pageSize) async {
      final m = BootstrapModule.partners;
      int page = 0;
      int totalFetched = 0;
      int offset = 0;
      final List<Map<String, dynamic>> allRecordsJson = [];
      
      try {
        print('👥 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de partners con paginación...');
        
        // Loop de paginación
        while (true) {
          print('👥 BOOTSTRAP_COORDINATOR: Página ${page + 1} - offset: $offset, limit: $pageSize');
          
          // Hacer llamada directa a search_read con offset y limit
          final response = await _partnerRepo.env.orpc.callKw({
            'model': 'res.partner',
            'method': 'search_read',
            'args': [],
            'kwargs': {
              'context': {'bin_size': true},
              'domain': [
                ['active', '=', true],
                ['type', '=', 'contact'],
              ],
              'fields': _partnerRepo.oFields,
              'limit': pageSize,
              'offset': offset,
              'order': 'name'
            },
          });
          
          final pageRecords = response as List<dynamic>;
          final pageCount = pageRecords.length;
          print('👥 BOOTSTRAP_COORDINATOR: Página ${page + 1} - ${pageCount} registros obtenidos');
          
          // Agregar a la lista acumulada
          allRecordsJson.addAll(pageRecords.cast<Map<String, dynamic>>());
          totalFetched += pageCount;
          page++;
          
          // Actualizar progreso
          _currentState = _updateModule(_currentState, m, page, totalFetched, completed: false);
          if (onProgress != null) onProgress!(_currentState);
          
          // Si obtuvimos menos registros que pageSize, ya no hay más páginas
          if (pageCount < pageSize) {
            print('👥 BOOTSTRAP_COORDINATOR: Última página alcanzada (${pageCount} < $pageSize)');
            break;
          }
          
          // Incrementar offset para siguiente página
          offset += pageSize;
          
          // Pequeño delay para no sobrecargar el servidor
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Convertir todos los JSON a objetos Partner y actualizar el repositorio
        final allPartners = allRecordsJson.map((json) => _partnerRepo.fromJson(json)).toList();
        _partnerRepo.latestRecords = allPartners;
        
        // Guardar en caché
        await _cache.put('Partner_records', allRecordsJson);
        
        print('👥 BOOTSTRAP_COORDINATOR: Bootstrap completado - Total: $totalFetched partners en $page página(s)');
        
        // Marcar como completado
        final completed = totalFetched > 0;
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
      } catch (e) {
        print('👥 BOOTSTRAP_COORDINATOR: Error en partners: $e');
        _currentState = _failModule(_currentState, m, e.toString());
      }
    }

  Future<void> _bootstrapProducts(int pageSize) async {
    final m = BootstrapModule.products;
    int page = 0;
    int totalFetched = 0;
    int offset = 0;
    final List<Map<String, dynamic>> allRecordsJson = [];
    
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        print('📦 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de productos con paginación (intento $attempt/2)...');
        
        // Reset para cada intento
        page = 0;
        totalFetched = 0;
        offset = 0;
        allRecordsJson.clear();
        
        // Loop de paginación
        while (true) {
          print('📦 BOOTSTRAP_COORDINATOR: Página ${page + 1} - offset: $offset, limit: $pageSize');
          
          // Hacer llamada directa a search_read con offset y limit
          final response = await _productRepo.env.orpc.callKw({
            'model': 'product.product',
            'method': 'search_read',
            'args': [],
            'kwargs': {
              'context': {'bin_size': true},
              'domain': [
                ['active', '=', true],
                ['sale_ok', '=', true],
              ],
              'fields': _productRepo.oFields,
              'limit': pageSize,
              'offset': offset,
            },
          });
          
          final pageRecords = response as List<dynamic>;
          final pageCount = pageRecords.length;
          print('📦 BOOTSTRAP_COORDINATOR: Página ${page + 1} - ${pageCount} registros obtenidos');
          
          // Agregar a la lista acumulada
          allRecordsJson.addAll(pageRecords.cast<Map<String, dynamic>>());
          totalFetched += pageCount;
          page++;
          
          // Actualizar progreso
          _currentState = _updateModule(_currentState, m, page, totalFetched, completed: false);
          if (onProgress != null) onProgress!(_currentState);
          
          // Si obtuvimos menos registros que pageSize, ya no hay más páginas
          if (pageCount < pageSize) {
            print('📦 BOOTSTRAP_COORDINATOR: Última página alcanzada (${pageCount} < $pageSize)');
            break;
          }
          
          // Incrementar offset para siguiente página
          offset += pageSize;
          
          // Pequeño delay para no sobrecargar el servidor
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Convertir todos los JSON a objetos Product y actualizar el repositorio
        final allProducts = allRecordsJson.map((json) => _productRepo.fromJson(json)).toList();
        _productRepo.latestRecords = allProducts;
        
        // Guardar en caché
        await _cache.put('Product_records', allRecordsJson);
        
        print('📦 BOOTSTRAP_COORDINATOR: Bootstrap completado - Total: $totalFetched productos en $page página(s)');
        
        // Marcar como completado
        final completed = totalFetched > 0;
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
        break; // Éxito, salir del loop de reintentos
        
      } catch (e) {
        print('📦 BOOTSTRAP_COORDINATOR: Error en productos (intento $attempt/2): $e');
        
        // Si es SessionExpired y es el primer intento, esperar y reintentar
        if (e.toString().contains('OdooSessionExpiredException') && attempt == 1) {
          print('📦 BOOTSTRAP_COORDINATOR: SessionExpired detectado, esperando 2s y reintentando...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        // Si no es SessionExpired o es el segundo intento, fallar
        _currentState = _failModule(_currentState, m, e.toString());
        break;
      }
    }
  }

  Future<void> _bootstrapEmployees(int pageSize) async {
    final m = BootstrapModule.employees;
    int page = 0;
    int totalFetched = 0;
    int offset = 0;
    final List<Map<String, dynamic>> allRecordsJson = [];
    
    try {
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de employees con paginación...');
      
      // Loop de paginación
      while (true) {
        print('👨‍💼 BOOTSTRAP_COORDINATOR: Página ${page + 1} - offset: $offset, limit: $pageSize');
        
        // Hacer llamada directa a search_read con offset y limit
        final response = await _employeeRepo.env.orpc.callKw({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'context': {'bin_size': true},
            'domain': [
              ['active', '=', true],
            ],
            'fields': _employeeRepo.oFields,
            'limit': pageSize,
            'offset': offset,
            'order': 'name'
          },
        });
        
        final pageRecords = response as List<dynamic>;
        final pageCount = pageRecords.length;
        print('👨‍💼 BOOTSTRAP_COORDINATOR: Página ${page + 1} - ${pageCount} registros obtenidos');
        
        // Agregar a la lista acumulada
        allRecordsJson.addAll(pageRecords.cast<Map<String, dynamic>>());
        totalFetched += pageCount;
        page++;
        
        // Actualizar progreso
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: false);
        if (onProgress != null) onProgress!(_currentState);
        
        // Si obtuvimos menos registros que pageSize, ya no hay más páginas
        if (pageCount < pageSize) {
          print('👨‍💼 BOOTSTRAP_COORDINATOR: Última página alcanzada (${pageCount} < $pageSize)');
          break;
        }
        
        // Incrementar offset para siguiente página
        offset += pageSize;
        
        // Pequeño delay para no sobrecargar el servidor
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Convertir todos los JSON a objetos Employee y actualizar el repositorio
      final allEmployees = allRecordsJson.map((json) => _employeeRepo.fromJson(json)).toList();
      _employeeRepo.latestRecords = allEmployees;
      
      // Guardar en caché
      await _cache.put('Employee_records', allRecordsJson);
      
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Bootstrap completado - Total: $totalFetched employees en $page página(s)');
      
      // Marcar como completado
      final completed = totalFetched > 0;
      _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
    } catch (e) {
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Error en employees: $e');
      _currentState = _failModule(_currentState, m, e.toString());
    }
  }

  Future<void> _bootstrapSaleOrders(int pageSize) async {
    final m = BootstrapModule.saleOrders;
    int page = 0;
    int totalFetched = 0;
    int offset = 0;
    final List<Map<String, dynamic>> allRecordsJson = [];
    
    try {
      print('🛒 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de sale orders con paginación...');
      
      // Loop de paginación
      while (true) {
        print('🛒 BOOTSTRAP_COORDINATOR: Página ${page + 1} - offset: $offset, limit: $pageSize');
        
        // Hacer llamada directa a search_read con offset y limit
        final response = await _saleOrderRepo.env.orpc.callKw({
          'model': 'sale.order',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'context': {'bin_size': true},
            'domain': [
              ['state', '!=', 'cancel'], // Excluir órdenes canceladas
            ],
            'fields': _saleOrderRepo.oFields,
            'limit': pageSize,
            'offset': offset,
            'order': 'date_order desc'
          },
        });
        
        final pageRecords = response as List<dynamic>;
        final pageCount = pageRecords.length;
        print('🛒 BOOTSTRAP_COORDINATOR: Página ${page + 1} - ${pageCount} registros obtenidos');
        
        // Agregar a la lista acumulada
        allRecordsJson.addAll(pageRecords.cast<Map<String, dynamic>>());
        totalFetched += pageCount;
        page++;
        
        // Actualizar progreso
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: false);
        if (onProgress != null) onProgress!(_currentState);
        
        // Si obtuvimos menos registros que pageSize, ya no hay más páginas
        if (pageCount < pageSize) {
          print('🛒 BOOTSTRAP_COORDINATOR: Última página alcanzada (${pageCount} < $pageSize)');
          break;
        }
        
        // Incrementar offset para siguiente página
        offset += pageSize;
        
        // Pequeño delay para no sobrecargar el servidor
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Convertir todos los JSON a objetos SaleOrder y actualizar el repositorio
      final allSaleOrders = allRecordsJson.map((json) => _saleOrderRepo.fromJson(json)).toList();
      _saleOrderRepo.latestRecords = allSaleOrders;
      
      // Guardar en caché
      await _cache.put('sale_orders', allRecordsJson);
      
      print('🛒 BOOTSTRAP_COORDINATOR: Bootstrap completado - Total: $totalFetched sale orders en $page página(s)');
      
      // Marcar como completado
      final completed = totalFetched > 0;
      _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
    } catch (e) {
      print('🛒 BOOTSTRAP_COORDINATOR: Error en sale orders: $e');
      _currentState = _failModule(_currentState, m, e.toString());
    }
  }

  BootstrapState _updateModule(
    BootstrapState state,
    BootstrapModule module,
    int completedPages,
    int fetched, {
    bool completed = false,
  }) {
    final current = state.modules[module]!;
    final updated = current.copyWith(
      completedPages: completedPages,
      recordsFetched: fetched,
      completed: completed,
      totalPages: completed ? completedPages : current.totalPages,
    );
    final newMap = Map<BootstrapModule, ModuleBootstrapStatus>.from(state.modules)
      ..[module] = updated;
    return state.copyWith(modules: newMap);
  }

  BootstrapState _failModule(BootstrapState state, BootstrapModule module, String message) {
    final current = state.modules[module]!;
    final updated = current.copyWith(errorMessage: message, completed: false);
    final newMap = Map<BootstrapModule, ModuleBootstrapStatus>.from(state.modules)
      ..[module] = updated;
    return state.copyWith(modules: newMap);
  }

  /// Bootstrap de direcciones de despacho con paginación
  Future<void> _bootstrapShippingAddresses(int pageSize) async {
    try {
      print('📍 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de shipping addresses con paginación...');
      
      int page = 1;
      int offset = 0;
      int totalFetched = 0;
      final List<Map<String, dynamic>> allRecordsJson = []; // Acumular todos los registros
      
      while (true) {
        print('📍 BOOTSTRAP_COORDINATOR: Página $page - offset: $offset, limit: $pageSize');
        
        final response = await _shippingAddressRepo.env.orpc.callKw({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'context': {'bin_size': true},
            'domain': [
              ['active', '=', true],
              ['type', '=', 'delivery']
            ],
            'fields': ['id', 'name', 'email', 'phone', 'is_company', 'customer_rank', 'supplier_rank', 'active', 'type', 'parent_id', 'commercial_partner_id', 'street', 'street2', 'city', 'city_id', 'state_id', 'country_id', 'zip'],
            'limit': pageSize,
            'offset': offset,
            'order': 'name'
          }
        });
        
        final records = response as List<dynamic>;
        final addresses = records.map((record) => _shippingAddressRepo.fromJson(record)).toList();
        
        print('📍 BOOTSTRAP_COORDINATOR: Página $page - ${addresses.length} registros obtenidos');
        
        if (addresses.isNotEmpty) {
          // Acumular registros JSON para guardar todos al final
          allRecordsJson.addAll(records.cast<Map<String, dynamic>>());
          
          totalFetched += addresses.length;
          
          // Actualizar estado
          _currentState = _updateModule(_currentState, BootstrapModule.shippingAddresses, 
            page, addresses.length, completed: false);
        }
        
        // Si recibimos menos registros que el límite, es la última página
        if (records.length < pageSize) {
          print('📍 BOOTSTRAP_COORDINATOR: Última página alcanzada (${records.length} < $pageSize)');
          break;
        }
        
        page++;
        offset += pageSize;
      }
      
      // Guardar TODOS los registros acumulados en caché al final
      if (allRecordsJson.isNotEmpty) {
        await _shippingAddressRepo.cache.put('ShippingAddress_records', allRecordsJson);
        print('📍 BOOTSTRAP_COORDINATOR: ${allRecordsJson.length} direcciones guardadas en caché');
      }
      
      print('📍 BOOTSTRAP_COORDINATOR: Bootstrap completado - Total: $totalFetched shipping addresses en ${page - 1} página(s)');
      
      // Marcar como completado solo si obtuvimos registros
      if (totalFetched > 0) {
        _currentState = _updateModule(_currentState, BootstrapModule.shippingAddresses, 
          page - 1, totalFetched, completed: true);
      } else {
        print('⚠️ BOOTSTRAP_COORDINATOR: No se obtuvieron shipping addresses');
        _currentState = _failModule(_currentState, BootstrapModule.shippingAddresses, 
          'No se obtuvieron shipping addresses');
      }
      
    } catch (e) {
      print('❌ BOOTSTRAP_COORDINATOR: Error en bootstrap de shipping addresses: $e');
      _currentState = _failModule(_currentState, BootstrapModule.shippingAddresses, e.toString());
    }
  }
}


