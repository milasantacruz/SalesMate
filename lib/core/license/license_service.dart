import 'dart:convert';
import 'package:http/http.dart' as http;

class LicenseInfo {
  final bool success;
  final bool isActive;
  final String licenseNumber;
  final String? serverUrl;
  final String? database;
  final String? username;
  final String? password;
  final String? tipoven; // "U" = Usuario Admin (sin PIN), "E" = Empleado (con PIN)

  const LicenseInfo({
    required this.success,
    required this.isActive,
    required this.licenseNumber,
    this.serverUrl,
    this.database,
    this.username,
    this.password,
    this.tipoven,
  });

  factory LicenseInfo.fromWebhook(Map<String, dynamic> json) {
    print('🔍 LICENSE_INFO: Parseando respuesta del webhook...');
    
    final license = json['license'] as Map<String, dynamic>?;
    final connections = (json['connections'] as List?) ?? const [];
    String? serverUrl;
    String? database;
    String? username;
    String? password;
    String? tipoven;

    print('🔍 LICENSE_INFO: Número de conexiones: ${connections.length}');
    
    if (connections.isNotEmpty) {
      final conn = connections.first as Map<String, dynamic>;
      final fieldValues = (conn['fieldValues'] as Map<String, dynamic>?) ?? {};
      
      print('🔍 LICENSE_INFO: fieldValues completos: $fieldValues');
      
      serverUrl = _sanitizeBaseUrl(fieldValues['host'] as String?);
      database = fieldValues['nombre_bd'] as String?;
      username = fieldValues['usuario'] as String?;
      password = fieldValues['contrasena'] as String?;
      tipoven = fieldValues['tipoven'] as String?;
      
      print('🔍 LICENSE_INFO: Valores extraídos:');
      print('   - host: $serverUrl');
      print('   - nombre_bd: $database');
      print('   - usuario: $username');
      print('   - contrasena: ${password?.substring(0, 2)}*** (${password?.length} chars)');
      print('   - tipoven: $tipoven');
    }

    final info = LicenseInfo(
      success: (json['success'] as bool?) ?? false,
      isActive: (license?['isActive'] as bool?) ?? false,
      licenseNumber: (license?['licenseNumber'] as String?) ?? '',
      serverUrl: serverUrl,
      database: database,
      username: username,
      password: password,
      tipoven: tipoven,
    );
    
    print('✅ LICENSE_INFO: LicenseInfo creado - tipoven: $tipoven');
    return info;
  }
}

String? _sanitizeBaseUrl(String? url) {
  if (url == null) return null;
  try {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    final parsed = Uri.parse(u);
    final clean = Uri(scheme: parsed.scheme, host: parsed.host).toString();
    return clean.endsWith('/') ? clean.substring(0, clean.length - 1) : clean;
  } catch (_) {
    return url;
  }
}

class LicenseService {
  final String baseUrl;
  final String apiKey;
  
  // 🔍 DEBUG FASE 1: Contador para distinguir primera carga vs post-logout
  static int _requestCount = 0;
  
  const LicenseService({
    this.baseUrl = 'http://app.proandsys.net/api/webhook/license',
    this.apiKey = 'lw_prod_8f4a2c1d9e6b3a5f7e2c8d4a1b6f9e3c',
  });

  Future<LicenseInfo> fetchLicense(String licenseNumber) async {
    _requestCount++;
    print('🔑 LICENSE_SERVICE: Iniciando validación de licencia: $licenseNumber');
    
    // 🔍 DEBUG FASE 1: Verificar si es primera carga o post-logout
    print('🔍 DEBUG FASE 1: Verificando contexto de la petición...');
    print('🔍 DEBUG FASE 1: Request #$_requestCount');
    if (_requestCount == 1) {
      print('🔍 DEBUG FASE 1: 🆕 PRIMERA CARGA - Sin cookies residuales');
    } else {
      print('🔍 DEBUG FASE 1: 🔄 POST-LOGOUT - Posibles cookies residuales');
    }
    print('🔍 DEBUG FASE 1: API Key: $apiKey');
    print('🔍 DEBUG FASE 1: Base URL: $baseUrl');
    
    final url = Uri.parse('$baseUrl/$licenseNumber');
    print('🌐 LICENSE_SERVICE: URL completa: $url');
    print('📤 LICENSE_SERVICE: Headers de petición:');
    print('   - Accept: application/json');
    print('   - Authorization: Bearer $apiKey');
    
    // 🔍 DEBUG FASE 1: Verificar que el API key no esté corrupto
    if (apiKey != 'lw_prod_8f4a2c1d9e6b3a5f7e2c8d4a1b6f9e3c') {
      print('🔍 DEBUG FASE 1: ⚠️ API Key modificado: $apiKey');
    } else {
      print('🔍 DEBUG FASE 1: ✅ API Key correcto');
    }
    
    try {
      final resp = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      
      print('📥 LICENSE_SERVICE: Status code recibido: ${resp.statusCode}');
      print('📥 LICENSE_SERVICE: Headers de respuesta: ${resp.headers}');
      print('📥 LICENSE_SERVICE: Body de respuesta: ${resp.body}');

      // 🔍 DEBUG FASE 1: Análisis detallado del error 401
      if (resp.statusCode == 401) {
        print('🔍 DEBUG FASE 1: ❌ ERROR 401 DETECTADO');
        print('🔍 DEBUG FASE 1: Request #$_requestCount');
        print('🔍 DEBUG FASE 1: Headers enviados: Accept=application/json, Authorization=Bearer $apiKey');
        print('🔍 DEBUG FASE 1: Headers de respuesta: ${resp.headers}');
        print('🔍 DEBUG FASE 1: Body de error: ${resp.body}');
        if (_requestCount == 1) {
          print('🔍 DEBUG FASE 1: ⚠️ ERROR EN PRIMERA CARGA - Problema no relacionado con cookies');
        } else {
          print('🔍 DEBUG FASE 1: ⚠️ ERROR EN POST-LOGOUT - Posible causa: Cookies del CookieClient interfieren');
        }
      } else {
        print('🔍 DEBUG FASE 1: ✅ Request #$_requestCount exitoso');
      }

      if (resp.statusCode != 200) {
        print('❌ LICENSE_SERVICE: Error HTTP ${resp.statusCode}');
        print('❌ LICENSE_SERVICE: Respuesta completa: ${resp.body}');
        throw Exception('License webhook failed (${resp.statusCode}): ${resp.body}');
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      print('✅ LICENSE_SERVICE: JSON parseado exitosamente');
      print('📋 LICENSE_SERVICE: Datos recibidos: $data');
      
      final licenseInfo = LicenseInfo.fromWebhook(data);
      print('✅ LICENSE_SERVICE: LicenseInfo creado - isActive: ${licenseInfo.isActive}');
      
      return licenseInfo;
    } catch (e, stackTrace) {
      print('❌ LICENSE_SERVICE: Excepción capturada: $e');
      print('❌ LICENSE_SERVICE: Stack trace: $stackTrace');
      rethrow;
    }
  }
}


