import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/cache/custom_odoo_kv.dart';
import '../../../core/errors/session_expired_handler.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../core/license/license_service.dart';
import '../../../data/repositories/employee_repository.dart';

/// BLoC para manejar la autenticación de usuarios
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  StreamSubscription? _sessionExpiredSubscription;
  
  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<LicenseCheckRequested>(_onLicenseCheckRequested);
    on<EmployeePinLoginRequested>(_onEmployeePinLoginRequested);
    
    // Escuchar eventos de sesión expirada
    _sessionExpiredSubscription = SessionExpiredHandler.sessionExpiredStream.listen((_) {
      print('🔔 AUTH_BLOC: Sesión expirada detectada desde handler');
      add(LogoutRequested());
    });
  }
  
  @override
  Future<void> close() {
    _sessionExpiredSubscription?.cancel();
    return super.close();
  }
}

// Nuevos eventos para licencia y PIN
abstract class LicenseEvent {}

class LicenseCheckRequested extends AuthEvent {
  final String licenseNumber;
  LicenseCheckRequested(this.licenseNumber);
}

class EmployeePinLoginRequested extends AuthEvent {
  final String pin;
  EmployeePinLoginRequested(this.pin);
  }
  
  /// Verifica el estado de autenticación actual
  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    print('🔍 Verificando estado de autenticación...');
    emit(AuthLoading());
    
    try {
      final hasValidSession = await checkExistingSession();
      if (hasValidSession) {
        // Obtener datos del usuario desde cache
        final cache = getIt<CustomOdooKv>();
        final username = cache.get('username') ?? 'Usuario desconocido';
        final userId = cache.get('userId') ?? 'ID desconocido';
        final database = cache.get('database') ?? AppConstants.odooDbName;
        
        // Obtener la sesión desde cache y registrar en GetIt
        final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
        if (sessionJson != null) {
          final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
          final session = OdooSession.fromJson(sessionData);
          initAuthScope(session);
        }
        
        print('✅ Sesión válida encontrada para: $username');
        
        emit(AuthAuthenticated(
          username: username,
          userId: userId,
          database: database,
        ));
      } else {
        print('❌ No se encontró sesión válida');
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print('❌ Error verificando autenticación: $e');
      emit(AuthError('Error verificando autenticación: ${e.toString()}'));
    }
  }
  
  /// Maneja las solicitudes de login
  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    print('🔐 Procesando login para usuario: ${event.username}');
    emit(AuthLoading());
    
    try {
      final success = await loginWithCredentials(
        username: event.username,
        password: event.password,
        serverUrl: event.serverUrl,
        database: event.database,
      );
      
      if (success) {
        // Obtener datos del usuario desde cache (fueron guardados en loginWithCredentials)
        final cache = getIt<CustomOdooKv>();
        final userId = cache.get('userId') ?? 'unknown';
        final database = cache.get('database') ?? AppConstants.odooDbName;
        
        // Obtener la sesión desde cache y registrar en GetIt
        final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
        if (sessionJson != null) {
          final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
          final session = OdooSession.fromJson(sessionData);
          initAuthScope(session);
        }
        
        print('✅ Login exitoso para: ${event.username}');
        
        emit(AuthAuthenticated(
          username: event.username,
          userId: userId,
          database: database,
        ));
      } else {
        print('❌ Login fallido para: ${event.username}');
        emit(const AuthError('Credenciales inválidas'));
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      emit(AuthError('Error de conexión: ${e.toString()}'));
    }
  }
  
  /// Maneja las solicitudes de logout
  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    print('🚪 Procesando logout...');
    emit(AuthLoading());
    
    try {
      await logout();
      print('✅ Logout completado exitosamente');
      emit(AuthUnauthenticated());
    } catch (e) {
      print('❌ Error en logout: $e');
      emit(AuthError('Error en logout: ${e.toString()}'));
    }
  }

  // Maneja verificación de licencia
  Future<void> _onLicenseCheckRequested(LicenseCheckRequested event, Emitter<AuthState> emit) async {
    print('🔐 AUTH_BLOC: Procesando validación de licencia: ${event.licenseNumber}');
    emit(AuthLoading());
    
    try {
      final service = LicenseService();
      print('🔐 AUTH_BLOC: Llamando a LicenseService.fetchLicense()...');
      
      final info = await service.fetchLicense(event.licenseNumber);
      
      print('🔐 AUTH_BLOC: Respuesta recibida - success: ${info.success}, isActive: ${info.isActive}');
      print('🔐 AUTH_BLOC: serverUrl: ${info.serverUrl}');
      print('🔐 AUTH_BLOC: database: ${info.database}');
      print('🔐 AUTH_BLOC: username: ${info.username}');
      print('🔐 AUTH_BLOC: tipoven: ${info.tipoven}');
      
      if (!info.success || !info.isActive) {
        print('❌ AUTH_BLOC: Licencia no válida o inactiva');
        emit(AuthError('Licencia no activa o inválida'));
        return;
      }
      
      // Persistir configuración en KV
      print('💾 AUTH_BLOC: Guardando configuración en cache...');
      final kv = getIt<CustomOdooKv>();
      if (info.serverUrl != null) {
        kv.put('serverUrl', info.serverUrl);
        print('💾 AUTH_BLOC: serverUrl guardado: ${info.serverUrl}');
      }
      if (info.database != null) {
        kv.put('database', info.database);
        print('💾 AUTH_BLOC: database guardado: ${info.database}');
      }
      if (info.username != null) {
        kv.put('licenseUser', info.username);
        print('💾 AUTH_BLOC: licenseUser guardado: ${info.username}');
      }
      if (info.password != null) {
        kv.put('licensePassword', info.password);
        print('💾 AUTH_BLOC: licensePassword guardado');
      }
      kv.put('licenseNumber', info.licenseNumber);
      print('💾 AUTH_BLOC: licenseNumber guardado: ${info.licenseNumber}');
      if (info.tipoven != null) {
        kv.put('tipoven', info.tipoven);
        print('💾 AUTH_BLOC: tipoven guardado: ${info.tipoven}');
      }
      
      // Guardar tarifaId (importante para filtrado de productos)
      print('💰 AUTH_BLOC: Verificando tarifaId en LicenseInfo...');
      print('💰 AUTH_BLOC: info.tarifaId = ${info.tarifaId}');
      print('💰 AUTH_BLOC: Tipo de tarifaId: ${info.tarifaId.runtimeType}');
      
      if (info.tarifaId != null) {
        // Guardar como String para consistencia con otros valores
        final tarifaIdString = info.tarifaId.toString();
        print('💰 AUTH_BLOC: Guardando tarifaId como String: "$tarifaIdString"');
        
        await kv.put('tarifaId', tarifaIdString);
        print('✅ AUTH_BLOC: tarifaId guardado en cache (await completado)');
        
        // Verificar inmediatamente después de guardar
        final savedTarifaId = kv.get('tarifaId');
        print('✅ AUTH_BLOC: Verificación inmediata - tarifaId leído desde cache: $savedTarifaId');
        print('✅ AUTH_BLOC: Tipo del valor guardado: ${savedTarifaId?.runtimeType}');
        
        // Listar todas las claves para verificar que tarifaId está presente
        print('💰 AUTH_BLOC: Claves en cache después de guardar: ${kv.keys.toList()}');
      } else {
        print('⚠️ AUTH_BLOC: ⚠️⚠️⚠️ ADVERTENCIA: tarifaId es NULL - No se guardará en cache');
        print('⚠️ AUTH_BLOC: Esto significa que el webhook no incluyó tarifa_id en fieldValues');
        print('⚠️ AUTH_BLOC: Verificar respuesta del webhook para ver si tarifa_id está presente');
      }

      // Autenticar con Odoo usando las credenciales de la licencia
      if (info.serverUrl != null && info.database != null && 
          info.username != null && info.password != null) {
        print('🔐 AUTH_BLOC: ═══════════════════════════════════════════════');
        print('🔐 AUTH_BLOC: Iniciando autenticación con Odoo...');
        print('🔐 AUTH_BLOC: ═══════════════════════════════════════════════');
        print('🔐 AUTH_BLOC: Licencia: ${info.licenseNumber}');
        print('🔐 AUTH_BLOC: Server: ${info.serverUrl}');
        print('🔐 AUTH_BLOC: Database: ${info.database}');
        print('🔐 AUTH_BLOC: Username: ${info.username}');
        print('🔐 AUTH_BLOC: Password: ${info.password?.substring(0, 2)}***');
        print('🔐 AUTH_BLOC: Tipo de venta: ${info.tipoven}');
        print('🔐 AUTH_BLOC: ═══════════════════════════════════════════════');
        
        try {
          final loginSuccess = await loginWithCredentials(
            username: info.username!,
            password: info.password!,
            serverUrl: info.serverUrl,
            database: info.database,
            licenseNumber: info.licenseNumber,
          );
          
          if (!loginSuccess) {
            print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
            print('❌ AUTH_BLOC: AUTENTICACIÓN FALLÓ');
            print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
            print('❌ AUTH_BLOC: Posibles causas:');
            print('❌ AUTH_BLOC: 1. Credenciales incorrectas para esta instancia');
            print('❌ AUTH_BLOC: 2. Usuario bloqueado o sin permisos');
            print('❌ AUTH_BLOC: 3. Base de datos incorrecta o no existe');
            print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
            final errorMsg = 'Credenciales inválidas para la base de datos "${info.database}".\n\nVerifica que el usuario y contraseña sean correctos para esta instancia de Odoo.';
            print('🔴 AUTH_BLOC: ⚠️ EMITIENDO AuthError: $errorMsg');
            emit(AuthError(errorMsg));
            print('🔴 AUTH_BLOC: ✅ AuthError EMITIDO, retornando...');
            return;
          }
          
          print('✅ AUTH_BLOC: Autenticación con Odoo exitosa');
          
          // 🚧 TEMPORAL: Desactivar PIN - Siempre ir directo a la app
          // TODO: Reactivar validación de tipoven cuando se necesite PIN
          print('🔓 AUTH_BLOC: [TEMPORAL] PIN desactivado - Login directo');
          print('✅ AUTH_BLOC: Emitiendo AuthAuthenticated (sin PIN)');
          
          // Obtener datos del usuario desde cache
          final userId = kv.get('userId')?.toString() ?? 'unknown';
          final username = kv.get('username')?.toString() ?? info.username ?? 'Admin';
          
          emit(AuthAuthenticated(
            username: username,
            userId: userId,
            database: info.database ?? '',
          ));
          return;
          
          // CÓDIGO ORIGINAL (comentado temporalmente):
          /*
          // Si tipoven es "U" (Usuario/Admin), ir directamente a la app sin PIN
          if (info.tipoven?.toUpperCase() == 'U') {
            print('🔓 AUTH_BLOC: Tipo de venta "U" - Login directo como administrador');
            print('✅ AUTH_BLOC: Emitiendo AuthAuthenticated (sin PIN)');
            
            // Obtener datos del usuario desde cache
            final userId = kv.get('userId')?.toString() ?? 'unknown';
            final username = kv.get('username')?.toString() ?? info.username ?? 'Admin';
            
            emit(AuthAuthenticated(
              username: username,
              userId: userId,
              database: info.database ?? '',
            ));
            return;
          }
          */
          
        } catch (e) {
          print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
          print('❌ AUTH_BLOC: EXCEPCIÓN EN AUTENTICACIÓN');
          print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
          print('❌ AUTH_BLOC: Error: $e');
          print('❌ AUTH_BLOC: Tipo: ${e.runtimeType}');
          
          // Extraer mensaje específico según el tipo de error
          String errorMsg = 'Error conectando con servidor Odoo';
          
          if (e.toString().contains('Servidor no disponible')) {
            // Error 503 o servidor caído
            errorMsg = '🔴 Servidor no disponible\n\nEl servidor "${info.serverUrl}" no está respondiendo correctamente.\n\nPosibles causas:\n• El servidor está en mantenimiento\n• Problemas técnicos temporales\n• URL incorrecta\n\n💡 Solución: Contacta al administrador o intenta más tarde.';
          } else if (e.toString().contains('AccessError')) {
            errorMsg = 'Acceso denegado: Las credenciales no son válidas para la base de datos "${info.database}".\n\nContacta al administrador del sistema.';
          } else if (e.toString().contains('database')) {
            errorMsg = 'La base de datos "${info.database}" no existe o no está disponible.';
          } else if (e.toString().contains('FormatException')) {
            errorMsg = '🔴 Servidor no disponible\n\nEl servidor no está devolviendo respuestas válidas.\n\nContacta al administrador del sistema.';
          }
          
          print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
          print('🔴 AUTH_BLOC: ⚠️ EMITIENDO AuthError (desde catch): $errorMsg');
          emit(AuthError(errorMsg));
          print('🔴 AUTH_BLOC: ✅ AuthError EMITIDO (desde catch), retornando...');
          return;
        }
      }

      // 🚧 TEMPORAL: Este código nunca se alcanza porque siempre hacemos return arriba
      // CÓDIGO ORIGINAL (comentado - validación de PIN desactivada):
      /*
      // Si llegamos aquí y tipoven es "E", emitir AuthLicenseValidated para pedir PIN
      print('🔐 AUTH_BLOC: Tipo de venta "${info.tipoven}" - Se requiere PIN de empleado');
      print('✅ AUTH_BLOC: Emitiendo AuthLicenseValidated');
      emit(AuthLicenseValidated(
        licenseNumber: info.licenseNumber,
        serverUrl: info.serverUrl,
        database: info.database,
        tipoven: info.tipoven,
      ));
      */
      
      // 🚧 TEMPORAL: Como el PIN está desactivado, esto no debería ejecutarse
      print('⚠️ AUTH_BLOC: Código inalcanzable - PIN está desactivado temporalmente');
    } catch (e, stackTrace) {
      print('❌ AUTH_BLOC: Error validando licencia: $e');
      print('❌ AUTH_BLOC: Stack trace: $stackTrace');
      emit(AuthError('Error validando licencia: $e'));
    }
  }

  // Maneja login por PIN
  Future<void> _onEmployeePinLoginRequested(EmployeePinLoginRequested event, Emitter<AuthState> emit) async {
    print('🔢 AUTH_BLOC: Procesando login por PIN: ${event.pin}');
    emit(AuthLoading());
    
    try {
      final repo = getIt<EmployeeRepository>();
      print('🔢 AUTH_BLOC: Validando PIN con EmployeeRepository...');
      
      final employee = await repo.validatePin(event.pin);
      
      if (employee == null) {
        print('❌ AUTH_BLOC: PIN inválido o múltiples coincidencias');
        emit(AuthError('PIN inválido. Verifica tu código de empleado.'));
        return;
      }
      
      print('✅ AUTH_BLOC: Empleado encontrado:');
      print('   - ID: ${employee.id}');
      print('   - Nombre: ${employee.name}');
      print('   - User ID: ${employee.userId}');
      print('   - User Name: ${employee.userName}');
      print('   - Email: ${employee.workEmail}');
      print('   - Puesto: ${employee.jobTitle}');
      
      // Guardar información del empleado en cache
      final kv = getIt<CustomOdooKv>();
      kv.put('employeeId', employee.id);
      kv.put('employeeName', employee.name);
      
      if (employee.userId != null) {
        // Caso ideal: empleado tiene usuario de Odoo vinculado
        kv.put('userId', employee.userId.toString());
        print('💾 AUTH_BLOC: User ID del empleado guardado: ${employee.userId}');
      } else {
        // Caso no ideal: empleado sin usuario de Odoo
        print('⚠️ ═══════════════════════════════════════════════════════════');
        print('⚠️ ADVERTENCIA: Empleado "${employee.name}" sin usuario Odoo');
        print('⚠️ ═══════════════════════════════════════════════════════════');
        print('⚠️ Employee ID: ${employee.id} (tabla hr.employee)');
        print('⚠️ User ID en Odoo: NO EXISTE (user_id = false)');
        print('⚠️ ');
        print('⚠️ CONSECUENCIA:');
        print('⚠️ - Las órdenes mostrarán "ADMINISTRATOR" como responsable');
        print('⚠️ - Se pierde trazabilidad del vendedor real');
        print('⚠️ ');
        print('⚠️ SOLUCIÓN en Odoo:');
        print('⚠️ 1. Ir a: Empleados > ${employee.name}');
        print('⚠️ 2. Campo "Usuario relacionado" > Crear usuario');
        print('⚠️ 3. Asignar permisos de "Ventas / Usuario"');
        print('⚠️ ═══════════════════════════════════════════════════════════');
        // NO sobrescribir userId - mantener el de la sesión (admin)
      }
      
      if (employee.workEmail != null) kv.put('employeeEmail', employee.workEmail);
      if (employee.jobTitle != null) kv.put('employeeJobTitle', employee.jobTitle);
      print('💾 AUTH_BLOC: Información de empleado guardada en cache');
      
      // Asegurarse de que OdooSession esté registrado en GetIt
      print('🔧 AUTH_BLOC: Verificando OdooSession en GetIt...');
      if (!getIt.isRegistered<OdooSession>()) {
        print('⚠️ AUTH_BLOC: OdooSession no registrado, re-inicializando desde cache...');
        final sessionJson = kv.get(AppConstants.cacheSessionKey) as String?;
        if (sessionJson != null) {
          final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
          final session = OdooSession.fromJson(sessionData);
          initAuthScope(session);
          print('✅ AUTH_BLOC: OdooSession re-registrado exitosamente');
        } else {
          print('❌ AUTH_BLOC: No se encontró sesión en cache');
          emit(AuthError('Error: Sesión de Odoo no disponible. Por favor, reinicie la aplicación.'));
          return;
        }
      } else {
        print('✅ AUTH_BLOC: OdooSession ya está registrado');
      }
      
      // Emitir estado autenticado con el empleado
      print('✅ AUTH_BLOC: Emitiendo AuthAuthenticated');
      final effectiveUserId = employee.userId?.toString() ?? employee.id.toString();
      print('✅ AUTH_BLOC: userId efectivo para AuthState: $effectiveUserId');
      
      emit(AuthAuthenticated(
        username: employee.name,
        userId: effectiveUserId,
        database: kv.get('database') ?? 'unknown',
      ));
    } catch (e, stackTrace) {
      print('❌ AUTH_BLOC: Error login por PIN: $e');
      print('❌ AUTH_BLOC: Stack trace: $stackTrace');
      emit(AuthError('Error al validar PIN: $e'));
    }
  }



