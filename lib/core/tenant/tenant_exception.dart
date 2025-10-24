/// Excepción personalizada para errores relacionados con tenants
/// 
/// Se lanza cuando se intenta realizar una operación que requiere
/// un tenant activo pero no hay ninguno establecido.
class TenantException implements Exception {
  final String message;
  
  TenantException(this.message);
  
  @override
  String toString() => 'TenantException: $message';
}

