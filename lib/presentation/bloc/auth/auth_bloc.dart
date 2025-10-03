import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/cache/custom_odoo_kv.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../core/license/license_service.dart';
import '../../../data/repositories/employee_repository.dart';

/// BLoC para manejar la autenticación de usuarios
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<LicenseCheckRequested>(_onLicenseCheckRequested);
    on<EmployeePinLoginRequested>(_onEmployeePinLoginRequested);
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

      // Autenticar con Odoo usando las credenciales de la licencia
      if (info.serverUrl != null && info.database != null && 
          info.username != null && info.password != null) {
        print('🔐 AUTH_BLOC: Iniciando autenticación con Odoo...');
        print('🔐 AUTH_BLOC: Server: ${info.serverUrl}');
        print('🔐 AUTH_BLOC: Database: ${info.database}');
        print('🔐 AUTH_BLOC: Username: ${info.username}');
        
        try {
          final loginSuccess = await loginWithCredentials(
            username: info.username!,
            password: info.password!,
            serverUrl: info.serverUrl,
            database: info.database,
          );
          
          if (!loginSuccess) {
            print('❌ AUTH_BLOC: Autenticación con Odoo falló');
            emit(AuthError('Error autenticando con servidor Odoo'));
            return;
          }
          
          print('✅ AUTH_BLOC: Autenticación con Odoo exitosa');
        } catch (e) {
          print('❌ AUTH_BLOC: Error en autenticación Odoo: $e');
          emit(AuthError('Error conectando con servidor Odoo: $e'));
          return;
        }
      }

      print('✅ AUTH_BLOC: Emitiendo AuthLicenseValidated');
      emit(AuthLicenseValidated(
        licenseNumber: info.licenseNumber,
        serverUrl: info.serverUrl,
        database: info.database,
      ));
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

