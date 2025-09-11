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
