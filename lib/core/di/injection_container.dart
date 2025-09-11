import 'package:get_it/get_it.dart';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../constants/app_constants.dart';
import '../network/network_connectivity.dart';
import '../cache/custom_odoo_kv.dart';
import '../../data/repositories/partner_repository.dart';

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

  // Odoo Client - sin sesión inicial (se recreará después del login)
  getIt.registerLazySingleton<OdooClient>(
    () => OdooClient(AppConstants.odooServerURL),
  );

  // Odoo Environment
  getIt.registerLazySingleton<OdooEnvironment>(
    () {
      final client = getIt<OdooClient>();
      final netConn = getIt<NetworkConnectivity>();
      final cache = getIt<CustomOdooKv>();
      
      return OdooEnvironment(
        client,
        AppConstants.odooDbName,
        cache,
        netConn,
      );
    },
  );
}

/// Nueva función de login que acepta credenciales dinámicas
Future<bool> loginWithCredentials({
  required String username,
  required String password,
  String? serverUrl,
  String? database,
}) async {
  try {
    final client = getIt<OdooClient>();
    final cache = getIt<CustomOdooKv>();
    
    print('🔐 Intentando login con credenciales dinámicas...');
    print('📡 URL: ${serverUrl ?? AppConstants.odooServerURL}');
    print('🗄️ DB: ${database ?? AppConstants.odooDbName}');
    print('👤 Usuario: $username');
    print('🔍 useCorsProxy: ${AppConstants.useCorsProxy}');
    print('🔍 Cliente base URL: ${client.baseURL}');
    
    // Usar authenticate con parámetros dinámicos
    print('🚀 Llamando client.authenticate...');
    print('🔍 Headers antes de authenticate:');
    print('   Base URL: ${client.baseURL}');
    print('   Client type: ${client.runtimeType}');
    
    // Interceptar y debuggear la respuesta HTTP
    try {
      final session = await client.authenticate(
        database ?? AppConstants.odooDbName,
        username,
        password,
      );
      
      print('🔍 RAW authenticate response received');
      print('🔍 Client después de authenticate:');
      print('   SessionId: ${client.sessionId}');
      print('   Cookies: ${client.sessionId != null ? "Sesión activa" : "Sin sesión"}');
      
      return await _handleAuthenticateResponse(session, username, password, database, cache);
    } catch (e) {
      print('❌ Exception during authenticate: $e');
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
    
    // Limpiar cache de autenticación
    await cache.delete(AppConstants.cacheSessionKey);
    await cache.delete('username');
    await cache.delete('userId');
    await cache.delete('database');
    
    // Desregistrar dependencias que requieren autenticación
    if (getIt.isRegistered<PartnerRepository>()) {
      getIt.unregister<PartnerRepository>();
      print('🗑️ PartnerRepository desregistrado');
    }
    if (getIt.isRegistered<OdooEnvironment>()) {
      getIt.unregister<OdooEnvironment>();
      print('🗑️ OdooEnvironment desregistrado');
    }
    if (getIt.isRegistered<OdooClient>()) {
      getIt.unregister<OdooClient>();
      print('🗑️ OdooClient desregistrado');
    }
    
    // Recrear cliente sin sesión (limpio)
    getIt.registerLazySingleton<OdooClient>(
      () => OdooClient(AppConstants.odooServerURL),
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
    
    final env = getIt<OdooEnvironment>();
    
    // Desregistrar repository anterior si existe
    if (getIt.isRegistered<PartnerRepository>()) {
      getIt.unregister<PartnerRepository>();
    }
    
    // Registrar PartnerRepository en el entorno
    final partnerRepo = env.add(PartnerRepository(env));
    
    // Registrar en GetIt para acceso directo
    getIt.registerLazySingleton<PartnerRepository>(() => partnerRepo);
    
    print('✅ Repositories configurados correctamente');
    
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
    final sessionId = cache.get(AppConstants.cacheSessionKey);
    final username = cache.get('username');
    final userId = cache.get('userId');
    final database = cache.get('database');
    
    if (sessionId != null && username != null && userId != null) {
      print('📋 Datos de sesión encontrados:');
      print('   Usuario: $username');
      print('   User ID: $userId');
      print('   Database: ${database ?? AppConstants.odooDbName}');
      
      // PROBLEMA: No podemos recrear OdooSession fácilmente desde datos guardados
      // SOLUCIÓN TEMPORAL: Forzar nuevo login con credenciales guardadas
      print('⚠️ Sesión encontrada pero necesita reautenticación');
      print('💡 Recomendación: Implementar re-login automático o mejorar persistencia de sesión');
      
      // Por ahora, limpiar datos y forzar nuevo login
      await cache.delete(AppConstants.cacheSessionKey);
      await cache.delete('username');
      await cache.delete('userId');
      await cache.delete('database');
      
      return false; // Forzar nuevo login
    } else {
      print('❌ No se encontró sesión válida');
      return false;
    }
  } catch (e) {
    print('❌ Error verificando sesión: $e');
    return false;
  }
}

/// Recrear OdooEnvironment con cliente actualizado
Future<void> _recreateOdooEnvironment() async {
  try {
    print('🔄 Recreando OdooEnvironment...');
    
    // Desregistrar environment anterior
    if (getIt.isRegistered<OdooEnvironment>()) {
      getIt.unregister<OdooEnvironment>();
    }
    
    // Crear nuevo environment con cliente actualizado
    getIt.registerLazySingleton<OdooEnvironment>(
      () {
        final client = getIt<OdooClient>();
        final netConn = getIt<NetworkConnectivity>();
        final cache = getIt<CustomOdooKv>();
        
        return OdooEnvironment(
          client,
          AppConstants.odooDbName,
          cache,
          netConn,
        );
      },
    );
    
    print('✅ OdooEnvironment recreado correctamente');
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
    await cache.put(AppConstants.cacheSessionKey, session.id.toString());
    await cache.put('username', username);
    await cache.put('userId', session.userId.toString());
    await cache.put('database', database ?? AppConstants.odooDbName);
    
    print('✅ Session ID válido: ${session.id}');
    print('🔍 Client sessionId: ${client.sessionId}');
    print('🔍 Client sessionId ID: ${client.sessionId?.id}');
    
    // Recrear environment y repositories con el cliente existente
    await _recreateOdooEnvironment();
    await _setupRepositories();
    
    return true;
  } else {
    print('❌ Login fallido: sesión nula');
    return false;
  }
}


