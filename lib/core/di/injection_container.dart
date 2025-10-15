import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
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
import '../../data/repositories/city_repository.dart';
import '../../data/repositories/operation_queue_repository.dart';
import '../../data/repositories/local_id_repository.dart';
import '../../data/repositories/sync_coordinator_repository.dart';
import '../../data/repositories/odoo_call_queue_repository.dart';

/// Contenedor de inyección de dependencias
final GetIt getIt = GetIt.instance;

/// Inicializa todas las dependencias de la aplicación
Future<void> init() async {
  // Core dependencies
  getIt.registerLazySingleton<NetworkConnectivity>(
    () => NetworkConnectivity(),
  );

  // Odoo dependencies - usando implementación personalizada
  getIt.registerLazySingleton<CustomOdooKv>(
    () => CustomOdooKv(),
  );

  // Inicializar OperationQueueRepository
  final operationQueueRepo = OperationQueueRepository();
  await operationQueueRepo.init();
  getIt.registerSingleton<OperationQueueRepository>(operationQueueRepo);

  // Odoo Client - usando factory con conditional imports
  getIt.registerLazySingleton<OdooClient>(
    () {
      print('🔧 Creando OdooClient usando factory');
      return OdooClientFactory.create(AppConstants.odooServerURL);
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
}) async {
  try {
    var client = getIt<OdooClient>();
    final cache = getIt<CustomOdooKv>();
    
    print('🔐 Intentando login con credenciales dinámicas...');
    print('📡 URL solicitada: ${serverUrl ?? AppConstants.odooServerURL}');
    print('🗄️ DB: ${database ?? AppConstants.odooDbName}');
    print('👤 Usuario: $username');
    print('🔍 Cliente base URL ANTES: ${client.baseURL}');
    
    // SI la URL del servidor cambió, recrear el cliente
    final targetUrl = serverUrl ?? AppConstants.odooServerURL;
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
    }
    
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
      print('   - Session recibida: ${session != null ? "SÍ" : "NO"}');
      if (session != null) {
        print('   - Session.id: "${session.id}"');
        print('   - Session.userId: ${session.userId}');
        print('   - Session.userName: "${session.userName}"');
        print('   - Session.userLogin: "${session.userLogin}"');
        print('   - Session.isSystem: ${session.isSystem}');
      }
      print('🔍 Client después de authenticate:');
      print('   SessionId: ${client.sessionId}');
      print('   Cookies: ${client.sessionId != null ? "Sesión activa" : "Sin sesión"}');
      
      // WORKAROUND: Extraer session_id manualmente de cookies si está vacío
      if (session != null && session.id.isEmpty) {
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
          return await _handleAuthenticateResponse(fixedSession, username, password, database, cache);
        } else {
          print('❌ No se pudo interceptar session_id');
        }
      }
      
      return await _handleAuthenticateResponse(session, username, password, database, cache);
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
    
    print('✅ Repositories configurados correctamente (Partner + Employee + SaleOrder + Product + Pricelist)');
    
    // Registrar servicios offline
    if (getIt.isRegistered<SyncCoordinatorRepository>()) {
      getIt.unregister<SyncCoordinatorRepository>();
    }
    getIt.registerLazySingleton<SyncCoordinatorRepository>(() => SyncCoordinatorRepository(
      networkConnectivity: getIt<NetworkConnectivity>(),
      queueRepository: getIt<OperationQueueRepository>(),
      odooClient: getIt<OdooClient>(),
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
    
    // Aquí se agregarán más repositories cuando se implementen
    // env.add(UserRepository(env));
    // env.add(SaleOrderRepository(env));
  } catch (e) {
    print('❌ Error configurando repositories: $e');
    rethrow;
  }
}

/// A simple [http.Client] wrapper that adds a session cookie to every request.
class _ClientWithCookie extends http.BaseClient {
  final http.Client _inner;
  final String _sessionId;

  _ClientWithCookie(this._inner, this._sessionId);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Cookie'] = 'session_id=$_sessionId';
    return _inner.send(request);
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
        final authenticatedHttpClient =
            _ClientWithCookie(http.Client(), session.id);
        final odooClient = OdooClient(
          AppConstants.odooServerURL,
          httpClient: authenticatedHttpClient,
        );
        getIt.registerSingleton<OdooClient>(odooClient);

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

/// Recrear OdooClient con sesión válida
Future<void> _recreateClientWithSession(OdooSession session) async {
  try {
    print('🔄 Recreando OdooClient con sesión válida...');
    print('🔍 Sesión a usar: ${session.id}');
    
    // Desregistrar cliente anterior
    if (getIt.isRegistered<OdooClient>()) {
      getIt.unregister<OdooClient>();
      print('🗑️ OdooClient anterior desregistrado');
    }
    
    // IMPORTANTE: En lugar de intentar asignar sessionId manualmente,
    // el problema puede estar en que el cliente no está usando las cookies correctamente
    // Vamos a crear un cliente nuevo y verificar que mantenga la sesión
    getIt.registerLazySingleton<OdooClient>(
      () {
        final client = OdooClientFactory.create(AppConstants.odooServerURL);
        print('✅ Cliente recreado - Verificando sesión...');
        print('🔍 Cliente sessionId después de recrear: ${client.sessionId?.id}');
        return client;
      },
    );
    
    // Verificar que el cliente tenga la sesión correcta
    final newClient = getIt<OdooClient>();
    print('🔍 Verificación final:');
    print('   - Nuevo cliente sessionId: ${newClient.sessionId?.id}');
    print('   - Sesión esperada: ${session.id}');
    
    print('✅ OdooClient recreado exitosamente');
  } catch (e) {
    print('❌ Error recreando OdooClient: $e');
    rethrow;
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
    
    if (session != null) {
      print('✅ Re-auth: Sesión restaurada exitosamente');
      print('   - Session ID: ${session.id}');
      print('   - User: ${session.userName}');
      
      // Guardar sesión actualizada en cache
      cache.put(AppConstants.cacheSessionKey, json.encode(session.toJson()));
      print('💾 Re-auth: Sesión guardada en cache');
    } else {
      print('❌ Re-auth: authenticate() retornó null');
    }
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
  OdooSession? session,
  String username,
  String password,
  String? database,
  CustomOdooKv cache,
) async {
  final client = getIt<OdooClient>();
  
  print('🔍 DEBUG - Session después de authenticate:');
  print('   Session: $session');
  print('   Session ID: ${session?.id}');
  print('   Session ID length: ${session?.id.length}');
  print('   User ID: ${session?.userId}');
  print('   Username: ${session?.userName}');
  
  if (session != null) {
    print('✅ Login exitoso! User ID: ${session.userId}');
    print('👤 Username: ${session.userName}');
    
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
    
    // Configurar repositories (crearán el Environment lazy cuando se necesite)
    await _setupRepositories();
    
    return true;
  } else {
    print('❌ Login fallido: sesión nula');
    return false;
  }
}

/// Registra dependencias que requieren una sesión de Odoo activa.
void initAuthScope(OdooSession session) {
  // Primero, verificamos si ya hay una sesión registrada y la eliminamos.
  if (getIt.isRegistered<OdooSession>()) {
    getIt.unregister<OdooSession>();
  }
  // Registramos la nueva instancia de la sesión.
  getIt.registerSingleton<OdooSession>(session);

  // ⚠️ NO desregistrar OdooEnvironment porque llama a dispose() que hace logout!
  // Solo registrar si no existe
  if (!getIt.isRegistered<OdooEnvironment>()) {
    print('📦 initAuthScope: Creando nuevo OdooEnvironment');
    getIt.registerSingleton<OdooEnvironment>(OdooEnvironment(
      getIt<OdooClient>(),
      session.dbName,
      getIt<CustomOdooKv>(),
      getIt<NetworkConnectivity>(),
    ));
  } else {
    print('✅ initAuthScope: OdooEnvironment ya existe, manteniendo instancia actual');
  }

  // Repositories
  if (getIt.isRegistered<PartnerRepository>()) {
    getIt.unregister<PartnerRepository>();
  }
  getIt.registerLazySingleton<PartnerRepository>(
    () => PartnerRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );

  if (getIt.isRegistered<EmployeeRepository>()) {
    getIt.unregister<EmployeeRepository>();
  }
  getIt.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );

  if (getIt.isRegistered<SaleOrderRepository>()) {
    getIt.unregister<SaleOrderRepository>();
  }
  getIt.registerLazySingleton<SaleOrderRepository>(
    () => SaleOrderRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );

  if (getIt.isRegistered<ProductRepository>()) {
    getIt.unregister<ProductRepository>();
  }
  getIt.registerLazySingleton<ProductRepository>(
    () => ProductRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );

  if (getIt.isRegistered<PricelistRepository>()) {
    getIt.unregister<PricelistRepository>();
  }
  getIt.registerLazySingleton<PricelistRepository>(
    () => PricelistRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );
  
  if (getIt.isRegistered<CityRepository>()) {
    getIt.unregister<CityRepository>();
  }
  getIt.registerLazySingleton<CityRepository>(
    () => CityRepository(
        getIt<OdooEnvironment>(), getIt<NetworkConnectivity>(), getIt<CustomOdooKv>()),
  );
  
  print('✅ Repositories configurados correctamente (Partner + Employee + SaleOrder + Product + Pricelist + City)');
}





