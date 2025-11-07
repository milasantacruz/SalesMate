import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';

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
  
  /// Agregar una cookie manualmente (útil para restaurar sesiones)
  void addCookie(String name, String value) {
    _cookies[name] = value;
    print('🍪 COOKIE_DEBUG: Cookie agregada manualmente: $name = $value');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 🔧 FIX: Corregir endpoint de /web/dataset/call_kw a /xmlrpc/2/object
    // El paquete odoo_rpc está usando incorrectamente el endpoint web
    if (request.url.path.contains('/web/dataset/call_kw')) {
      final originalUrl = request.url;
      final correctedPath = request.url.path.replaceAll('/web/dataset/call_kw', '/xmlrpc/2/object');
      final correctedUrl = Uri(
        scheme: originalUrl.scheme,
        host: originalUrl.host,
        port: originalUrl.port,
        path: correctedPath,
        query: originalUrl.query,
        fragment: originalUrl.fragment,
      );
      print('🔧 COOKIE_CLIENT: Corrigiendo endpoint de ${originalUrl.path} a ${correctedPath}');
      print('🔧 COOKIE_CLIENT: URL original: ${originalUrl}');
      print('🔧 COOKIE_CLIENT: URL corregida: ${correctedUrl}');
      
      // Crear un nuevo request con la URL corregida
      request = _createRequestWithNewUrl(request, correctedUrl);
    }
    
    // print('🚀 ANDROID: Iniciando request a ${request.url}');
    // print('📋 ANDROID: Método: ${request.method}');
    // print('📋 ANDROID: Headers: ${request.headers}');
    
    // 🔍 DEBUG FASE 1: Detectar peticiones a LicenseService
    if (request.url.toString().contains('app.proandsys.net')) {
      print('🔑 LICENSE_REQUEST: ⚠️ Petición a LicenseService detectada en CookieClient');
      print('🔑 LICENSE_REQUEST: URL completa: ${request.url}');
      print('🔑 LICENSE_REQUEST: Headers antes de procesamiento: ${request.headers}');
      print('🔑 LICENSE_REQUEST: Cookies actuales: $_cookies');
    }
    
    // Agregar cookies a la request
    if (_cookies.isNotEmpty) {
      final cookieHeader = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      request.headers['Cookie'] = cookieHeader;
      // 🚫 LOGS COMENTADOS: Generan demasiado ruido
      // print('🍪 ANDROID: Enviando cookies: $cookieHeader');
      // 🔍 DEBUG FASE 1: Verificar si las cookies interfieren con LicenseService
      if (request.url.toString().contains('app.proandsys.net')) {
        print('🔑 LICENSE_REQUEST: ⚠️ Cookies agregadas a petición de LicenseService');
        print('🔑 LICENSE_REQUEST: Headers finales después de cookies: ${request.headers}');
        print('🔑 LICENSE_REQUEST: Esto podría causar el error 401');
      }
    } else {
      // 🚫 LOG COMENTADO: Genera demasiado ruido
      // print('🍪 ANDROID: No hay cookies para enviar');
      
      // 🔍 DEBUG FASE 1: Confirmar que no hay cookies para LicenseService
      if (request.url.toString().contains('app.proandsys.net')) {
        print('🔑 LICENSE_REQUEST: ✅ No hay cookies para LicenseService (correcto)');
      }
    }

    try {
      // 🚫 LOGS COMENTADOS: Generan demasiado ruido
      // print('⏳ ANDROID: Enviando request a: ${request.url}');
      // print('⏳ ANDROID: Path: ${request.url.path}');
      // print('⏳ ANDROID: Es call_kw?: ${request.url.path.contains('call_kw')}');
      
      final response = await _inner.send(request);
      // 🚫 LOGS COMENTADOS: Generan demasiado ruido
      // print('✅ ANDROID: Response recibida - Status: ${response.statusCode}');
      // print('✅ ANDROID: Content-Type: ${response.headers['content-type']}');
      
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
      
      // 🔍 VERIFICAR SI ES HTML (solo para call_kw)
      if (request.url.path.contains('call_kw')) {
        // 🔍 DEBUG: Log detallado de la URL usada
        print('🔍 ANDROID: URL completa de call_kw: ${request.url}');
        print('🔍 ANDROID:   - Scheme: ${request.url.scheme}');
        print('🔍 ANDROID:   - Host: ${request.url.host}');
        print('🔍 ANDROID:   - Port: ${request.url.port}');
        print('🔍 ANDROID:   - Path: ${request.url.path}');
        print('🔍 ANDROID:   - Query: ${request.url.query}');
        print('🔍 ANDROID:   - Fragment: ${request.url.fragment}');
        print('🔍 ANDROID: Headers enviados:');
        request.headers.forEach((key, value) {
          if (key.toLowerCase() == 'cookie') {
            print('🔍 ANDROID:   $key: ${value.length > 50 ? value.substring(0, 50) + "..." : value}');
          } else {
            print('🔍 ANDROID:   $key: $value');
          }
        });
        
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          print('⚠️ ANDROID: RESPUESTA ES HTML, NO JSON!');
          print('⚠️ ANDROID: Status code: ${response.statusCode}');
          print('⚠️ ANDROID: Headers de respuesta completos:');
          response.headers.forEach((key, value) {
            print('⚠️ ANDROID:   $key: $value');
          });
          
          // Leer el body para ver qué HTML se está devolviendo
          final bodyStream = response.stream;
          final bodyBytes = await bodyStream.toList();
          final bodyStr = String.fromCharCodes(bodyBytes.expand((chunk) => chunk));
          print('⚠️ ANDROID: Body length: ${bodyStr.length} chars');
          print('⚠️ ANDROID: Body (primeros 300 chars): ${bodyStr.length > 300 ? bodyStr.substring(0, 300) : bodyStr}');
          
          // Recrear el stream para que el código original funcione
          return http.StreamedResponse(
            Stream.value(bodyBytes.expand((chunk) => chunk).toList()),
            response.statusCode,
            contentLength: bodyBytes.fold<int>(0, (sum, chunk) => sum + chunk.length),
            request: response.request,
            headers: response.headers,
            isRedirect: response.isRedirect,
            persistentConnection: response.persistentConnection,
            reasonPhrase: response.reasonPhrase,
          );
        }
        
        // 🔍 DEBUG: Capturar respuesta completa para call_kw (solo si contiene TypeError)
        if (request.url.path.contains('call_kw')) {
          try {
            // Leer el stream completo (lo consumimos)
            final bytes = await response.stream.toList();
            final allBytes = bytes.expand((x) => x).toList();
            final responseBody = utf8.decode(allBytes);
            
            // Si contiene TypeError, mostrar debug completo
            if (responseBody.contains('TypeError')) {
              try {
                final jsonResponse = jsonDecode(responseBody);
                if (jsonResponse is Map && jsonResponse.containsKey('error')) {
                  final error = jsonResponse['error'];
                  if (error is Map && error.containsKey('data')) {
                    final errorData = error['data'];
                    if (errorData is Map && errorData.containsKey('debug')) {
                      final debugStr = errorData['debug'].toString();
                      print('❌ ANDROID: ========== ERROR DEBUG (TypeError) ==========');
                      // Imprimir línea por línea para evitar truncamiento
                      final debugLines = debugStr.split('\n');
                      for (int i = 0; i < debugLines.length; i++) {
                        print('❌ ANDROID: ${debugLines[i]}');
                      }
                      print('❌ ANDROID: ===========================================');
                    }
                    if (errorData is Map && errorData.containsKey('name')) {
                      print('❌ ANDROID: Error name: ${errorData['name']}');
                    }
                    if (errorData is Map && errorData.containsKey('message')) {
                      print('❌ ANDROID: Error message: ${errorData['message']}');
                    }
                  }
                }
              } catch (parseError) {
                print('⚠️ ANDROID: Error parseando JSON de respuesta: $parseError');
              }
            }
            
            // SIEMPRE recrear el stream porque lo consumimos
            final newResponse = http.StreamedResponse(
              Stream.fromIterable([allBytes]),
              response.statusCode,
              contentLength: allBytes.length,
              request: response.request,
              headers: response.headers,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase,
            );
            
            // Extraer cookies antes de devolver
            final setCookie = newResponse.headers['set-cookie'];
            if (setCookie != null) {
              // 🚫 LOG COMENTADO: Genera demasiado ruido
              // print('🍪 ANDROID: Recibidas cookies: $setCookie');
              _parseCookies(setCookie);
            } else {
              // 🚫 LOG COMENTADO: Genera demasiado ruido
              // print('🍪 ANDROID: No se recibieron cookies en la response');
            }
            
            return newResponse;
          } catch (e) {
            print('⚠️ ANDROID: Error leyendo response body para debug: $e');
          }
        }
        
        // Extraer y guardar cookies de la response
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          // 🚫 LOG COMENTADO: Genera demasiado ruido
          // print('🍪 ANDROID: Recibidas cookies: $setCookie');
          _parseCookies(setCookie);
        } else {
          // 🚫 LOG COMENTADO: Genera demasiado ruido
          // print('🍪 ANDROID: No se recibieron cookies en la response');
        }
        
        return response; // Devolvemos la respuesta original sin tocarla
      } else {
        // Para otras requests, manejo normal
        // 🚫 LOGS COMENTADOS: Generan demasiado ruido
        // print('🔍 ANDROID: Request no es call_kw - Path: ${request.url.path}');
        // if (request is http.Request && request.body.isNotEmpty) {
        //   print('🔍 ANDROID: OTHER REQUEST PAYLOAD: ${request.body}');
        // }
        
        // Extraer y guardar cookies de la response
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          // 🚫 LOG COMENTADO: Genera demasiado ruido
          // print('🍪 ANDROID: Recibidas cookies: $setCookie');
          _parseCookies(setCookie);
        } else {
          // 🚫 LOG COMENTADO: Genera demasiado ruido
          // print('🍪 ANDROID: No se recibieron cookies en la response');
        }

        return response;
      }
    } catch (e) {
      print('❌ ANDROID: Error en request: $e');
      print('❌ ANDROID: Error tipo: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Crea un nuevo request con una URL diferente, preservando todas las propiedades
  http.BaseRequest _createRequestWithNewUrl(http.BaseRequest original, Uri newUrl) {
    if (original is http.Request) {
      return http.Request(original.method, newUrl)
        ..headers.addAll(original.headers)
        ..body = original.body
        ..encoding = original.encoding;
    } else if (original is http.StreamedRequest) {
      final newRequest = http.StreamedRequest(original.method, newUrl)
        ..headers.addAll(original.headers)
        ..contentLength = original.contentLength
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection;
      
      // Copiar el stream del body original
      original.finalize().listen(
        (data) => newRequest.sink.add(data),
        onError: (error) => newRequest.sink.addError(error),
        onDone: () => newRequest.sink.close(),
        cancelOnError: true,
      );
      
      return newRequest;
    } else {
      // Para otros tipos de request, intentar crear uno básico
      return http.Request(original.method, newUrl)
        ..headers.addAll(original.headers);
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





