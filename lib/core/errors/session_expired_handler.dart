import 'dart:async';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../di/injection_container.dart';

/// Manejador global para sesiones expiradas
class SessionExpiredHandler {
  /// Stream para notificar cuando la sesión expira (lazy creation para hot reload)
  static StreamController<void>? _sessionExpiredController;
  
  static StreamController<void> get _controller {
    _sessionExpiredController ??= StreamController<void>.broadcast();
    return _sessionExpiredController!;
  }
  
  /// Stream público para escuchar eventos de sesión expirada
  static Stream<void> get sessionExpiredStream => _controller.stream;
  
  /// Verifica si el error es una sesión expirada y maneja el logout
  static Future<bool> handleIfSessionExpired(dynamic error) async {
    if (error is OdooSessionExpiredException ||
        error.toString().contains('Session expired') ||
        error.toString().contains('SessionExpired')) {
      
      print('🚨 SESSION_HANDLER: Sesión expirada detectada');
      print('🚪 SESSION_HANDLER: Iniciando logout automático...');
      
      try {
        await logout();
        print('✅ SESSION_HANDLER: Logout completado');
        
        // Notificar a los listeners (AuthBloc)
        print('📢 SESSION_HANDLER: Notificando a listeners...');
        _controller.add(null);
        
        return true; // Indica que se manejó el error
      } catch (e) {
        print('❌ SESSION_HANDLER: Error en logout: $e');
        return false;
      }
    }
    
    return false; // No es un error de sesión expirada
  }
  
  /// Ejecuta una función y maneja automáticamente sesiones expiradas
  static Future<T> executeWithSessionHandling<T>(
    Future<T> Function() operation, {
    required T Function() onSessionExpired,
  }) async {
    try {
      return await operation();
    } catch (e) {
      final wasHandled = await handleIfSessionExpired(e);
      if (wasHandled) {
        return onSessionExpired();
      }
      rethrow;
    }
  }
}

