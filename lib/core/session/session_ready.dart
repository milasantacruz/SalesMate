import 'dart:async';

/// Coordinador simple para bloquear llamadas a Odoo mientras
/// se realiza una re-autenticación silenciosa.
class SessionReadyCoordinator {
  static Completer<void>? _reauthCompleter;

  /// Llamar justo antes de iniciar la re-autenticación silenciosa
  static void startReauthentication() {
    // Solo crear si no existe; evita reinicios múltiples
    _reauthCompleter ??= Completer<void>();
  }

  /// Llamar cuando la re-autenticación silenciosa haya finalizado (éxito o error)
  static void completeReauthentication() {
    if (_reauthCompleter != null && !_reauthCompleter!.isCompleted) {
      _reauthCompleter!.complete();
    }
    _reauthCompleter = null;
  }

  /// Espera (si corresponde) a que termine la re-autenticación silenciosa
  static Future<void> waitIfReauthenticationInProgress() async {
    final completer = _reauthCompleter;
    if (completer != null) {
      await completer.future;
    }
  }
}


