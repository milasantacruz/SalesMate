import 'package:equatable/equatable.dart';

/// Estados base para el sistema de autenticación
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object> get props => [];
}

/// Estado inicial
class AuthInitial extends AuthState {}

/// Estado de carga durante operaciones de autenticación
class AuthLoading extends AuthState {}

/// Estado cuando el usuario está autenticado
class AuthAuthenticated extends AuthState {
  final String username;
  final String userId;
  final String database;
  
  const AuthAuthenticated({
    required this.username,
    required this.userId,
    required this.database,
  });
  
  @override
  List<Object> get props => [username, userId, database];
}

/// Estado cuando el usuario no está autenticado
class AuthUnauthenticated extends AuthState {}

/// Estado de error en autenticación
class AuthError extends AuthState {
  final String message;
  final String? details;
  
  const AuthError(this.message, {this.details});
  
  @override
  List<Object> get props => [message, details ?? ''];
}

/// Estado cuando la licencia fue validada y se configuró la conexión
class AuthLicenseValidated extends AuthState {
  final String licenseNumber;
  final String? serverUrl;
  final String? database;
  final String? tipoven; // "U" = Usuario Admin (sin PIN), "E" = Empleado (con PIN)

  const AuthLicenseValidated({
    required this.licenseNumber,
    this.serverUrl,
    this.database,
    this.tipoven,
  });

  @override
  List<Object> get props => [licenseNumber, serverUrl ?? '', database ?? '', tipoven ?? ''];
}