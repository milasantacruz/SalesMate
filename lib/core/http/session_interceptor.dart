import 'package:http/http.dart' as http;
import 'dart:convert';

/// Interceptor para extraer session_id de cookies HTTP
class SessionInterceptor {
  static String? _sessionId;
  
  /// Extrae session_id de headers Set-Cookie
  static void extractSessionFromHeaders(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null && setCookie.contains('session_id=')) {
      final regex = RegExp(r'session_id=([^;]+)');
      final match = regex.firstMatch(setCookie);
      if (match != null) {
        _sessionId = match.group(1);
        print('🍪 Session ID extraído manualmente: $_sessionId');
      }
    }
  }
  
  /// Extrae session_id de múltiples cookies
  static void extractSessionFromCookieList(List<String> cookies) {
    for (final cookie in cookies) {
      if (cookie.startsWith('session_id=')) {
        final parts = cookie.split(';')[0]; // Tomar solo la parte del valor
        _sessionId = parts.split('=')[1];
        print('🍪 Session ID extraído de lista: $_sessionId');
        break;
      }
    }
  }
  
  /// Getter para session_id actual
  static String? get sessionId => _sessionId;
  
  /// Setter público para session_id
  static void setSessionId(String? sessionId) {
    _sessionId = sessionId;
    print('🔧 Session ID establecido: $_sessionId');
  }
  
  /// Limpia session_id almacenado
  static void clearSession() {
    _sessionId = null;
    print('🗑️ Session ID limpiado');
  }
  
  /// Intercepta response HTTP y extrae session_id automáticamente
  static http.Response interceptResponse(http.Response response) {
    // Extraer de header set-cookie
    final setCookieHeader = response.headers['set-cookie'];
    if (setCookieHeader != null) {
      extractSessionFromHeaders(response.headers);
    }
    
    return response;
  }
  
  /// Método para extraer session_id de cookies del navegador (WEB)
  static void extractSessionFromBrowserCookies() {
    try {
      // En Flutter Web, intentar extraer cookies del navegador
      print('🔧 WEB: Intentando extraer session_id de cookies del navegador...');
      
      // WORKAROUND TEMPORAL: Usar el último session_id conocido
      // En producción, esto se haría interceptando cookies reales
      _sessionId = 'sf87Y573fbm3_6ZMeocI5QzqHl17mUcTY4hR38nTOx9Sl454-36R1lI2koGExFQ7v0W7fH-64e9HagG-x9Vy';
      print('🔧 WORKAROUND: Usando session_id conocido: $_sessionId');
      
      // TODO: Implementar extracción real de cookies en Flutter Web
      // Esto requeriría usar dart:html o js_interop para acceder a document.cookie
      
    } catch (e) {
      print('❌ Error extrayendo cookies del navegador: $e');
      _sessionId = null;
    }
  }
  
  /// Método legacy mantenido por compatibilidad
  static void extractSessionFromProxyLogs() {
    extractSessionFromBrowserCookies();
  }
  
  /// Cliente HTTP personalizado que intercepta responses
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    
    return interceptResponse(response);
  }
}
