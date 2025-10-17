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
import 'bootstrap_state.dart';

/// Coordinador de Bootstrap de caché para datasets críticos
class BootstrapCoordinator {
  final NetworkConnectivity _netConn;
  final CustomOdooKv _cache;
  final PartnerRepository _partnerRepo;
  final ProductRepository _productRepo;
  final EmployeeRepository _employeeRepo;
  final SaleOrderRepository _saleOrderRepo;

  BootstrapCoordinator()
      : _netConn = getIt<NetworkConnectivity>(),
        _cache = getIt<CustomOdooKv>(),
        _partnerRepo = getIt<PartnerRepository>(),
        _productRepo = getIt<ProductRepository>(),
        _employeeRepo = getIt<EmployeeRepository>(),
        _saleOrderRepo = getIt<SaleOrderRepository>();

  /// Callback de progreso
  void Function(BootstrapState)? onProgress;

  /// Estado actual del bootstrap (compartido entre métodos paralelos)
  late BootstrapState _currentState;

  /// Módulos mínimos requeridos para considerar la app "offline ready"
  final Set<BootstrapModule> _minimumModules = {
    BootstrapModule.partners,
    BootstrapModule.products,
    BootstrapModule.employees,
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
    report();
    return _currentState;
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
      try {
        print('👥 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de partners...');
        await _partnerRepo.fetchRecords();
        print('👥 BOOTSTRAP_COORDINATOR: fetchRecords() completado');
        
        // Esperar un frame para que el repositorio actualice latestRecords
        await Future.delayed(const Duration(milliseconds: 100));
        totalFetched = _partnerRepo.latestRecords.length;
        print('👥 BOOTSTRAP_COORDINATOR: Total fetched: $totalFetched');
        
        page++;
        final completed = totalFetched > 0;
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
        print('👥 BOOTSTRAP_COORDINATOR: Partners - Fetched: $totalFetched, Completed: $completed');
      } catch (e) {
        print('👥 BOOTSTRAP_COORDINATOR: Error en partners: $e');
        _currentState = _failModule(_currentState, m, e.toString());
      }
    }

  Future<void> _bootstrapProducts(int pageSize) async {
    final m = BootstrapModule.products;
    int page = 0;
    int totalFetched = 0;
    
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        print('📦 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de productos (intento $attempt/2)...');
        // Configurar límite más alto para bootstrap
        _productRepo.setSearchParams(limit: pageSize, offset: 0);
        print('📦 BOOTSTRAP_COORDINATOR: Parámetros configurados - limit: $pageSize, offset: 0');
        
        print('📦 BOOTSTRAP_COORDINATOR: Llamando fetchRecords()...');
        await _productRepo.fetchRecords();
        print('📦 BOOTSTRAP_COORDINATOR: fetchRecords() completado');

        // Leer INMEDIATAMENTE sin delay
        totalFetched = _productRepo.latestRecords.length;
        print('📦 BOOTSTRAP_COORDINATOR: Total fetched INMEDIATO: $totalFetched');
        
        // Si es 0, esperar un poco y reintentar (fallback)
        if (totalFetched == 0) {
          print('⚠️ BOOTSTRAP_COORDINATOR: Total es 0, esperando 200ms y reintentando...');
          await Future.delayed(const Duration(milliseconds: 200));
          totalFetched = _productRepo.latestRecords.length;
          print('📦 BOOTSTRAP_COORDINATOR: Total fetched DESPUÉS DE DELAY: $totalFetched');
        }
        
        page++;
        // Solo marcar como completado si realmente obtuvimos productos
        final completed = totalFetched > 0;
        _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
        print('📦 BOOTSTRAP_COORDINATOR: Products - Fetched: $totalFetched, Completed: $completed');
        break; // Éxito, salir del loop
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
    try {
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de employees...');
      await _employeeRepo.fetchRecords();
      print('👨‍💼 BOOTSTRAP_COORDINATOR: fetchRecords() completado');
      
      // Esperar un frame para que el repositorio actualice latestRecords
      await Future.delayed(const Duration(milliseconds: 100));
      totalFetched = _employeeRepo.latestRecords.length;
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Total fetched: $totalFetched');
      
      page++;
      final completed = totalFetched > 0;
      _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Employees - Fetched: $totalFetched, Completed: $completed');
    } catch (e) {
      print('👨‍💼 BOOTSTRAP_COORDINATOR: Error en employees: $e');
      _currentState = _failModule(_currentState, m, e.toString());
    }
  }

  Future<void> _bootstrapSaleOrders(int pageSize) async {
    final m = BootstrapModule.saleOrders;
    int page = 0;
    int totalFetched = 0;
    try {
      print('🛒 BOOTSTRAP_COORDINATOR: Iniciando bootstrap de sale orders...');
      await _saleOrderRepo.fetchRecords();
      print('🛒 BOOTSTRAP_COORDINATOR: fetchRecords() completado');
      
      // Esperar un frame para que el repositorio actualice latestRecords
      await Future.delayed(const Duration(milliseconds: 100));
      totalFetched = _saleOrderRepo.latestRecords.length;
      print('🛒 BOOTSTRAP_COORDINATOR: Total fetched: $totalFetched');
      
      page++;
      final completed = totalFetched > 0;
      _currentState = _updateModule(_currentState, m, page, totalFetched, completed: completed);
      print('🛒 BOOTSTRAP_COORDINATOR: Sale Orders - Fetched: $totalFetched, Completed: $completed');
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
}


