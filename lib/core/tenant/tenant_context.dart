import 'tenant_exception.dart';

/// Gestor global de contexto single-tenant con detección de cambios
/// 
/// ⚠️ v2.0: Solo se cachea UNA licencia a la vez
/// 
/// Mantiene el tenant (licencia) actual, detecta cambios de licencia
/// y proporciona métodos para generar claves scoped automáticamente.
/// 
/// Ejemplo de uso:
/// ```dart
/// // En login
/// final previousLicense = TenantContext.setTenant('POF0001', 'db_pof0001');
/// if (previousLicense != null) {
///   // Cambio de licencia detectado - limpiar cache anterior
///   await tenantCache.clearTenant(previousLicense);
/// }
/// 
/// // En repositorios
/// final scopedKey = TenantContext.scopeKey('Partner_records');
/// // Resultado: "POF0001:Partner_records"
/// ```
class TenantContext {
  static String? _currentLicenseNumber;
  static String? _currentDatabase;
  static String? _previousLicenseNumber;  // Para detectar cambios
  static DateTime? _tenantSetAt;
  
  /// Establece el tenant actual y detecta cambios de licencia
  /// 
  /// ⚠️ IMPORTANTE v2.0: Si la licencia cambia, retorna la licencia anterior
  /// para que el llamador pueda limpiar su cache
  /// 
  /// Debe llamarse después de autenticación exitosa
  /// 
  /// Retorna:
  /// - `String` (licencia anterior) si hubo cambio de licencia → Llamador debe limpiar cache
  /// - `null` si es la misma licencia o primera vez → Cache se preserva
  /// 
  /// Ejemplo:
  /// ```dart
  /// final previousLicense = TenantContext.setTenant('POF0003', 'db_pof0003');
  /// if (previousLicense != null) {
  ///   print('Cambio de licencia de $previousLicense a POF0003');
  ///   await cache.clearTenant(previousLicense);
  /// }
  /// ```
  static String? setTenant(String licenseNumber, String database) {
    // Solo actualizar _previousLicenseNumber si _currentLicenseNumber no es null
    // (para no perder el valor guardado en clearTenant)
    if (_currentLicenseNumber != null) {
      _previousLicenseNumber = _currentLicenseNumber;
    }
    
    // Detectar cambio de licencia
    if (_previousLicenseNumber != null && _previousLicenseNumber != licenseNumber) {
      print('🔄 TENANT_CONTEXT: Cambio de licencia detectado: $_previousLicenseNumber → $licenseNumber');
      print('⚠️ TENANT_CONTEXT: Cache anterior debe ser limpiado');
      
      _currentLicenseNumber = licenseNumber;
      _currentDatabase = database;
      _tenantSetAt = DateTime.now();
      
      return _previousLicenseNumber;  // Retorna licencia anterior para limpiar
    }
    
    // Misma licencia o primera vez
    _currentLicenseNumber = licenseNumber;
    _currentDatabase = database;
    _tenantSetAt = DateTime.now();
    
    if (_previousLicenseNumber == null) {
      print('🏢 TENANT_CONTEXT: Tenant establecido (primera vez): $licenseNumber');
    } else {
      print('✅ TENANT_CONTEXT: Misma licencia ($licenseNumber) - Cache preservado');
    }
    
    return null;  // No hay cambio de licencia
  }
  
  /// Limpia el contexto actual
  /// 
  /// ⚠️ IMPORTANTE: Esto NO limpia el cache de datos, solo el contexto en memoria.
  /// El cache se preserva para el próximo login con la misma licencia.
  /// 
  /// Debe llamarse en logout.
  static void clearTenant() {
    // Guardar la licencia actual como "anterior" para detectar cambios en el próximo login
    _previousLicenseNumber = _currentLicenseNumber;
    
    _currentLicenseNumber = null;
    _currentDatabase = null;
    _tenantSetAt = null;
    
    if (_previousLicenseNumber != null) {
      print('🏢 TENANT_CONTEXT: Contexto limpiado (licencia anterior: $_previousLicenseNumber)');
      print('💾 TENANT_CONTEXT: Cache de datos preservado para próximo login');
    }
  }
  
  /// Obtiene el número de licencia actual
  static String? get currentLicenseNumber => _currentLicenseNumber;
  
  /// Obtiene la base de datos actual
  static String? get currentDatabase => _currentDatabase;
  
  /// Indica si hay un tenant activo
  static bool get hasActiveTenant => _currentLicenseNumber != null;
  
  /// Obtiene la fecha/hora en que se estableció el tenant actual
  static DateTime? get tenantSetAt => _tenantSetAt;
  
  /// Genera una clave con scope del tenant actual
  /// 
  /// Ejemplo:
  /// ```dart
  /// TenantContext.setTenant('POF0001', 'db');
  /// final key = TenantContext.scopeKey('Partner_records');
  /// // Resultado: "POF0001:Partner_records"
  /// ```
  /// 
  /// Lanza [TenantException] si no hay tenant activo.
  static String scopeKey(String key) {
    if (_currentLicenseNumber == null) {
      throw TenantException(
        'No hay tenant activo. Debe llamar setTenant() antes de usar scopeKey().'
      );
    }
    return '$_currentLicenseNumber:$key';
  }
  
  /// Verifica que hay un tenant activo, lanza excepción si no
  /// 
  /// Útil para validar que hay un tenant antes de operaciones críticas.
  /// 
  /// Ejemplo:
  /// ```dart
  /// void fetchData() {
  ///   TenantContext.requireTenant();
  ///   // ... código que requiere tenant ...
  /// }
  /// ```
  static void requireTenant() {
    if (_currentLicenseNumber == null) {
      throw TenantException(
        'Se requiere un tenant activo para esta operación. '
        'Debe autenticarse primero.'
      );
    }
  }
  
  /// [DEBUG] Obtiene información del estado actual
  /// 
  /// Útil para debugging y logs.
  static Map<String, dynamic> getDebugInfo() {
    return {
      'currentLicenseNumber': _currentLicenseNumber,
      'currentDatabase': _currentDatabase,
      'previousLicenseNumber': _previousLicenseNumber,
      'tenantSetAt': _tenantSetAt?.toIso8601String(),
      'hasActiveTenant': hasActiveTenant,
    };
  }
  
  /// [TEST ONLY] Reset completo del estado para tests
  /// 
  /// ⚠️ NO usar en producción, solo para tests unitarios.
  /// Limpia completamente el estado incluyendo _previousLicenseNumber.
  static void resetForTesting() {
    _currentLicenseNumber = null;
    _currentDatabase = null;
    _previousLicenseNumber = null;
    _tenantSetAt = null;
  }
}

