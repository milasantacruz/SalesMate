import 'package:equatable/equatable.dart';

/// Clase base para todos los errores de la aplicación
abstract class Failure extends Equatable {
  final String message;
  final int? code;
  
  const Failure({
    required this.message,
    this.code,
  });
  
  @override
  List<Object?> get props => [message, code];
}

/// Error del servidor Odoo
class ServerFailure extends Failure {
  const ServerFailure({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Error de cache local
class CacheFailure extends Failure {
  const CacheFailure({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Error de conectividad de red
class NetworkFailure extends Failure {
  const NetworkFailure({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Error de validación de datos
class ValidationFailure extends Failure {
  const ValidationFailure({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}

/// Error de autenticación
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required String message,
    int? code,
  }) : super(message: message, code: code);
}
