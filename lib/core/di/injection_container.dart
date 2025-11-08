import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../constants/app_constants.dart';
import '../network/network_connectivity.dart';
import '../cache/custom_odoo_kv.dart';
import '../http/session_interceptor.dart';
import '../http/odoo_client_factory.dart';
import '../session/session_ready.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/sale_order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/pricelist_repository.dart';
import '../../data/repositories/tax_repository.dart';
import '../../data/repositories/city_repository.dart';
import '../../data/repositories/shipping_address_repository.dart';
import '../../core/services/tax_calculation_service.dart';
import '../../core/services/order_totals_calculation_service.dart';
import '../../data/repositories/operation_queue_repository.dart';
import '../../data/repositories/local_id_repository.dart';
import '../../data/repositories/sync_coordinator_repository.dart';
import '../../data/repositories/odoo_call_queue_repository.dart';
import '../bootstrap/bootstrap_coordinator.dart';
import '../sync/sync_marker_store.dart';
import '../sync/incremental_sync_coordinator.dart';
import '../tenant/tenant_aware_cache.dart';
import '../tenant/tenant_admin_service.dart';
import '../tenant/tenant_context.dart';
import '../http/odoo_client_mobile.dart'; // ← Importar CookieClient
import '../http/scoped_odoo_client.dart';
import '../audit/audit_event_service.dart';

/// Contenedor de inyección de dependencias
final GetIt getIt = GetIt.instance;

/// Inicializa todas las dependencias de la aplicación
Future<void> init() async {
  // Core dependencies
  getIt.registerLazySingleton<NetworkConnectivity>(
    () => NetworkConnectivity(),
  );

  // Odoo dependencies - usando implementación personalizada
  final customCache = CustomOdooKv();
  getIt.registerSingleton<CustomOdooKv>(customCache);
  
  // Registrar también como OdooKv (interfaz base) para compatibilidad
  getIt.registerSingleton<OdooKv>(customCache);
  
  // Tenant management - Single-Tenant v2.0
  getIt.registerLazySingleton<TenantAwareCache>(
    () => TenantAwareCache(getIt<CustomOdooKv>())
  );
  
  getIt.registerLazySingleton<TenantAdminService>(
    () => TenantAdminService(getIt<TenantAwareCache>())
  );

  getIt.registerLazySingleton<AuditEventService>(
    () => AuditEventService(getIt<TenantAwareCache>())
  );

  // Inicializar OperationQueueRepository
  final operationQueueRepo = OperationQueueRepository();
  await operationQueueRepo.init();
  getIt.registerSingleton<OperationQueueRepository>(operationQueueRepo);

  // Odoo Client - usando factory con conditional imports
  getIt.registerLazySingleton<OdooClient>(
    () {
      print('🔧 Creando OdooClient usando factory');
      return OdooClientFactory.create(_sanitizeBaseUrl(AppConstants.odooServerURL));
    },
  );

  // ⚠️ OdooEnvironment NO se crea aquí porque aún no hay sesión
  // Se creará después del login exitoso en _recreateOdooEnvironment()

  // Offline functionality dependencies
  getIt.registerLazySingleton<LocalIdRepository>(
    () => LocalIdRepository(),
  );

  // OperationQueueRepository ya está registrado arriba con inicialización

  // SyncCoordinatorRepository se registrará después de OdooClient
  // OdooCallQueueRepository se registrará después de todos los demás
}

/// Nueva función de login que acepta credenciales dinámicas
Future<bool> loginWithCredentials({
  required String username,
  required String password,
  String? serverUrl,
  String? database,
  String? licenseNumber,  // ← NUEVO v2.0: Para tenant management
}) async {
  try {
    var client = getIt<OdooClient>();
    final cache = getIt<CustomOdooKv>();
    
    print('🔐 Intentando login con credenciales dinámicas...');
    final requestedUrl = _sanitizeBaseUrl(serverUrl ?? AppConstants.odooServerURL);
    print('📡 URL solicitada: $requestedUrl');
    print('🗄️ DB: ${database ?? AppConstants.odooDbName}');
    print('👤 Usuario: $username');
    print('🔍 Cliente base URL ANTES: ${client.baseURL}');
    
      // SI la URL del servidor cambió, recrear el cliente
      final targetUrl = requestedUrl;
      if (client.baseURL != targetUrl) {
        print('🔄 URL cambió, recreando OdooClient...');
        print('   Anterior: ${client.baseURL}');
        print('   Nueva: $targetUrl');
        
        // Desregistrar el cliente anterior
        if (getIt.isRegistered<OdooClient>()) {
          await getIt.unregister<OdooClient>();
        }
        
        // Crear y registrar nuevo cliente con la URL correcta
        final newClient = OdooClientFactory.create(targetUrl);
        getIt.registerLazySingleton<OdooClient>(() => newClient);
        client = newClient;
        
        print('✅ Nuevo cliente creado con URL: ${client.baseURL}');
        print('✅ Cliente usa CookieClient: ${client.httpClient.runtimeType}');
      }

      _applyCompanyScopeToClient(client, cache);
    
    print('🔍 Cliente base URL DESPUÉS: ${client.baseURL}');
    print('🔍 Cliente HTTP type: ${client.httpClient.runtimeType}');
    print('🔍 Cliente isWebPlatform: ${client.isWebPlatform}');
    
    // ANDROID DEBUG: Información adicional
    print('🤖 ANDROID DEBUG - Información del entorno:');
    print('   - Servidor a usar: $targetUrl');
    print('   - Database: ${database ?? AppConstants.odooDbName}');
    print('   - Usuario: $username');
    print('   - Password length: ${password.length}');
    
    // Usar authenticate con parámetros dinámicos
    print('🚀 Llamando client.authenticate...');
    print('🔍 Headers antes de authenticate:');
    print('   Base URL: ${client.baseURL}');
    print('   Client type: ${client.runtimeType}');
    
    // Interceptar y debuggear la respuesta HTTP
    try {
      print('🚀 ANDROID DEBUG: Iniciando authenticate...');
      print('   - URL completa: ${client.baseURL}/web/session/authenticate');
      print('   - Database param: ${database ?? AppConstants.odooDbName}');
      print('   - Username param: $username');
      
      final session = await client.authenticate(
        database ?? AppConstants.odooDbName,
        username,
        password,
      );
      
      print('🔍 RAW authenticate response received');
      print('🤖 ANDROID DEBUG - Respuesta detallada:');
        print('   - Session.id: "${session.id}"');
        print('   - Session.userId: ${session.userId}');
        print('   - Session.userName: "${session.userName}"');
        print('   - Session.userLogin: "${session.userLogin}"');
        print('   - Session.isSystem: ${session.isSystem}');
      print('🔍 Client después de authenticate:');
      print('   SessionId: ${client.sessionId}');
      print('   Cookies: ${client.sessionId != null ? "Sesión activa" : "Sin sesión"}');
      
      // WORKAROUND: Extraer session_id manualmente de cookies si está vacío
      if (session.id.isEmpty) {
        print('🔧 WORKAROUND: session.id vacío, extrayendo de SessionInterceptor...');
        
        // WORKAROUND: Extraer session_id de logs del proxy
        SessionInterceptor.extractSessionFromProxyLogs();
        final interceptedSessionId = SessionInterceptor.sessionId;
        
        if (interceptedSessionId != null && interceptedSessionId.isNotEmpty) {
          print('🍪 Session ID interceptado: $interceptedSessionId');
          
          // Crear nueva sesión con el session_id correcto
          final fixedSession = OdooSession(
            id: interceptedSessionId,
            userId: session.userId,
            userName: session.userName,
            userLogin: session.userLogin,
            userLang: session.userLang,
            userTz: session.userTz,
            serverVersion: session.serverVersion,
            isSystem: session.isSystem,
            partnerId: 0, // Valor por defecto
            companyId: 0, // Valor por defecto
            allowedCompanies: [], // Lista vacía por defecto
            dbName: database ?? AppConstants.odooDbName, // Usar database del parámetro
          );
          
          print('✅ Session corregida creada con ID: ${fixedSession.id}');
          return await _handleAuthenticateResponse(fixedSession, username, password, database, cache, licenseNumber);
        } else {
          print('❌ No se pudo interceptar session_id');
        }
      }
      
      return await _handleAuthenticateResponse(session, username, password, database, cache, licenseNumber);
    } catch (e) {
      print('❌ Exception during authenticate: $e');
      print('🤖 ANDROID DEBUG - Error detallado:');
      print('   - Error tipo: ${e.runtimeType}');
      print('   - Error mensaje: $e');
      
      // Análisis específico de errores comunes en Android
      if (e.toString().contains('SocketException')) {
        print('🔍 POSIBLE CAUSA: Problema de conectividad de red');
        print('   - Verifica que el dispositivo tenga internet');
        print('   - Verifica que la URL sea accesible desde móvil');
      } else if (e.toString().contains('HandshakeException')) {
        print('🔍 POSIBLE CAUSA: Problema de certificados SSL');
        print('   - El servidor puede tener certificado inválido');
      } else if (e.toString().contains('TimeoutException')) {
        print('🔍 POSIBLE CAUSA: Timeout de conexión');
        print('   - El servidor no responde a tiempo');
      } else if (e.toString().contains('FormatException')) {
        print('🔍 POSIBLE CAUSA: Respuesta del servidor inválida (Error 503/500)');
        print('   - El servidor no está devolviendo JSON válido');
        print('   - El servidor está caído, en mantenimiento, o con problemas');
        print('   - Status HTTP probablemente 503 (Service Unavailable) o 500');
        // Re-lanzar con mensaje más descriptivo
        throw Exception('Servidor no disponible: El servidor Odoo no está respondiendo correctamente. Puede estar en mantenimiento o experimentando problemas técnicos. Contacta al administrador o intenta más tarde.');
      } else {
        print('🔍 ERROR DESCONOCIDO - Revisar logs completos');
      }
      
      rethrow;
    }
    
    // Esta lógica se movió a _handleAuthenticateResponse
  } catch (e, stackTrace) {
    print('❌ Error en login: $e');
    print('📍 Stack trace: $stackTrace');
    return false;
  }
}

/// Normaliza una URL para usar solo esquema + host (sin paths como /odoo)
String _sanitizeBaseUrl(String url) {
  try {
    var u = url.trim();
    if (u.isEmpty) return u;
    // Si viene con /odoo o cualquier path, eliminarlo
    // Asegurar esquema
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    final parsed = Uri.parse(u);
    final clean = Uri(scheme: parsed.scheme, host: parsed.host).toString();
    // Quitar trailing slash si lo hubiera
    return clean.endsWith('/') ? clean.substring(0, clean.length - 1) : clean;
  } catch (_) {
    return url; // fallback sin modificar en caso de error
  }
}

int? _parseCompanyId(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

void _applyCompanyScopeToClient(OdooClient client, CustomOdooKv cache) {
  if (client is ScopedOdooClient) {
    final rawCompanyId = cache.get('companyId');
    final companyId = _parseCompanyId(rawCompanyId);
    client.setCompanyScope(companyId);

    final rawUserId = cache.get('userId');
    final userId = _parseCompanyId(rawUserId);
    client.setUserScope(userId);
  }
}

/// Función legacy mantenida por compatibilidad (ahora usa credenciales por defecto)
@Deprecated('Use loginWithCredentials instead')
Future<bool> loginToOdoo() async {
  return loginWithCredentials(
    username: AppConstants.testUsername,
    password: AppConstants.testPassword,
  );
}


/// Realiza logout y limpia todas las dependencias de autenticación
Future<void> logout() async {
  try {
    print('🚪 Iniciando proceso de logout...');
    final cache = getIt<CustomOdooKv>();

    if (getIt.isRegistered<OdooClient>()) {
      final scopedClient = getIt<OdooClient>();
      if (scopedClient is ScopedOdooClient) {
        scopedClient.setCompanyScope(null);
      }
    }
    
    // ✅ NUEVO v2.0: Limpiar contexto de tenant (NO limpia cache de datos)
    TenantContext.clearTenant();
    print('🏢 TENANT: Contexto limpiado - Cache de datos preservado');
    
    // Verificar qué hay en caché antes de limpiar
    print('🔍 Verificando caché antes de limpiar:');
    final sessionBefore = cache.get(AppConstants.cacheSessionKey);
    final usernameBefore = cache.get('username');
    final userIdBefore = cache.get('userId');
    final databaseBefore = cache.get('database');
    print('   - Session: ${sessionBefore != null ? "EXISTE" : "NO EXISTE"}');
    print('   - Username: $usernameBefore');
    print('   - UserId: $userIdBefore');
    print('   - Database: $databaseBefore');
    
    // Limpiar cache de autenticación
    print('🧹 Limpiando caché...');
    await cache.delete(AppConstants.cacheSessionKey);
    await cache.delete('username');
    await cache.delete('userId');
    await cache.delete('database');
    
    // Verificar que se limpió correctamente
    print('🔍 Verificando caché después de limpiar:');
    final sessionAfter = cache.get(AppConstants.cacheSessionKey);
    final usernameAfter = cache.get('username');
    final userIdAfter = cache.get('userId');
    final databaseAfter = cache.get('database');
    print('   - Session: ${sessionAfter != null ? "EXISTE" : "NO EXISTE"}');
    print('   - Username: $usernameAfter');
    print('   - UserId: $userIdAfter');
    print('   - Database: $databaseAfter');
    
    // 🔍 DEBUG FASE 1: Limpiar cookies del CookieClient antes de desregistrar
    print('🧹 DEBUG FASE 1: Limpiando cookies del CookieClient...');
    try {
      final client = getIt<OdooClient>();
      if (client.httpClient is CookieClient) {
        final cookieClient = client.httpClient as CookieClient;
          cookieClient.clearCookies();
          print('🧹 DEBUG FASE 1: ✅ Cookies del CookieClient limpiadas');
          cookieClient.debugCookies();
      } else {
        print('🧹 DEBUG FASE 1: ⚠️ Cliente no es CookieClient: ${client.httpClient.runtimeType}');
      }
    } catch (e) {
      print('🧹 DEBUG FASE 1: ❌ Error limpiando cookies: $e');
    }

    // Desregistrar dependencias que requieren autenticación
    print('🗑️ Desregistrando dependencias...');
    if (getIt.isRegistered<PartnerRepository>()) {
      getIt.unregister<PartnerRepository>();
      print('🗑️ PartnerRepository desregistrado');
    }
    if (getIt.isRegistered<EmployeeRepository>()) {
      getIt.unregister<EmployeeRepository>();
      print('🗑️ EmployeeRepository desregistrado');
    }
    if (getIt.isRegistered<SaleOrderRepository>()) {
      getIt.unregister<SaleOrderRepository>();
      print('🗑️ SaleOrderRepository desregistrado');
    }
    if (getIt.isRegistered<OdooEnvironment>()) {
      getIt.unregister<OdooEnvironment>();
      print('🗑️ OdooEnvironment desregistrado');
    }
    if (getIt.isRegistered<OdooClient>()) {
      getIt.unregister<OdooClient>();
      print('🗑️ OdooClient desregistrado');
    }
    
    // Recrear cliente sin sesión (limpio) usando factory
    print('🔄 Recreando cliente limpio...');
    getIt.registerLazySingleton<OdooClient>(
      () => OdooClientFactory.create(AppConstants.odooServerURL),
    );
    
    print('✅ Logout completado exitosamente');
  } catch (e) {
    print('❌ Error en logout: $e');
    rethrow;
  }
}


/// Configura el entorno Odoo con todos los repositories (DEPRECATED)
@Deprecated('Authentication is now handled by AuthBloc')
Future<void> setupOdooEnvironment() async {
  // Esta función ahora se mantiene solo por compatibilidad
  // La autenticación se maneja a través del AuthBloc
  throw Exception('setupOdooEnvironment is deprecated. Use AuthBloc for authentication.');
}

/// Configura los repositories después de la autenticación exitosa
Future<void> _setupRepositories() async {
  try {
    print('🔧 Configurando repositories...');
    print('🔍 DEBUG: Obteniendo OdooEnvironment de GetIt...');
    
    final env = getIt<OdooEnvironment>();
    print('✅ DEBUG: OdooEnvironment obtenido correctamente');
    
    // Desregistrar repository anterior si existe
    print('🔍 DEBUG: Verificando PartnerRepository...');
    if (getIt.isRegistered<PartnerRepository>()) {
      print('🗑️ DEBUG: Desregistrando PartnerRepository anterior...');
      getIt.unregister<PartnerRepository>();
      print('✅ DEBUG: PartnerRepository desregistrado');
    }
    
    // Registrar PartnerRepository en GetIt para acceso directo
    getIt.registerLazySingleton<PartnerRepository>(() => PartnerRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    // Desregistrar EmployeeRepository anterior si existe
    if (getIt.isRegistered<EmployeeRepository>()) {
      getIt.unregister<EmployeeRepository>();
    }
    
    // Registrar EmployeeRepository en GetIt para acceso directo
    getIt.registerLazySingleton<EmployeeRepository>(() => EmployeeRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    // Desregistrar ShippingAddressRepository anterior si existe
    if (getIt.isRegistered<ShippingAddressRepository>()) {
      getIt.unregister<ShippingAddressRepository>();
    }
    
    // Registrar ShippingAddressRepository en GetIt para acceso directo
    getIt.registerLazySingleton<ShippingAddressRepository>(() => ShippingAddressRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    // Desregistrar SaleOrderRepository anterior si existe
    if (getIt.isRegistered<SaleOrderRepository>()) {
      getIt.unregister<SaleOrderRepository>();
    }
    
    // Registrar SaleOrderRepository
    getIt.registerLazySingleton<SaleOrderRepository>(() => SaleOrderRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    // Desregistrar ProductRepository anterior si existe
    if (getIt.isRegistered<ProductRepository>()) {
      getIt.unregister<ProductRepository>();
    }
    
    // Registrar ProductRepository
    getIt.registerLazySingleton<ProductRepository>(() => ProductRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    // Desregistrar PricelistRepository anterior si existe
    if (getIt.isRegistered<PricelistRepository>()) {
      getIt.unregister<PricelistRepository>();
    }
    
    // Registrar PricelistRepository
    getIt.registerLazySingleton<PricelistRepository>(() => PricelistRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
    ));
    
    // Desregistrar TaxRepository anterior si existe
    if (getIt.isRegistered<TaxRepository>()) {
      getIt.unregister<TaxRepository>();
    }
    
    // Registrar TaxRepository
    getIt.registerLazySingleton<TaxRepository>(() => TaxRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
    ));
    
    // Desregistrar CityRepository anterior si existe
    if (getIt.isRegistered<CityRepository>()) {
      getIt.unregister<CityRepository>();
    }
    
    // Registrar CityRepository
    getIt.registerLazySingleton<CityRepository>(() => CityRepository(
      env,
      getIt<NetworkConnectivity>(),
      getIt<CustomOdooKv>(),
    ));
    
    print('✅ Repositories configurados correctamente (Partner + Employee + SaleOrder + Product + Pricelist + Tax + City)');
    
    // Registrar servicios de cálculo
    if (getIt.isRegistered<TaxCalculationService>()) {
      getIt.unregister<TaxCalculationService>();
    }
    getIt.registerLazySingleton<TaxCalculationService>(
      () => TaxCalculationService(getIt<TaxRepository>()),
    );
    
    if (getIt.isRegistered<OrderTotalsCalculationService>()) {
      getIt.unregister<OrderTotalsCalculationService>();
    }
    getIt.registerLazySingleton<OrderTotalsCalculationService>(
      () => OrderTotalsCalculationService(getIt<TaxCalculationService>()),
    );
    
    print('✅ Servicios de cálculo configurados correctamente');
    
    // Registrar servicios offline
    if (getIt.isRegistered<SyncCoordinatorRepository>()) {
getIt.unregister<SyncCoordinatorRepository>();
    }
    getIt.registerLazySingleton<SyncCoordinatorRepository>(() => SyncCoordinatorRepository(
      networkConnectivity: getIt<NetworkConnectivity>(),
      queueRepository: getIt<OperationQueueRepository>(),
      env: getIt<OdooEnvironment>(),
      tenantCache: getIt<TenantAwareCache>(),
    ));
    
    if (getIt.isRegistered<OdooCallQueueRepository>()) {
      getIt.unregister<OdooCallQueueRepository>();
    }
    getIt.registerLazySingleton<OdooCallQueueRepository>(() => OdooCallQueueRepository(
      queueRepository: getIt<OperationQueueRepository>(),
      idRepository: getIt<LocalIdRepository>(),
      syncCoordinator: getIt<SyncCoordinatorRepository>(),
      networkConnectivity: getIt<NetworkConnectivity>(),
    ));
    
    print('✅ Servicios offline configurados correctamente');
    
    // Registrar BootstrapCoordinator
    if (getIt.isRegistered<BootstrapCoordinator>()) {
      getIt.unregister<BootstrapCoordinator>();
    }
    getIt.registerLazySingleton<BootstrapCoordinator>(() => BootstrapCoordinator());
    
    // Registrar SyncMarkerStore para sincronización incremental
    if (!getIt.isRegistered<SyncMarkerStore>()) {
      getIt.registerLazySingleton<SyncMarkerStore>(
        () => SyncMarkerStore(getIt<OdooKv>(), tenantCache: getIt<TenantAwareCache>()),
      );
      print('✅ SyncMarkerStore registrado');
    }
    
    // Registrar IncrementalSyncCoordinator
    if (getIt.isRegistered<IncrementalSyncCoordinator>()) {
      getIt.unregister<IncrementalSyncCoordinator>();
    }
    getIt.registerLazySingleton<IncrementalSyncCoordinator>(
      () => IncrementalSyncCoordinator(
        partnerRepo: getIt<PartnerRepository>(),
        productRepo: getIt<ProductRepository>(),
        employeeRepo: getIt<EmployeeRepository>(),
        saleOrderRepo: getIt<SaleOrderRepository>(),
        shippingAddressRepo: getIt<ShippingAddressRepository>(),
        markerStore: getIt<SyncMarkerStore>(),
        tenantCache: getIt<TenantAwareCache>(),
      ),
    );
    print('✅ IncrementalSyncCoordinator registrado');
    
    // Aquí se agregarán más repositories cuando se implementen
    // env.add(UserRepository(env));
    // env.add(SaleOrderRepository(env));
  } catch (e) {
    print('❌ Error configurando repositories: $e');
    rethrow;
  }
}

/// Verifica si existe una sesión válida guardada
Future<bool> checkExistingSession() async {
  try {
    print('🔍 Verificando sesión existente...');
    final cache = getIt<CustomOdooKv>();

    // Verificar si tenemos datos de sesión guardados
    final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;

    if (sessionJson != null && sessionJson.isNotEmpty) {
      print('📋 Datos de sesión JSON encontrados. Restaurando...');
      final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
      final session = OdooSession.fromJson(sessionData);

      if (session.id.isNotEmpty) {
        print('✅ Sesión válida recuperada para user: ${session.userName}');

        // Replace the existing OdooClient with a new one that has our session cookie.
        // This is the correct way to restore state without a public session setter.
        if (getIt.isRegistered<OdooClient>()) {
          getIt.unregister<OdooClient>();
        }
        
        // ✅ FIX: Leer serverUrl del cache en lugar de usar AppConstants
        final cachedServerUrl = cache.get('serverUrl') as String?;
        final serverUrl = cachedServerUrl ?? AppConstants.odooServerURL;
        print('🌐 SESIÓN: Usando serverUrl del cache: $serverUrl');
        
        final odooClient = OdooClientFactory.create(serverUrl);
        if (odooClient.httpClient is CookieClient) {
          final cookieClient = odooClient.httpClient as CookieClient;
          cookieClient.addCookie('session_id', session.id);
        }
        _applyCompanyScopeToClient(odooClient, cache);
        getIt.registerSingleton<OdooClient>(odooClient);
        
        print('✅ SESIÓN: OdooClient recreado con CookieClient');
        print('✅ SESIÓN: session_id agregado: ${session.id}');
        print('✅ SESIÓN: BaseURL del cliente: ${odooClient.baseURL}');

        // ✅ FIX: Restaurar TenantContext desde cache
        final cachedLicenseNumber = cache.get('licenseNumber') as String?;
        final cachedDatabase = cache.get('database') as String?;
        
        if (cachedLicenseNumber != null && cachedLicenseNumber.isNotEmpty && cachedDatabase != null) {
          print('🏢 TENANT: Restaurando tenant de sesión guardada');
          print('   License: $cachedLicenseNumber');
          print('   Database: $cachedDatabase');
          
          TenantContext.setTenant(cachedLicenseNumber, cachedDatabase);
          print('✅ TENANT: TenantContext restaurado correctamente');
        } else {
          print('⚠️ TENANT: No se encontró licenseNumber en cache');
          print('   cachedLicenseNumber: $cachedLicenseNumber');
          print('   cachedDatabase: $cachedDatabase');
        }

        // Recrear environment y repositories que dependen del cliente autenticado
        await _recreateOdooEnvironment();
        await _setupRepositories();

        print('🚀 Entorno restaurado con sesión existente.');
        return true;
      }
    }

    print('❌ No se encontró sesión válida');
    return false;
  } catch (e) {
    print('❌ Error verificando sesión: $e');
    return false;
  }
}

/// Re-autentica silenciosamente después de que OdooEnvironment destruya la sesión
Future<void> _reAuthenticateSilently() async {
  try {
    final client = getIt<OdooClient>();
    final cache = getIt<CustomOdooKv>();
    
    // Obtener credenciales guardadas
    final username = cache.get('licenseUser');
    final password = cache.get('licensePassword');
    final database = cache.get('database');
    
    if (username == null || password == null || database == null) {
      print('⚠️ Re-auth: No se encontraron credenciales en cache');
      print('   - username: ${username != null ? "SÍ" : "NO"}');
      print('   - password: ${password != null ? "SÍ" : "NO"}');
      print('   - database: ${database != null ? "SÍ" : "NO"}');
      return;
    }
    
    print('🔐 Re-auth: Credenciales encontradas');
    print('   - Database: $database');
    print('   - Username: $username');
    
    // Re-autenticar
    final session = await client.authenticate(database, username, password);
    
      print('✅ Re-auth: Sesión restaurada exitosamente');
      print('   - Session ID: ${session.id}');
      print('   - User: ${session.userName}');
      
      // Guardar sesión actualizada en cache
      cache.put(AppConstants.cacheSessionKey, json.encode(session.toJson()));
      print('💾 Re-auth: Sesión guardada en cache');
  } catch (e, stackTrace) {
    print('❌ Re-auth: Error durante re-autenticación: $e');
    print('   Stack trace: $stackTrace');
    // No relanzar el error - es mejor continuar sin sesión que crashear
  }
}

/// Recrear OdooEnvironment con cliente actualizado
Future<void> _recreateOdooEnvironment() async {
  try {
    print('🔄 Recreando OdooEnvironment...');
    
    // ⚠️ WORKAROUND: OdooEnvironment() constructor puede invalidar sesión anterior
    // Solución: Simplemente no crearlo hasta que sea absolutamente necesario
    // Como los repositories usan LazySingleton, el Environment se creará cuando se use
    if (!getIt.isRegistered<OdooEnvironment>()) {
      print('📦 OdooEnvironment no existe, ESPERANDO a que se use (lazy)...');
      
      // Registrar como LazySingleton - se creará cuando un repository lo necesite
      getIt.registerLazySingleton<OdooEnvironment>(
        () {
          print('🏗️ OdooEnvironment: Creación LAZY iniciada por primer uso');
          final client = getIt<OdooClient>();
          final netConn = getIt<NetworkConnectivity>();
          final cache = getIt<CustomOdooKv>();
          
          final env = OdooEnvironment(
            client,
            AppConstants.odooDbName,
            cache,
            netConn,
          );
          
          print('✅ OdooEnvironment: Instancia creada');
          return env;
        },
      );
      
      print('✅ OdooEnvironment: Factory registrado (creación diferida)');
    } else {
      print('✅ OdooEnvironment ya existe, reutilizando instancia actual');
    }
  } catch (e) {
    print('❌ Error recreando OdooEnvironment: $e');
    rethrow;
  }
}

/// Maneja la respuesta de autenticación y realiza el debug necesario
Future<bool> _handleAuthenticateResponse(
  OdooSession session,
  String username,
  String password,
  String? database,
  CustomOdooKv cache,
  String? licenseNumber,  // ← NUEVO v2.0: Para tenant management
) async {
  final client = getIt<OdooClient>();
  
  print('🔍 DEBUG - Session después de authenticate:');
  print('   Session: $session');
  print('   Session ID: ${session.id}');
  print('   Session ID length: ${session.id.length}');
  print('   User ID: ${session.userId}');
  print('   Username: ${session.userName}');
  
    print('✅ Login exitoso! User ID: ${session.userId}');
    print('👤 Username: ${session.userName}');
    
    // ✅ NUEVO v2.0: Detectar cambio de licencia y limpiar cache anterior
    if (licenseNumber != null && licenseNumber.isNotEmpty) {
      print('🏢 TENANT: Procesando tenant para licencia: $licenseNumber');
      
      final previousLicense = TenantContext.setTenant(
        licenseNumber,
        database ?? AppConstants.odooDbName,
      );
      
      if (previousLicense != null) {
        // ⚠️ Cambio de licencia detectado - Limpiar cache anterior
        print('🔄 LOGIN: Cambio de licencia detectado: $previousLicense → $licenseNumber');
        print('🧹 LOGIN: Limpiando cache de licencia anterior...');
        
        final tenantCache = getIt<TenantAwareCache>();
        await tenantCache.clearTenant(previousLicense);
        
        print('✅ LOGIN: Cache de $previousLicense eliminado completamente');
        print('📦 LOGIN: Ahora se hará bootstrap completo para $licenseNumber');
      } else {
        print('✅ LOGIN: Misma licencia ($licenseNumber) - Cache preservado');
      }
      
      // Guardar licenseNumber en cache para referencia
      await cache.put('licenseNumber', licenseNumber);
    } else {
      print('⚠️ LOGIN: No se proporcionó licenseNumber - Tenant management deshabilitado');
    }
    
    // VALIDACIÓN ESTRICTA: El servidor DEBE retornar session_id válido
    if (session.id.isEmpty) {
      print('🚨 ERROR: Session ID vacío - servidor no configurado correctamente');
      print('❌ FALLO: El servidor debe incluir session_id en la respuesta');
      print('🎯 ACCIÓN REQUERIDA: Configurar /web/session/authenticate en el servidor');
      print('📋 Ver requerimiento técnico para el backend');
      return false; // FALLO EXPLÍCITO - no continuar sin session válido
    }
    
    // Session ID válido - continuar normalmente
    final sessionJson = json.encode(session.toJson());
    await cache.put(AppConstants.cacheSessionKey, sessionJson);
    await cache.put('username', username);
    await cache.put('database', database ?? AppConstants.odooDbName);
    
    print('✅ Sesión completa guardada en caché.');
    
    print('✅ Session ID válido: ${session.id}');
    print('🔍 Client sessionId: ${client.sessionId}');
    print('🔍 Client sessionId ID: ${client.sessionId?.id}');
    
    // PROBLEMA IDENTIFICADO: El cliente no está usando la sesión correctamente
    // Necesitamos verificar si el cliente tiene la sesión activa
    print('🔍 VERIFICACIÓN DE SESIÓN EN CLIENTE:');
    print('   - Cliente tiene sesión: ${client.sessionId != null}');
    print('   - Sesión del cliente: ${client.sessionId}');
    print('   - ID de sesión del cliente: ${client.sessionId?.id}');
    print('   - Sesión recibida: ${session.id}');
    print('   - ¿Son iguales?: ${client.sessionId?.id == session.id}');
    
    // Si las sesiones no coinciden, hay un problema
    if (client.sessionId?.id != session.id) {
      print('⚠️ PROBLEMA: La sesión del cliente no coincide con la sesión recibida');
      print('   - Esto puede causar "Session Expired" en llamadas posteriores');
      print('   - SOLUCIÓN: El cliente móvil ahora maneja cookies automáticamente');
      print('   - Las cookies se enviarán en todas las requests posteriores');
    }
    
    // ⚠️ NO recrear OdooEnvironment inmediatamente - registrar factory lazy
    // Esto evita que se llame a session/destroy inmediatamente después del login
    print('⏭️ Registrando factory de Environment (creación diferida)...');
    
    // Registrar el factory si no existe
    if (!getIt.isRegistered<OdooEnvironment>()) {
      // Variable para almacenar la instancia después de re-autenticación
      OdooEnvironment? environmentInstance;
      
      getIt.registerLazySingleton<OdooEnvironment>(
        () {
          if (environmentInstance != null) {
            return environmentInstance!;
          }
          
          print('🏗️ OdooEnvironment: Creación LAZY iniciada por primer uso');
          final client = getIt<OdooClient>();
          final netConn = getIt<NetworkConnectivity>();
          final cache = getIt<CustomOdooKv>();
          
          // Crear environment (esto llamará a session/destroy)
          final env = OdooEnvironment(
            client,
            AppConstants.odooDbName,
            cache,
            netConn,
          );
          
          print('✅ OdooEnvironment: Instancia creada');
          
        // 🔄 Re-autenticación silenciosa después de session/destroy (fire-and-forget)
        print('🔄 Iniciando re-autenticación silenciosa en background...');
        SessionReadyCoordinator.startReauthentication();
        _reAuthenticateSilently().then((_) {
          print('✅ Re-autenticación completada');
        }).catchError((e) {
          print('⚠️ Re-autenticación falló (continuando de todas formas): $e');
        }).whenComplete(() {
          SessionReadyCoordinator.completeReauthentication();
        });
          
          environmentInstance = env;
          return env;
        },
      );
      print('✅ Factory de OdooEnvironment registrado (creación diferida)');
    }
    
  // ⚠️ NO llamar _setupRepositories aquí porque fuerza la creación de OdooEnvironment
  // Los repositorios se configurarán en initAuthScope() que se llama después del login
  // Esto evita que OdooEnvironment se cree antes de tener la sesión correcta inicializada
    
    return true;
}

/// Espera a que la re-autenticación silenciosa complete después de crear OdooEnvironment
/// Similar a BootstrapCoordinator._ensureSessionValid() pero con timeout más corto
/// CRÍTICO: También asegura que OdooClient.sessionId esté sincronizado con la cookie
Future<void> _ensureReauthComplete({Duration timeout = const Duration(seconds: 10)}) async {
  try {
    final client = getIt<OdooClient>();
    final cache = getIt<CustomOdooKv>();
    final start = DateTime.now();
    print('⏳ initAuthScope: Esperando re-autenticación silenciosa...');
    
    String? cookieSessionId;
    
    while (true) {
      final sid = client.sessionId; // OdooSession
      final hasValidSession = sid != null && sid.id.isNotEmpty;
      
      // Verificar también que las cookies estén disponibles en el CookieClient
      bool hasValidCookies = false;
      try {
        if (client.httpClient is CookieClient) {
          final cookieClient = client.httpClient as CookieClient;
          final cookies = cookieClient.getCookies();
          cookieSessionId = cookies['session_id'];
          hasValidCookies = cookies.containsKey('session_id') && 
            cookies['session_id']!.isNotEmpty;
        }
      } catch (e) {
        print('⚠️ initAuthScope: Error verificando cookies: $e');
      }
      
      // ✅ CRÍTICO: Si tenemos cookie pero no sessionId en cliente, recuperar desde cache
      if (hasValidCookies && cookieSessionId != null && !hasValidSession) {
        print('⚠️ initAuthScope: Cookie existe pero cliente no tiene sessionId');
        print('⚠️ initAuthScope: Recuperando sesión desde cache...');
        
        // Intentar recuperar sesión desde cache
        final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
        if (sessionJson != null) {
          try {
            final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
            final cachedSession = OdooSession.fromJson(sessionData);
            
            // Si la cookie coincide con la sesión en cache, podemos usar esa sesión
            if (cachedSession.id == cookieSessionId) {
              print('✅ initAuthScope: Sesión encontrada en cache - ID coincide con cookie');
              print('✅ initAuthScope: Cookie session_id: ${cookieSessionId.substring(0, 8)}...');
              
              // IMPORTANTE: El OdooClient debería tener sessionId automáticamente después de authenticate
              // Pero si no lo tiene, debemos esperar a que la re-auth complete
              // o recrear el cliente con la sesión correcta
              print('⏳ initAuthScope: Esperando que re-auth complete para actualizar sessionId...');
            }
          } catch (e) {
            print('⚠️ initAuthScope: Error parseando sesión desde cache: $e');
          }
        }
      }
      
      if (hasValidSession && hasValidCookies) {
        print('✅ initAuthScope: Re-autenticación completada');
        print('   - SessionId: ${sid.id.substring(0, 8)}...');
        print('   - Cookies: OK');
        // Delay adicional para asegurar que las cookies y sessionId estén completamente sincronizados
        await Future.delayed(const Duration(milliseconds: 500));
        print('✅ initAuthScope: Sesión lista para cacheos');
        return;
      }
      
      // ✅ Si tenemos cookie válida pero aún no sessionId en cliente, seguir esperando
      // La re-auth puede estar en progreso
      if (hasValidCookies && !hasValidSession) {
        print('⏳ initAuthScope: Cookie válida pero sessionId aún no disponible - esperando...');
        print('   - Cookie session_id: ${cookieSessionId?.substring(0, 8) ?? "NULL"}...');
      }
      
      if (DateTime.now().difference(start) >= timeout) {
        print('⏳ initAuthScope: Timeout esperando re-autenticación');
        print('   - SessionId válido: ${hasValidSession ? "SÍ" : "NO"}');
        print('   - Cookies válidas: ${hasValidCookies ? "SÍ" : "NO"}');
        
        // ⚠️ CRÍTICO: Si tenemos cookie pero no sessionId, intentar recuperar desde cache
        if (hasValidCookies && cookieSessionId != null && !hasValidSession) {
          print('⚠️ initAuthScope: Reintentando recuperar sesión desde cache después de timeout...');
          final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
          if (sessionJson != null) {
            try {
              final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
              final cachedSession = OdooSession.fromJson(sessionData);
              
              // Si la cookie coincide, podemos continuar aunque cliente no tenga sessionId
              // porque las cookies se enviarán automáticamente en las requests
              if (cachedSession.id == cookieSessionId) {
                print('✅ initAuthScope: Cookie válida coincide con sesión en cache - continuando');
                print('✅ initAuthScope: Las cookies se enviarán automáticamente en requests');
                return;
              }
            } catch (e) {
              print('⚠️ initAuthScope: Error final parseando sesión: $e');
            }
          }
        }
        
        break;
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
    }
  } catch (e) {
    print('⚠️ initAuthScope: Error verificando re-autenticación: $e');
    // Continuar de todas formas
  }
}

/// Registra dependencias que requieren una sesión de Odoo activa.
Future<void> initAuthScope(OdooSession session) async {
  print('═══════════════════════════════════════════════════════════════');
  print('⚠️⚠️⚠️ initAuthScope: INICIANDO INICIALIZACIÓN DE SCOPE DE AUTENTICACIÓN ⚠️⚠️⚠️');
  print('═══════════════════════════════════════════════════════════════');
  print('⚠️ initAuthScope:   - Session ID: ${session.id.substring(0, 8)}...');
  print('⚠️ initAuthScope:   - User: ${session.userName}');
  print('⚠️ initAuthScope:   - Database: ${session.dbName}');
  print('═══════════════════════════════════════════════════════════════');
  
  // Primero, verificamos si ya hay una sesión registrada y la eliminamos.
  if (getIt.isRegistered<OdooSession>()) {
    getIt.unregister<OdooSession>();
  }
  // Registramos la nueva instancia de la sesión.
  getIt.registerSingleton<OdooSession>(session);

  final cache = getIt<CustomOdooKv>();
  // ✅ NUEVO: Asegurar que el OdooClient tenga las cookies correctas antes de crear OdooEnvironment
  final client = getIt<OdooClient>();
  _applyCompanyScopeToClient(client, cache);
  print('🔍 initAuthScope: Verificando OdooClient antes de crear OdooEnvironment');
  print('🔍 initAuthScope:   - baseURL: ${client.baseURL}');
  print('🔍 initAuthScope:   - sessionId: ${client.sessionId?.id ?? "NULL"}');
  print('🔍 initAuthScope:   - httpClient type: ${client.httpClient.runtimeType}');
  
  // Si el httpClient es CookieClient, asegurar que tenga la cookie session_id
  if (client.httpClient is CookieClient) {
    final cookieClient = client.httpClient as CookieClient;
    final cookies = cookieClient.getCookies();
    print('🔍 initAuthScope: CookieClient tiene ${cookies.length} cookies');
    
    if (!cookies.containsKey('session_id') || cookies['session_id'] != session.id) {
      print('⚠️ initAuthScope: ⚠️⚠️⚠️ CookieClient NO tiene session_id correcto');
      print('⚠️ initAuthScope:   - Session ID esperado: ${session.id}');
      print('⚠️ initAuthScope:   - Session ID en cookies: ${cookies['session_id'] ?? "NO EXISTE"}');
      print('🔧 initAuthScope: Agregando session_id al CookieClient...');
      cookieClient.addCookie('session_id', session.id);
      print('✅ initAuthScope: session_id agregado al CookieClient');
    } else {
      print('✅ initAuthScope: CookieClient tiene session_id correcto');
    }
  } else {
    print('⚠️ initAuthScope: OdooClient NO usa CookieClient - tipo: ${client.httpClient.runtimeType}');
  }

  // ⚠️ PROBLEMA: Si OdooEnvironment ya existe, puede tener una sesión incorrecta
  // Necesitamos recrearlo con la sesión correcta
  if (getIt.isRegistered<OdooEnvironment>()) {
    print('⚠️ initAuthScope: OdooEnvironment ya existe - puede tener sesión incorrecta');
    print('⚠️ initAuthScope: Eliminando OdooEnvironment existente para recrearlo con sesión correcta');
    final oldEnv = getIt<OdooEnvironment>();
    print('⚠️ initAuthScope: dbName del Environment antiguo: ${oldEnv.dbName}');
    print('⚠️ initAuthScope: dbName esperado: ${session.dbName}');
    
    // Desregistrar el Environment antiguo (esto llamará a dispose() pero es necesario)
    getIt.unregister<OdooEnvironment>();
    print('✅ initAuthScope: OdooEnvironment antiguo eliminado');
  }
  
  // Crear nuevo OdooEnvironment con la sesión correcta
  print('📦 initAuthScope: Creando nuevo OdooEnvironment con sesión correcta');
    getIt.registerSingleton<OdooEnvironment>(OdooEnvironment(
    client,  // Usar el cliente ya verificado y actualizado con cookies correctas
      session.dbName,
      getIt<CustomOdooKv>(),
      getIt<NetworkConnectivity>(),
    ));
  print('✅ initAuthScope: OdooEnvironment creado con dbName: ${session.dbName}');
  
  // ⚠️ CRÍTICO: OdooEnvironment() constructor llama a session/destroy que invalida la sesión
  // Luego se re-autentica silenciosamente en background. Debemos ESPERAR a que complete
  // antes de configurar repositories y hacer cacheos, igual que BootstrapCoordinator
  print('⏳ initAuthScope: Esperando re-autenticación silenciosa después de session/destroy...');
  await _ensureReauthComplete();
  print('✅ initAuthScope: Re-autenticación completada, continuando con configuración...');
  
  // ✅ CRÍTICO: Asegurar que OdooClient tenga sessionId sincronizado después de re-auth
  // Si la re-auth completó pero el cliente no tiene sessionId, sincronizar desde cookie
  final clientAfterReauth = getIt<OdooClient>();
  _applyCompanyScopeToClient(clientAfterReauth, cache);
  
  if (clientAfterReauth.sessionId == null || clientAfterReauth.sessionId!.id.isEmpty) {
    print('⚠️ initAuthScope: OdooClient no tiene sessionId después de re-auth');
    
    // Verificar cookie y actualizar cache si es necesario
    if (clientAfterReauth.httpClient is CookieClient) {
      final cookieClient = clientAfterReauth.httpClient as CookieClient;
      final cookies = cookieClient.getCookies();
      final cookieSessionId = cookies['session_id'];
      
      if (cookieSessionId != null && cookieSessionId.isNotEmpty) {
        print('⚠️ initAuthScope: Cookie tiene session_id: ${cookieSessionId.substring(0, 8)}...');
        
        // Verificar si la cookie coincide con el cache
        final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
        if (sessionJson != null) {
          try {
            final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
            final cachedSession = OdooSession.fromJson(sessionData);
            
            if (cookieSessionId != cachedSession.id) {
              print('⚠️ initAuthScope: Cookie difiere de sesión en cache - re-auth creó nueva sesión');
              print('⚠️ initAuthScope: La re-auth silenciosa creará una nueva sesión, esperando...');
              // No actualizar aquí - la re-auth explícita más abajo lo hará
  } else {
              print('✅ initAuthScope: Cookie coincide con sesión en cache');
            }
          } catch (e) {
            print('⚠️ initAuthScope: Error procesando sesión: $e');
          }
        }
        
        // ⚠️ PROBLEMA: OdooClient.sessionId no se puede establecer manualmente
        // Necesitamos forzar una llamada authenticate() explícita para sincronizar sessionId
        print('⚠️ initAuthScope: OdooClient.sessionId aún no está disponible');
        print('⚠️ initAuthScope: Forzando re-autenticación explícita para sincronizar sessionId...');
        
        try {
          // Obtener credenciales desde cache
          final username = cache.get('licenseUser') as String?;
          final password = cache.get('licensePassword') as String?;
          final database = cache.get('database') as String?;
          
          if (username != null && password != null && database != null) {
            print('⚠️ initAuthScope: Re-autenticando explícitamente...');
            final newSession = await clientAfterReauth.authenticate(database, username, password);
            
            print('✅ initAuthScope: Re-autenticación explícita exitosa');
            print('   - Nuevo SessionId: ${newSession.id.substring(0, 8)}...');
            
            // Actualizar cache con nueva sesión
            await cache.put(AppConstants.cacheSessionKey, json.encode(newSession.toJson()));
            
            // Actualizar singleton en GetIt
            if (getIt.isRegistered<OdooSession>()) {
              getIt.unregister<OdooSession>();
            }
            getIt.registerSingleton<OdooSession>(newSession);
            
            // Verificar que el cliente ahora tiene sessionId
            if (clientAfterReauth.sessionId != null && clientAfterReauth.sessionId!.id.isNotEmpty) {
              print('✅ initAuthScope: OdooClient ahora tiene sessionId sincronizado');
              print('   - SessionId: ${clientAfterReauth.sessionId!.id.substring(0, 8)}...');
            } else {
              print('⚠️ initAuthScope: OdooClient aún no tiene sessionId después de authenticate()');
            }
          } else {
            print('⚠️ initAuthScope: No se encontraron credenciales para re-autenticar');
          }
        } catch (e) {
          print('⚠️ initAuthScope: Error en re-autenticación explícita: $e');
          print('⚠️ initAuthScope: Continuando de todas formas - las cookies pueden funcionar');
        }
      } else {
        print('⚠️ initAuthScope: No hay session_id en cookies');
      }
    }
  } else {
    print('✅ initAuthScope: OdooClient tiene sessionId después de re-auth');
    print('   - SessionId: ${clientAfterReauth.sessionId!.id.substring(0, 8)}...');
  }

  // ✅ Configurar repositories DESPUÉS de asegurar que OdooEnvironment está correcto
  // y que la re-autenticación completó
  // Esto reemplaza la llamada que estaba en _handleAuthenticateResponse
  _setupRepositories();
}





