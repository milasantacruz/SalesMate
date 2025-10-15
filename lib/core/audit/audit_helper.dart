import '../di/injection_container.dart';
import '../cache/custom_odoo_kv.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

/// Helper para obtener información de auditoría para operaciones
class AuditHelper {
  /// Obtiene el usuario actual de la sesión de Odoo
  static String get currentUserId {
    try {
      final session = getIt<OdooSession>();
      return session.userId.toString();
    } catch (e) {
      print('⚠️ AUDIT_HELPER: No se pudo obtener userId de sesión: $e');
      return '0';
    }
  }

  /// Obtiene información completa del usuario actual para auditoría
  static Map<String, dynamic> getCurrentUserAuditInfo() {
    try {
      final session = getIt<OdooSession>();
      
      return {
        'user_id': session.userId,
        'db_name': session.dbName,
        'session_id': 'active_session',
        'server_url': 'odoo_server',
      };
    } catch (e) {
      print('⚠️ AUDIT_HELPER: No se pudo obtener información de auditoría: $e');
      return {
        'user_id': 0, // asegurar tipo int para evitar casts inválidos
        'db_name': 'unknown',
        'session_id': 'anonymous',
        'server_url': '',
      };
    }
  }

  /// Genera datos de auditoría para crear registros
  static Map<String, dynamic> getCreateAuditData({
    Map<String, dynamic>? additionalData,
  }) {
    // Intentar obtener el userId del empleado logueado
    int? effectiveUserId;
    try {
      final kv = getIt<CustomOdooKv>();
      final employeeId = kv.get('employeeId');
      final userIdStr = kv.get('userId');
      
      if (userIdStr != null) {
        effectiveUserId = int.tryParse(userIdStr.toString());
        print('📝 AUDIT_HELPER: Usando user_id del empleado: $effectiveUserId (employee_id: $employeeId)');
      }
    } catch (e) {
      print('⚠️ AUDIT_HELPER: No se pudo obtener userId del empleado: $e');
    }
    
    // Si no hay userId del empleado, usar el de la sesión
    if (effectiveUserId == null) {
      final auditInfo = getCurrentUserAuditInfo();
      final dynamic auditUserId = auditInfo['user_id'];
      if (auditUserId is int) {
        effectiveUserId = auditUserId;
      } else if (auditUserId is String) {
        effectiveUserId = int.tryParse(auditUserId);
      }
      print('📝 AUDIT_HELPER: Usando user_id de sesión: $effectiveUserId');
    }
    
    final auditData = {
      'user_id': effectiveUserId,
      ...?additionalData,
    };

    print('🔍 AUDIT_HELPER: Datos de auditoría para crear: $auditData');
    return auditData;
  }

  /// Genera datos de auditoría para actualizar registros
  static Map<String, dynamic> getWriteAuditData({
    Map<String, dynamic>? additionalData,
  }) {
    // Intentar obtener el userId del empleado logueado
    int? effectiveUserId;
    try {
      final kv = getIt<CustomOdooKv>();
      final employeeId = kv.get('employeeId');
      final userIdStr = kv.get('userId');
      
      if (userIdStr != null) {
        effectiveUserId = int.tryParse(userIdStr.toString());
        print('📝 AUDIT_HELPER: Usando user_id del empleado: $effectiveUserId (employee_id: $employeeId)');
      }
    } catch (e) {
      print('⚠️ AUDIT_HELPER: No se pudo obtener userId del empleado: $e');
    }
    
    // Si no hay userId del empleado, usar el de la sesión
    if (effectiveUserId == null) {
      final auditInfo = getCurrentUserAuditInfo();
      final dynamic auditUserId = auditInfo['user_id'];
      if (auditUserId is int) {
        effectiveUserId = auditUserId;
      } else if (auditUserId is String) {
        effectiveUserId = int.tryParse(auditUserId);
      }
      print('📝 AUDIT_HELPER: Usando user_id de sesión: $effectiveUserId');
    }
    
    final auditData = {
      'user_id': effectiveUserId,
      ...?additionalData,
    };

    print('🔍 AUDIT_HELPER: Datos de auditoría para actualizar: $auditData');
    return auditData;
  }

  /// Obtiene información del empleado actual si está disponible
  static Map<String, dynamic> getCurrentEmployeeInfo() {
    try {
      final session = getIt<OdooSession>();
      
      return {
        'user_id': session.userId,
        'logged_at': DateTime.now().toIso8601String(),
        'action': 'manual', // Indica que es acción manual del usuario
      };
    } catch (e) {
      print('⚠️ AUDIT_HELPER: No se pudo obtener información de empleado: $e');
      return {
        'user_id': '0',
        'logged_at': DateTime.now().toIso8601String(),
        'action': 'manual',
      };
    }
  }

  /// Convierte string a int con fallback seguro
  static int parseIntWithFallback(String value) {
    try {
      return int.parse(value);
    } catch (e) {
      print('⚠️ AUDIT_HELPER: Error parseando "$value" a int, usando 0');
      return 0;
    }
  }

  /// Formatea información de auditoría para logs
  static String formatAuditLog(String operation, {String? details}) {
    final auditInfo = getCurrentUserAuditInfo();
    final timestamp = DateTime.now().toIso8601String();
    
    return '[AUDIT $timestamp] User: ${auditInfo['user_id']} | '
           'Operation: $operation | '
           'Database: ${auditInfo['db_name']} | '
           'Session: ${auditInfo['session_id']}'
           '${details != null ? ' | Details: $details' : ''}';
  }
}
