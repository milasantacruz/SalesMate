import 'package:equatable/equatable.dart';

/// Eventos base para el sistema de autenticación
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

/// Evento para verificar el estado de autenticación actual
class CheckAuthStatus extends AuthEvent {}

/// Evento para realizar login con credenciales
class LoginRequested extends AuthEvent {
  final String username;
  final String password;
  final String? serverUrl;
  final String? database;
  
  const LoginRequested({
    required this.username,
    required this.password,
    this.serverUrl,
    this.database,
  });
  
  @override
  List<Object> get props => [username, password, serverUrl ?? '', database ?? ''];
}

/// Evento para realizar logout
class LogoutRequested extends AuthEvent {}

/// Evento para continuar después de mostrar la pantalla de recuperación de key
class RecoveryKeyAcknowledged extends AuthEvent {
  final String licenseNumber;
  final String? serverUrl;
  final String? database;
  final String? tipoven;
  final String? username;
  final String? password;
  final int? tarifaId;
  final int? empresaId;

  const RecoveryKeyAcknowledged({
    required this.licenseNumber,
    this.serverUrl,
    this.database,
    this.tipoven,
    this.username,
    this.password,
    this.tarifaId,
    this.empresaId,
  });

  @override
  List<Object> get props => [
    licenseNumber,
    serverUrl ?? '',
    database ?? '',
    tipoven ?? '',
    username ?? '',
    password ?? '',
    tarifaId ?? 0,
    empresaId ?? 0,
  ];
}

/// Evento cuando la key de recuperación fue validada exitosamente
class KeyValidationSucceeded extends AuthEvent {
  final String licenseNumber;
  final String uuid;

  const KeyValidationSucceeded({
    required this.licenseNumber,
    required this.uuid,
  });

  @override
  List<Object> get props => [licenseNumber, uuid];
}

/// Evento cuando la key de recuperación falló la validación
class KeyValidationFailed extends AuthEvent {
  final String licenseNumber;
  final String enteredKey;

  const KeyValidationFailed({
    required this.licenseNumber,
    required this.enteredKey,
  });

  @override
  List<Object> get props => [licenseNumber, enteredKey];
}