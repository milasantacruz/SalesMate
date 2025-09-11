import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/cache/custom_odoo_kv.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC para manejar la autenticación de usuarios
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
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
        
        print('✅ Sesión válida encontrada para: $username');
        
        // Las dependencias ya se recrearon en checkExistingSession
        // No necesitamos recrearlas aquí
        
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
}
