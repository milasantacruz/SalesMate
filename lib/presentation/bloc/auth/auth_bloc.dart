import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:odoo_repository/odoo_repository.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/cache/custom_odoo_kv.dart';
import '../../../core/errors/session_expired_handler.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../core/license/license_service.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/pricelist_repository.dart';
import '../../../data/repositories/tax_repository.dart';
import '../../../core/network/network_connectivity.dart';
import '../../../core/http/odoo_client_mobile.dart';
import '../../../core/audit/audit_event_service.dart';
import '../../../core/device/device_recovery_service.dart';

/// BLoC para manejar la autenticación de usuarios
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  StreamSubscription? _sessionExpiredSubscription;
  
  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<LicenseCheckRequested>(_onLicenseCheckRequested);
    on<EmployeePinLoginRequested>(_onEmployeePinLoginRequested);
    on<RecoveryKeyAcknowledged>(_onRecoveryKeyAcknowledged);
    on<KeyValidationSucceeded>(_onKeyValidationSucceeded);
    on<KeyValidationFailed>(_onKeyValidationFailed);
    on<KeyValidationCancelled>(_onKeyValidationCancelled);
    
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
          await initAuthScope(session);
        }
        
        // ✅ NUEVO: Verificar si requiere PIN y si fue validado
        final tipoven = cache.get('tipoven') as String?;
        print('🔍 CHECK_AUTH: tipoven = $tipoven');
        
        if (tipoven?.toUpperCase() == 'U') {
          // Licencia requiere PIN, verificar si fue validado
          final employeeId = cache.get('employeeId');
          print('🔍 CHECK_AUTH: employeeId en cache = $employeeId');
          
          if (employeeId == null) {
            // PIN nunca fue validado, redirigir a pantalla de PIN
            print('⚠️ CHECK_AUTH: Sesión Odoo válida pero PIN no validado');
            print('⚠️ CHECK_AUTH: Redirigiendo a pantalla de PIN...');
            
            final auditService = getIt<AuditEventService>();
            unawaited(
              auditService.recordWarning(
                category: 'auth',
                message: 'Intento de acceso sin PIN validado',
                metadata: {
                  'tipoven': tipoven,
                  'hasSession': true,
                  'hasEmployeeId': false,
                },
              ),
            );
            
            final licenseNumber = cache.get('licenseNumber') as String?;
            final serverUrl = cache.get('serverUrl') as String?;
            
            emit(AuthLicenseValidated(
              licenseNumber: licenseNumber ?? 'unknown',
              serverUrl: serverUrl,
              database: database,
              tipoven: tipoven,
            ));
            return;
          }
          
          // PIN fue validado, continuar normalmente
          print('✅ CHECK_AUTH: PIN previamente validado (employeeId: $employeeId)');
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
          await initAuthScope(session);
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

      // 🔑 VALIDACIÓN/REGISTRO DE UUID (KEY RECOVERY)
      print('🔑 AUTH_BLOC: ═══════════════════════════════════════════════');
      print('🔑 AUTH_BLOC: Validando/Registrando UUID del dispositivo');
      print('🔑 AUTH_BLOC: ═══════════════════════════════════════════════');
      
      final deviceRecoveryService = getIt<DeviceRecoveryService>();
        final auditService = getIt<AuditEventService>();
      
      // Si la licencia no tiene IMEI (license.imei == null), obtener/generar UUID y validar historial
      if (info.imei == null || info.imei!.isEmpty) {
        print('🔑 AUTH_BLOC: Licencia sin UUID - Verificando cache local...');
        
        // Verificar primero si existe UUID en cache local
        String newUUID;
        final storedUUID = deviceRecoveryService.getStoredUUID();
        
        if (storedUUID != null && deviceRecoveryService.isValidUUID(storedUUID)) {
          // Reutilizar UUID del cache si existe y es válido
          print('✅ AUTH_BLOC: UUID encontrado en cache: $storedUUID');
          print('🔑 AUTH_BLOC: Reutilizando UUID existente para validar/registrar en backend');
          newUUID = storedUUID;
        } else {
          // Generar nuevo UUID solo si no existe en cache o es inválido
          if (storedUUID != null) {
            print('⚠️ AUTH_BLOC: UUID en cache es inválido: $storedUUID');
          } else {
            print('🔑 AUTH_BLOC: No hay UUID en cache');
          }
          print('🔑 AUTH_BLOC: Generando nuevo UUID...');
          newUUID = deviceRecoveryService.generateUUID();
          print('🔑 AUTH_BLOC: UUID generado: $newUUID');
        }
        
        // Consultar historial de la licencia
        print('📜 AUTH_BLOC: Consultando historial de la licencia...');
        final historyResult = await service.getLicenseHistory(info.licenseNumber);
        
        if (!historyResult.success) {
          print('❌ AUTH_BLOC: Error obteniendo historial: ${historyResult.error}');
          
          // Mensaje más específico según el error
          String errorMessage = 'Error obteniendo historial de licencia. Por favor, intente nuevamente.';
          final error = historyResult.error?.toLowerCase() ?? '';
          
          if (error.contains('network') || error.contains('connection')) {
            errorMessage = 'Error de conexión al verificar historial. Verifique su conexión a internet.';
          } else if (error.contains('not found') || error.contains('404')) {
            errorMessage = 'Licencia no encontrada en el sistema. Verifique el número de licencia.';
          } else if (error.contains('unauthorized') || error.contains('401')) {
            errorMessage = 'No autorizado para acceder al historial. Contacte al administrador.';
          }
          
        await auditService.recordError(
          category: 'auth',
            message: 'Error obteniendo historial de licencia',
            metadata: {
              'license': info.licenseNumber,
              'error': historyResult.error ?? 'Error desconocido',
            },
          );
          emit(AuthError(errorMessage));
        return;
      }
      
        // Validar si el UUID generado existe en el historial (dispositivo bloqueado)
        if (historyResult.containsImei(newUUID)) {
          print('❌ AUTH_BLOC: UUID generado existe en historial - Dispositivo bloqueado');
          await auditService.recordError(
            category: 'auth',
            message: 'Dispositivo bloqueado por administrador',
            metadata: {
              'license': info.licenseNumber,
              'uuid': newUUID,
            },
          );
          emit(AuthError('El dispositivo fue bloqueado por el administrador. Si considera que es un error, comuníquese con el administrador.'));
          return;
        }
        
        print('✅ AUTH_BLOC: UUID no está en historial - Procediendo con registro...');
        
        try {
          // Registrar UUID en backend
          final registrationResult = await service.registerImei(
            info.licenseNumber,
            newUUID,
          );
          
          if (registrationResult.success) {
            print('✅ AUTH_BLOC: UUID registrado exitosamente');
            
            // Guardar UUID en cache local
            await deviceRecoveryService.storeUUID(newUUID);
            print('✅ AUTH_BLOC: UUID guardado en cache local');
            
            await auditService.recordInfo(
              category: 'auth',
              message: 'UUID registrado exitosamente',
              metadata: {
                'license': info.licenseNumber,
                'uuid': newUUID,
              },
            );
            
            // Emitir estado para mostrar pantalla de recuperación
            // Guardamos la información COMPLETA de la licencia para poder continuar después
            print('🔑 AUTH_BLOC: Emitiendo AuthRecoveryKeyRequired para mostrar credenciales');
            emit(AuthRecoveryKeyRequired(
              uuid: newUUID,
              licenseNumber: info.licenseNumber,
              serverUrl: info.serverUrl,
              database: info.database,
              tipoven: info.tipoven,
              username: info.username,
              password: info.password,
              tarifaId: info.tarifaId,
              empresaId: info.empresaId,
            ));
            return;
          } else {
            // Manejar errores según el tipo
            if (registrationResult.errorType == ImeiRegistrationErrorType.licenseNotFound) {
              print('❌ AUTH_BLOC: Licencia no encontrada');
              await auditService.recordError(
                category: 'auth',
                message: 'Licencia no encontrada al registrar IMEI',
                metadata: {
                  'license': info.licenseNumber,
                  'error': registrationResult.message ?? 'Licencia no encontrada',
                },
              );
              emit(AuthError(registrationResult.message ?? 'Licencia no encontrada'));
              return;
            } else if (registrationResult.errorType == ImeiRegistrationErrorType.imeiAlreadyRegistered) {
              print('❌ AUTH_BLOC: UUID ya registrado en otro dispositivo');
              await auditService.recordError(
                category: 'auth',
                message: 'UUID ya registrado en otro dispositivo',
                metadata: {
                  'license': info.licenseNumber,
                  'registeredUUID': registrationResult.registeredImei ?? 'unknown',
                  'currentUUID': newUUID,
                },
              );
              emit(AuthError('Esta licencia ya está vinculada a otro dispositivo, por favor contacte a su administrador'));
              return;
            } else {
              print('❌ AUTH_BLOC: Error desconocido al registrar IMEI');
              await auditService.recordError(
                category: 'auth',
                message: 'Error al registrar IMEI',
                metadata: {
                  'license': info.licenseNumber,
                  'error': registrationResult.message ?? 'Error desconocido',
                },
              );
              emit(AuthError(registrationResult.message ?? 'Error al registrar IMEI. Por favor, intente nuevamente.'));
              return;
            }
          }
        } catch (e, stackTrace) {
          print('❌ AUTH_BLOC: Excepción al registrar IMEI: $e');
          print('❌ AUTH_BLOC: Stack trace: $stackTrace');
          
          // Determinar tipo de error para mensaje más específico
          String errorMessage = 'Error de conexión al registrar UUID. Por favor, intente nuevamente.';
          
          if (e.toString().contains('SocketException') || 
              e.toString().contains('Connection') ||
              e.toString().contains('reset by peer')) {
            errorMessage = 'Error de conexión con el servidor. Verifique su conexión a internet e intente nuevamente.';
          } else if (e.toString().contains('TimeoutException')) {
            errorMessage = 'La solicitud tardó demasiado. Verifique su conexión e intente nuevamente.';
          } else if (e.toString().contains('FormatException')) {
            errorMessage = 'Error en la respuesta del servidor. Contacte al administrador.';
          }
          
          await auditService.recordError(
            category: 'auth',
            message: 'Excepción al registrar IMEI',
            metadata: {
              'license': info.licenseNumber,
              'error': e.toString(),
              'errorType': e.runtimeType.toString(),
            },
          );
          emit(AuthError(errorMessage));
          return;
        }
      } else {
        // La licencia ya tiene UUID (license.imei != null) - validar con cache local
        print('🔑 AUTH_BLOC: Licencia ya tiene UUID - Validando con cache local...');
        print('🔑 AUTH_BLOC: UUID de la licencia: ${info.imei}');
        
        // Obtener UUID del cache local
        final storedUUID = deviceRecoveryService.getStoredUUID();
        print('🔑 AUTH_BLOC: UUID en cache local: ${storedUUID ?? "null"}');
        
        if (storedUUID == null || !deviceRecoveryService.compareUUIDs(storedUUID, info.imei!)) {
          // No hay UUID en cache o no coincide - usuario debe ingresar/escanear key
          if (storedUUID == null) {
            print('🔑 AUTH_BLOC: No hay UUID en cache - Mostrar pantalla de validación de key');
          } else {
            print('❌ AUTH_BLOC: UUID en cache no coincide con el de la licencia');
            print('❌ AUTH_BLOC: UUID de la licencia: ${info.imei}');
            print('❌ AUTH_BLOC: UUID en cache: $storedUUID');
          await auditService.recordError(
            category: 'auth',
              message: 'UUID del dispositivo no coincide con el registrado',
            metadata: {
              'license': info.licenseNumber,
                'registeredUUID': info.imei,
                'cachedUUID': storedUUID,
              },
            );
          }
          
          // Emitir estado para mostrar pantalla de validación de key
          print('🔑 AUTH_BLOC: Emitiendo AuthKeyValidationRequired');
          emit(AuthKeyValidationRequired(
            licenseNumber: info.licenseNumber,
            expectedUUID: info.imei!,
          ));
          return;
        } else {
          print('✅ AUTH_BLOC: UUID coincide - Dispositivo autorizado');
          await auditService.recordInfo(
            category: 'auth',
            message: 'UUID validado correctamente',
            metadata: {
              'license': info.licenseNumber,
              'uuid': storedUUID,
            },
          );
        }
      }
      
      // Continuar con el flujo (guardar configuración, login con Odoo, etc.)
      await _continueAfterUUIDValidation(info, emit);

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
      final auditService = getIt<AuditEventService>();
      final repo = getIt<EmployeeRepository>();
      final kv = getIt<CustomOdooKv>();
      
      // Obtener licenseNumber desde cache
      final licenseNumber = kv.get('licenseNumber') as String?;
      print('🔢 AUTH_BLOC: Licencia activa: ${licenseNumber ?? "sin licencia"}');
      print('🔢 AUTH_BLOC: Validando PIN con EmployeeRepository...');
      
      // Validar PIN con filtro de licencia
      final employee = await repo.validatePin(event.pin, licenseNumber: licenseNumber);
      
      if (employee == null) {
        print('❌ AUTH_BLOC: PIN inválido o empleado no autorizado para esta licencia');
        
        // Mensaje de error específico según si hay licencia o no
        final errorMsg = licenseNumber != null
            ? 'No autorizado para la licencia $licenseNumber.'
            : 'PIN inválido. Verifica tu código de empleado.';
        
        unawaited(
          auditService.recordWarning(
            category: 'auth-pin',
            message: 'PIN inválido o no autorizado para licencia',
            metadata: {
              'pin': event.pin,
              'license': licenseNumber,
            },
          ),
        );
        emit(AuthError(errorMsg));
        return;
      }
      
      // Validar que el barcode del empleado coincida con la licencia activa
      if (licenseNumber != null && employee.barcode != licenseNumber) {
        print('❌ AUTH_BLOC: Empleado encontrado pero barcode no coincide');
        print('❌ AUTH_BLOC: Esperado: $licenseNumber, Obtenido: ${employee.barcode}');
        
        unawaited(
          auditService.recordError(
            category: 'auth-pin',
            message: 'Empleado no autorizado para esta licencia (barcode no coincide)',
            metadata: {
              'employeeId': employee.id,
              'employeeName': employee.name,
              'employeeBarcode': employee.barcode,
              'licenseNumber': licenseNumber,
            },
          ),
        );
        
        emit(AuthError('No autorizado para la licencia $licenseNumber.'));
        return;
      }
      
      print('✅ AUTH_BLOC: Empleado encontrado y autorizado:');
      print('   - ID: ${employee.id}');
      print('   - Nombre: ${employee.name}');
      print('   - Barcode: ${employee.barcode}');
      print('   - Licencia activa: $licenseNumber');
      print('   - User ID: ${employee.userId}');
      print('   - User Name: ${employee.userName}');
      print('   - Email: ${employee.workEmail}');
      print('   - Puesto: ${employee.jobTitle}');
      
      // Guardar información del empleado en cache (kv ya está declarado arriba)
      kv.put('employeeId', employee.id);
      kv.put('employeeName', employee.name);
      kv.put('username', employee.name); // ✅ Actualizar username para que _onCheckAuthStatus lo use
      
      if (employee.userId != null) {
        // Caso ideal: empleado tiene usuario de Odoo vinculado
        kv.put('userId', employee.userId.toString());
        print('💾 AUTH_BLOC: User ID del empleado guardado: ${employee.userId}');
        unawaited(
          auditService.recordInfo(
            category: 'auth-pin',
            message: 'PIN validado con usuario asociado',
            metadata: {
              'employeeId': employee.id,
              'userId': employee.userId,
              'employeeName': employee.name,
            },
          ),
        );
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
        try {
          final session = getIt<OdooSession>();
          final fallbackUserId = session.userId.toString();
          kv.put('userId', fallbackUserId);
          print('⚠️ AUTH_BLOC: Fallback a userId de sesión: $fallbackUserId');
          unawaited(
            auditService.recordWarning(
              category: 'auth-pin',
              message: 'Empleado sin user_id, se aplica fallback',
              metadata: {
                'employeeId': employee.id,
                'employeeName': employee.name,
                'fallbackUserId': fallbackUserId,
              },
            ),
          );
        } catch (e) {
          print('⚠️ AUTH_BLOC: No se pudo obtener userId de sesión para fallback: $e');
          unawaited(
            auditService.recordError(
              category: 'auth-pin',
              message: 'Fallback a user_id falló (sin sesión)',
              metadata: {
                'employeeId': employee.id,
                'error': e.toString(),
              },
            ),
          );
        }
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
          await initAuthScope(session);
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
      unawaited(
        auditService.recordInfo(
          category: 'auth-pin',
          message: 'PIN aceptado, sesión autenticada',
          metadata: {
            'employeeId': employee.id,
            'employeeName': employee.name,
            'userId': kv.get('userId'),
          },
        ),
      );
      final effectiveUserId = employee.userId?.toString() ?? employee.id.toString();
      print('✅ AUTH_BLOC: userId efectivo para AuthState: $effectiveUserId');
      
      emit(AuthAuthenticated(
        username: employee.name,
        userId: kv.get('userId'),
        database: kv.get('database') ?? '',
      ));
    } catch (e) {
      print('❌ AUTH_BLOC: Error login por PIN: $e');
      unawaited(
        getIt<AuditEventService>().recordError(
          category: 'auth-pin',
          message: 'Excepción validando PIN',
          metadata: {
            'error': e.toString(),
            'pin': event.pin,
          },
        ),
      );
      emit(AuthError('Error al validar PIN: $e'));
    }
  }

  /// Maneja el evento cuando el usuario hace clic en "Continuar" en la pantalla de recuperación
  /// 
  /// Este handler emite AuthLicenseValidated para continuar el flujo normal de autenticación
  /// después de que el usuario haya visto y guardado sus credenciales de recuperación.
  Future<void> _onRecoveryKeyAcknowledged(
    RecoveryKeyAcknowledged event,
    Emitter<AuthState> emit,
  ) async {
    print('🔑 AUTH_BLOC: Usuario confirmó haber guardado credenciales de recuperación');
    
    // Reconstruir LicenseInfo desde los datos del evento
    // Necesitamos llamar a _continueAfterUUIDValidation para hacer el login completo
    print('🔑 AUTH_BLOC: Reconstruyendo LicenseInfo para continuar flujo de autenticación');
    
    // Crear LicenseInfo con los datos guardados en el evento
    final info = LicenseInfo(
      success: true, // Ya fue validado
      isActive: true, // Ya fue validado
      licenseNumber: event.licenseNumber,
      serverUrl: event.serverUrl,
      database: event.database,
      username: event.username,
      password: event.password,
      tipoven: event.tipoven,
      tarifaId: event.tarifaId,
      empresaId: event.empresaId,
      imei: null, // Ya se registró el UUID
    );
    
    // Continuar con el flujo completo (login, inicialización de repositorios, etc.)
    print('🔑 AUTH_BLOC: Llamando a _continueAfterUUIDValidation para completar autenticación');
    await _continueAfterUUIDValidation(info, emit);
  }

  /// Maneja el evento cuando la key de recuperación fue validada exitosamente
  Future<void> _onKeyValidationSucceeded(
    KeyValidationSucceeded event,
    Emitter<AuthState> emit,
  ) async {
    print('🔑 AUTH_BLOC: Key de recuperación validada exitosamente');
    print('🔑 AUTH_BLOC: UUID guardado en cache: ${event.uuid}');
    
    final auditService = getIt<AuditEventService>();
    await auditService.recordInfo(
      category: 'auth',
      message: 'Key de recuperación validada exitosamente',
      metadata: {
        'license': event.licenseNumber,
        'uuid': event.uuid,
      },
    );
    
    // Continuar con el flujo normal - obtener información de la licencia y continuar
    try {
      final service = LicenseService();
      final info = await service.fetchLicense(event.licenseNumber);
      
      if (!info.success || !info.isActive) {
        emit(AuthError('Licencia no activa o inválida'));
        return;
      }
      
      // El UUID ya está validado y guardado en cache
      // Continuar con el flujo desde donde se guarda la configuración y hace login
      await _continueAfterUUIDValidation(info, emit);
    } catch (e) {
      print('❌ AUTH_BLOC: Error obteniendo información de licencia después de validar key: $e');
      emit(AuthError('Error al continuar después de validar key. Por favor, intente nuevamente.'));
    }
  }

  /// Método helper para continuar el flujo después de validar el UUID
  /// 
  /// Este método se llama tanto desde el flujo normal (cuando UUID coincide)
  /// como desde el handler de validación de key exitosa.
  Future<void> _continueAfterUUIDValidation(
    LicenseInfo info,
    Emitter<AuthState> emit,
  ) async {
    print('🔑 AUTH_BLOC: ═══════════════════════════════════════════════');
    print('🔑 AUTH_BLOC: Validación/Registro de UUID completado');
    print('🔑 AUTH_BLOC: ═══════════════════════════════════════════════');
      
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
        
        // ✅ NUEVO: Cachear items de pricelist en background
        try {
          final netConn = getIt<NetworkConnectivity>();
          final connState = await netConn.checkNetConn();
          if (connState == netConnState.online) {
            // Ejecutar en background - no bloquear login
            Future.microtask(() async {
              try {
                final pricelistRepo = getIt<PricelistRepository>();
                await pricelistRepo.cachePricelistItems(info.tarifaId!);
                print('✅ AUTH_BLOC: Items de pricelist cacheados en background');
                // Verificar que se guardó correctamente
                final kv = getIt<CustomOdooKv>();
                final cacheKey = 'pricelist_items_${info.tarifaId!}';
                final verifyCache = kv.get(cacheKey);
                print('🔍 AUTH_BLOC: Verificación cache - tipo: ${verifyCache.runtimeType}, es null: ${verifyCache == null}');
                if (verifyCache is List) {
                  print('🔍 AUTH_BLOC: Verificación cache - items guardados: ${verifyCache.length}');
                  if (verifyCache.isNotEmpty) {
                    print('🔍 AUTH_BLOC: Primer item del cache guardado: ${verifyCache.first}');
                  }
                }
              } catch (e) {
                print('⚠️ AUTH_BLOC: Error cacheando items de pricelist (no crítico): $e');
              }
            });
          } else {
            print('⚠️ AUTH_BLOC: Sin conexión - no se cachean items de pricelist');
          }
        } catch (e) {
          print('⚠️ AUTH_BLOC: Error verificando conexión para cacheo (no crítico): $e');
          // No bloquear login por error en cacheo
        }
      } else {
        print('⚠️ AUTH_BLOC: ⚠️⚠️⚠️ ADVERTENCIA: tarifaId es NULL - No se guardará en cache');
        print('⚠️ AUTH_BLOC: Esto significa que el webhook no incluyó tarifa_id en fieldValues');
        print('⚠️ AUTH_BLOC: Verificar respuesta del webhook para ver si tarifa_id está presente');
      }
      
      // Guardar empresaId (importante para filtrado de impuestos y otros datos)
      print('🏢 AUTH_BLOC: Verificando empresaId en LicenseInfo...');
      print('🏢 AUTH_BLOC: info.empresaId = ${info.empresaId}');
      print('🏢 AUTH_BLOC: Tipo de empresaId: ${info.empresaId.runtimeType}');
      
      if (info.empresaId != null) {
        // Guardar como String para consistencia con otros valores
        final empresaIdString = info.empresaId.toString();
        print('🏢 AUTH_BLOC: Guardando empresaId como String: "$empresaIdString"');
        
        await kv.put('companyId', empresaIdString);
        print('✅ AUTH_BLOC: empresaId guardado en cache (await completado)');
        
        // Verificar inmediatamente después de guardar
        final savedEmpresaId = kv.get('companyId');
        print('✅ AUTH_BLOC: Verificación inmediata - companyId leído desde cache: $savedEmpresaId');
        print('✅ AUTH_BLOC: Tipo del valor guardado: ${savedEmpresaId?.runtimeType}');
        
        // Listar todas las claves para verificar que companyId está presente
        print('🏢 AUTH_BLOC: Claves en cache después de guardar companyId: ${kv.keys.toList()}');
        
        // ✅ NUEVO: Cachear impuestos en background
        try {
          final netConn = getIt<NetworkConnectivity>();
          final connState = await netConn.checkNetConn();
          if (connState == netConnState.online) {
            // Ejecutar en background - no bloquear login
            Future.microtask(() async {
              try {
                print('✅ AUTH_BLOC: Iniciando try');
                final taxRepo = getIt<TaxRepository>();
                await taxRepo.cacheTaxes(info.empresaId!);
                print('✅ AUTH_BLOC: Impuestos cacheados en background para company ${info.empresaId}');
                // Verificar que se guardó correctamente
                final kv = getIt<CustomOdooKv>();
                final cacheKey = 'taxes_${info.empresaId!}';
                final verifyCache = kv.get(cacheKey);
                print('🔍 AUTH_BLOC: Verificación cache impuestos - tipo: ${verifyCache.runtimeType}, es null: ${verifyCache == null}');
                if (verifyCache is List) {
                  print('🔍 AUTH_BLOC: Verificación cache impuestos - cantidad guardada: ${verifyCache.length}');
                  if (verifyCache.isNotEmpty) {
                    print('🔍 AUTH_BLOC: Primer impuesto del cache guardado: ${verifyCache.first}');
                  }
                }
              } catch (e) {
                print('⚠️ AUTH_BLOC: Error cacheando impuestos (no crítico): $e');
              }
            });
          } else {
            print('⚠️ AUTH_BLOC: Sin conexión - no se cachean impuestos');
          }
        } catch (e) {
          print('⚠️ AUTH_BLOC: Error verificando conexión para cacheo de impuestos (no crítico): $e');
          // No bloquear login por error en cacheo
        }
      } else {
        print('⚠️ AUTH_BLOC: ⚠️⚠️⚠️ ADVERTENCIA: empresaId es NULL - No se guardará en cache');
        print('⚠️ AUTH_BLOC: Esto significa que el webhook no incluyó empresa_id en fieldValues');
        print('⚠️ AUTH_BLOC: Verificar respuesta del webhook para ver si empresa_id está presente');
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
          
          // ✅ NUEVO: Inicializar sesión en repositorios ANTES de cachear
          // Esto asegura que OdooEnvironment se cree con session.dbName correcto
          // y que los repos tengan sesión válida (igual que en _onLoginRequested)
          print('🔍 AUTH_BLOC: ═══════════════════════════════════════════════');
          print('🔍 AUTH_BLOC: Iniciando inicialización de sesión en repositorios...');
          try {
            final cache = getIt<CustomOdooKv>();
            print('🔍 AUTH_BLOC: Cache obtenido correctamente');
            
            final sessionJson = cache.get(AppConstants.cacheSessionKey) as String?;
            print('🔍 AUTH_BLOC: sessionJson obtenido: ${sessionJson != null ? "SÍ (${sessionJson.length} chars)" : "NULL"}');
            
            if (sessionJson != null) {
              print('🔍 AUTH_BLOC: Deserializando sesión desde JSON...');
              final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
              print('🔍 AUTH_BLOC: sessionData decodificado - session.id: ${sessionData['id']}');
              
              final session = OdooSession.fromJson(sessionData);
              print('🔍 AUTH_BLOC: OdooSession creada - id: "${session.id}", dbName: "${session.dbName}"');
              
              // Verificar estado del OdooClient antes de initAuthScope
              final clientBefore = getIt<OdooClient>();
              print('🔍 AUTH_BLOC: OdooClient antes de initAuthScope:');
              print('🔍 AUTH_BLOC:   - baseURL: ${clientBefore.baseURL}');
              print('🔍 AUTH_BLOC:   - sessionId: ${clientBefore.sessionId?.id ?? "NULL"}');
              print('🔍 AUTH_BLOC:   - httpClient type: ${clientBefore.httpClient.runtimeType}');
              
              await initAuthScope(session);  // ← Esto inicializa la sesión en los repos y espera re-auth
              print('✅ AUTH_BLOC: Sesión inicializada en repositorios');
              
              // Verificar estado después de initAuthScope
              final env = getIt<OdooEnvironment>();
              print('🔍 AUTH_BLOC: OdooEnvironment después de initAuthScope:');
              print('🔍 AUTH_BLOC:   - dbName: ${env.dbName}');
              print('🔍 AUTH_BLOC:   - orpc runtimeType: ${env.orpc.runtimeType}');
              
              final clientAfter = getIt<OdooClient>();
              print('🔍 AUTH_BLOC: OdooClient después de initAuthScope:');
              print('🔍 AUTH_BLOC:   - baseURL: ${clientAfter.baseURL}');
              print('🔍 AUTH_BLOC:   - sessionId: ${clientAfter.sessionId?.id ?? "NULL"}');
              
              // Si el httpClient es CookieClient, verificar cookies
              if (clientAfter.httpClient is CookieClient) {
                final cookieClient = clientAfter.httpClient as CookieClient;
                final cookies = cookieClient.getCookies();
                print('🔍 AUTH_BLOC: Cookies en CookieClient: ${cookies.length} cookies');
                if (cookies.containsKey('session_id')) {
                  print('🔍 AUTH_BLOC:   - session_id cookie: ${cookies['session_id']}');
                } else {
                  print('⚠️ AUTH_BLOC:   - ⚠️⚠️⚠️ NO HAY session_id en cookies!');
                }
              }
            } else {
              print('⚠️ AUTH_BLOC: No se encontró sesión en cache para inicializar');
              print('⚠️ AUTH_BLOC: Esto significa que loginWithCredentials no guardó la sesión correctamente');
            }
            print('🔍 AUTH_BLOC: ═══════════════════════════════════════════════');
          } catch (e, stackTrace) {
            print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
            print('❌ AUTH_BLOC: ERROR inicializando sesión: $e');
            print('❌ AUTH_BLOC: Stack trace: $stackTrace');
            print('❌ AUTH_BLOC: ═══════════════════════════════════════════════');
            // No bloquear el flujo por error de inicialización, pero los cacheos pueden fallar
          }

          // Cacheos iniciales DESPUÉS de login (repos y sesión ya listos)
          try {
            final netConn = getIt<NetworkConnectivity>();
            final connState = await netConn.checkNetConn();
            if (connState == netConnState.online) {
              // Cachear items de tarifa si existe tarifaId
              if (info.tarifaId != null) {
                try {
                  final pricelistRepo = getIt<PricelistRepository>();
                  print('💰 AUTH_BLOC: Cacheando items de pricelist ${info.tarifaId}...');
                  await pricelistRepo.cachePricelistItems(info.tarifaId!);
                  print('✅ AUTH_BLOC: Items de pricelist cacheados tras login');
                  final kvPl = getIt<CustomOdooKv>();
                  final verifyPl = kvPl.get('pricelist_items_${info.tarifaId!}');
                  print('🔍 AUTH_BLOC: Verificación cache pricelist - tipo: ${verifyPl.runtimeType}, es null: ${verifyPl == null}');
                  if (verifyPl is List) {
                    print('🔍 AUTH_BLOC: Verificación cache pricelist - items guardados: ${verifyPl.length}');
                  }
                } catch (e) {
                  print('⚠️ AUTH_BLOC: Error cacheando items de pricelist tras login: $e');
                }
              }

              // Cachear impuestos si existe empresaId
              if (info.empresaId != null) {
                try {
                  final taxRepo = getIt<TaxRepository>();
                  print('💰 AUTH_BLOC: Cacheando impuestos company ${info.empresaId}...');
                  await taxRepo.cacheTaxes(info.empresaId!);
                  print('✅ AUTH_BLOC: Impuestos cacheados tras login para company ${info.empresaId}');
                  final kvTx = getIt<CustomOdooKv>();
                  final verifyTx = kvTx.get('taxes_${info.empresaId!}');
                  print('🔍 AUTH_BLOC: Verificación cache impuestos - tipo: ${verifyTx.runtimeType}, es null: ${verifyTx == null}');
                  if (verifyTx is List) {
                    print('🔍 AUTH_BLOC: Verificación cache impuestos - cantidad guardada: ${verifyTx.length}');
                  }
                } catch (e) {
                  print('⚠️ AUTH_BLOC: Error cacheando impuestos tras login: $e');
                }
              }
            } else {
              print('⚠️ AUTH_BLOC: Sin conexión tras login - se omite cacheo inicial');
            }
          } catch (e) {
            print('⚠️ AUTH_BLOC: Error general en cacheos post-login: $e');
          }

          // Determinar flujo según tipoven
          final tipoVenta = info.tipoven?.toUpperCase();
          final cachedUserId = kv.get('userId')?.toString() ?? 'unknown';
          final cachedUsername = kv.get('username')?.toString() ?? info.username ?? 'Admin';

          final auditService = getIt<AuditEventService>();

          if (tipoVenta == 'E') {
            unawaited(
              auditService.recordInfo(
                category: 'auth',
                message: 'Login directo por tipoven=E',
                metadata: {
                  'license': info.licenseNumber,
                  'username': cachedUsername,
                  'companyId': info.empresaId,
                },
              ),
            );
            print('🔓 AUTH_BLOC: Tipo de venta "E" - Login directo (empleado sin PIN)');
            emit(AuthAuthenticated(
              username: cachedUsername,
              userId: cachedUserId,
              database: info.database ?? '',
            ));
            return;
          }

          unawaited(
            auditService.recordInfo(
              category: 'auth',
              message: 'Licencia requiere PIN (tipoven=U)',
              metadata: {
                'license': info.licenseNumber,
                'username': cachedUsername,
                'companyId': info.empresaId,
              },
            ),
          );
          print('🔐 AUTH_BLOC: Tipo de venta "${info.tipoven}" - Se requiere autenticación por PIN');
          emit(AuthLicenseValidated(
            licenseNumber: info.licenseNumber,
            serverUrl: info.serverUrl,
            database: info.database,
            tipoven: info.tipoven,
          ));
          return;
          
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
          unawaited(
            getIt<AuditEventService>().recordError(
              category: 'auth',
              message: 'Error validando licencia',
              metadata: {
                'license': info.licenseNumber,
                'error': e.toString(),
              },
            ),
          );
          print('🔴 AUTH_BLOC: ⚠️ EMITIENDO AuthError (desde catch): $errorMsg');
          emit(AuthError(errorMsg));
          print('🔴 AUTH_BLOC: ✅ AuthError EMITIDO (desde catch), retornando...');
          return;
        }
    }
  }

  /// Maneja el evento cuando la key de recuperación falló la validación
  Future<void> _onKeyValidationFailed(
    KeyValidationFailed event,
    Emitter<AuthState> emit,
  ) async {
    print('❌ AUTH_BLOC: Key de recuperación inválida');
    
      final auditService = getIt<AuditEventService>();
    await auditService.recordError(
      category: 'auth',
      message: 'Key de recuperación inválida',
            metadata: {
        'license': event.licenseNumber,
        'enteredKey': event.enteredKey,
      },
    );
    
    // El error ya fue mostrado en la pantalla, no necesitamos emitir otro estado
    // Solo registramos el evento de auditoría
  }

  /// Maneja el evento cuando el usuario cancela la validación de key
  Future<void> _onKeyValidationCancelled(
    KeyValidationCancelled event,
    Emitter<AuthState> emit,
  ) async {
    print('🚫 AUTH_BLOC: Usuario canceló validación de key para ${event.licenseNumber}');
    
    final auditService = getIt<AuditEventService>();
    await auditService.recordInfo(
      category: 'auth',
      message: 'Usuario canceló validación de key',
          metadata: {
        'license': event.licenseNumber,
      },
    );
    
    // Volver al estado no autenticado para que muestre pantalla de licencia
    print('🚫 AUTH_BLOC: Emitiendo AuthUnauthenticated para volver a pantalla de licencia');
    emit(AuthUnauthenticated());
  }



