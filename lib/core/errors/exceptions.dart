/// Excepciones de la aplicación
class AppException implements Exception {
  final String message;
  final int? code;
  
  const AppException({
    required this.message,
    this.code,
  });
  
  @override
  String toString() => 'AppException: $message (Code: $code)';
}

/// Excepción del servidor Odoo
class ServerException extends AppException {
  const ServerException({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Excepción de cache local
class CacheException extends AppException {
  const CacheException({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Excepción de conectividad de red
class NetworkException extends AppException {
  const NetworkException({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Excepción de validación de datos
class ValidationException extends AppException {
  const ValidationException({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Excepción de autenticación
class AuthenticationException extends AppException {
  const AuthenticationException({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}
