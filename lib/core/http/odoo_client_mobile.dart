import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

/// Cliente HTTP personalizado que maneja cookies manualmente para Android
class CookieClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Map<String, String> _cookies = {};

    /// Exponer cookies de solo lectura (Map inmutable)
  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  /// Método auxiliar equivalente (por compatibilidad con quien llame getCookies)
  Map<String, String> getCookies() => Map.unmodifiable(_cookies);

  /// 🔍 DEBUG FASE 1: Limpiar todas las cookies (para debugging)
  void clearCookies() {
    print('🧹 COOKIE_DEBUG: Limpiando todas las cookies del CookieClient');
    print('🧹 COOKIE_DEBUG: Cookies antes de limpiar: $_cookies');
    _cookies.clear();
    print('🧹 COOKIE_DEBUG: Cookies después de limpiar: $_cookies');
  }

  /// 🔍 DEBUG FASE 1: Verificar estado de cookies
  void debugCookies() {
    print('🔍 COOKIE_DEBUG: Estado actual de cookies:');
    print('🔍 COOKIE_DEBUG: Número de cookies: ${_cookies.length}');
    if (_cookies.isNotEmpty) {
      print('🔍 COOKIE_DEBUG: Cookies detalladas:');
      _cookies.forEach((key, value) {
        print('🔍 COOKIE_DEBUG:   - $key: $value');
      });
    } else {
      print('🔍 COOKIE_DEBUG: ✅ No hay cookies almacenadas');
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('🚀 ANDROID: Iniciando request a ${request.url}');
    print('📋 ANDROID: Método: ${request.method}');
    print('📋 ANDROID: Headers: ${request.headers}');
    
    // 🔍 DEBUG FASE 1: Detectar peticiones a LicenseService
    if (request.url.toString().contains('app.proandsys.net')) {
      print('🔑 LICENSE_REQUEST: ⚠️ Petición a LicenseService detectada en CookieClient');
      print('🔑 LICENSE_REQUEST: URL completa: ${request.url}');
      print('🔑 LICENSE_REQUEST: Headers antes de procesamiento: ${request.headers}');
      print('🔑 LICENSE_REQUEST: Cookies actuales: $_cookies');
    }
    
    // 🔥 CRÍTICO: Interceptar el body del request para análisis
    if (request is http.Request && request.body.isNotEmpty) {
      print('📦 ANDROID: Request body: ${request.body}');
    }
    
    // Agregar cookies a la request
    if (_cookies.isNotEmpty) {
      final cookieHeader = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      request.headers['Cookie'] = cookieHeader;
      print('🍪 ANDROID: Enviando cookies: $cookieHeader');
      
      // 🔍 DEBUG FASE 1: Verificar si las cookies interfieren con LicenseService
      if (request.url.toString().contains('app.proandsys.net')) {
        print('🔑 LICENSE_REQUEST: ⚠️ Cookies agregadas a petición de LicenseService');
        print('🔑 LICENSE_REQUEST: Headers finales después de cookies: ${request.headers}');
        print('🔑 LICENSE_REQUEST: Esto podría causar el error 401');
      }
    } else {
      print('🍪 ANDROID: No hay cookies para enviar');
      
      // 🔍 DEBUG FASE 1: Confirmar que no hay cookies para LicenseService
      if (request.url.toString().contains('app.proandsys.net')) {
        print('🔑 LICENSE_REQUEST: ✅ No hay cookies para LicenseService (correcto)');
      }
    }

    try {
      print('⏳ ANDROID: Enviando request...');
      final response = await _inner.send(request);
      print('✅ ANDROID: Response recibida - Status: ${response.statusCode}');
      print('📋 ANDROID: Response headers: ${response.headers}');
      
      // 🔍 DEBUG FASE 1: Logs específicos para LicenseService
      if (request.url.toString().contains('app.proandsys.net')) {
        print('🔑 LICENSE_RESPONSE: Status code: ${response.statusCode}');
        print('🔑 LICENSE_RESPONSE: Headers de respuesta: ${response.headers}');
        if (response.statusCode == 401) {
          print('🔑 LICENSE_RESPONSE: ❌ ERROR 401 CONFIRMADO - Cookies interfieren');
        } else {
          print('🔑 LICENSE_RESPONSE: ✅ Petición exitosa');
        }
      }
      
      // Log especial para llamadas a call_kw
      if (request.url.path.contains('call_kw')) {
        print('🎯 ANDROID: Esta es una llamada call_kw');
        print('🎯 ANDROID: URL completa: ${request.url}');
        
        // 🔥 CRÍTICO: Ver el payload exacto de call_kw
        if (request is http.Request && request.body.isNotEmpty) {
          print('🎯 ANDROID: PAYLOAD CALL_KW: ${request.body}');
          print('🎯 ANDROID: PAYLOAD LENGTH: ${request.body.length} chars');
        }
        
        // COMENTADO: El logging del body ya no es necesario y causa errores con respuestas grandes.
        /*
        // Leer el cuerpo de la response para debug
        final responseBody = await response.stream.bytesToString();
        print('🎯 ANDROID: Response body: $responseBody');
        
        // Recrear el stream para que la response funcione normalmente
        final newResponse = http.StreamedResponse(
          Stream.fromIterable([responseBody.codeUnits]),
          response.statusCode,
          contentLength: responseBody.length,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
        */
        
        // Extraer y guardar cookies de la response
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          print('🍪 ANDROID: Recibidas cookies: $setCookie');
          _parseCookies(setCookie);
        } else {
          print('🍪 ANDROID: No se recibieron cookies en la response');
        }
        
        return response; // Devolvemos la respuesta original sin tocarla
      } else {
        // Para otras requests, manejo normal
        print('🔍 ANDROID: Request no es call_kw - Path: ${request.url.path}');
        if (request is http.Request && request.body.isNotEmpty) {
          print('🔍 ANDROID: OTHER REQUEST PAYLOAD: ${request.body}');
        }
        
        // Extraer y guardar cookies de la response
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          print('🍪 ANDROID: Recibidas cookies: $setCookie');
          _parseCookies(setCookie);
        } else {
          print('🍪 ANDROID: No se recibieron cookies en la response');
        }

        return response;
      }
    } catch (e) {
      print('❌ ANDROID: Error en request: $e');
      print('❌ ANDROID: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  void _parseCookies(String setCookieHeader) {
    final cookies = setCookieHeader.split(',');
    for (final cookie in cookies) {
      final parts = cookie.trim().split(';')[0].split('=');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();
        _cookies[name] = value;
        print('🍪 ANDROID: Cookie guardada: $name = $value');
      }
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Implementación para plataformas móviles (Android/iOS)
OdooClient createClient(String baseUrl) {
  print('📱 PLATAFORMA MÓVIL DETECTADA - Creando cliente con manejo de cookies');
  print('🔧 URL: $baseUrl');
  print('📋 Platform: ${Platform.operatingSystem}');
  print('📋 Platform version: ${Platform.operatingSystemVersion}');
  
  // Crear cliente con manejo manual de cookies para Android
  final cookieClient = CookieClient();
  final client = OdooClient(baseUrl, httpClient: cookieClient);
  
  print('✅ Cliente móvil creado exitosamente con soporte para cookies');
  print('🔍 Cliente tipo: ${client.runtimeType}');
  print('🔍 Cliente baseURL: ${client.baseURL}');
  print('🔍 Cliente httpClient tipo: ${client.httpClient.runtimeType}');
  
  return client;
}





