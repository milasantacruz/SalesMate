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
  final int? tarifaId; // ID de la tarifa/pricelist por defecto
  final int? empresaId; // ID de la empresa/company por defecto

  const LicenseInfo({
    required this.success,
    required this.isActive,
    required this.licenseNumber,
    this.serverUrl,
    this.database,
    this.username,
    this.password,
    this.tipoven,
    this.tarifaId,
    this.empresaId,
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
    int? tarifaId;
    int? empresaId;

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
      
      // Extraer tarifa_id (puede venir como String o int)
      print('💰 LICENSE_INFO: Buscando tarifa_id en fieldValues...');
      print('💰 LICENSE_INFO: fieldValues.keys: ${fieldValues.keys.toList()}');
      
      final tarifaIdValue = fieldValues['tarifa_id'];
      print('💰 LICENSE_INFO: tarifa_id raw value: $tarifaIdValue');
      print('💰 LICENSE_INFO: tarifa_id tipo: ${tarifaIdValue?.runtimeType}');
      
      if (tarifaIdValue != null) {
        if (tarifaIdValue is int) {
          tarifaId = tarifaIdValue;
          print('✅ LICENSE_INFO: tarifa_id parseado como int: $tarifaId');
        } else if (tarifaIdValue is String) {
          tarifaId = int.tryParse(tarifaIdValue);
          if (tarifaId != null) {
            print('✅ LICENSE_INFO: tarifa_id parseado desde String: $tarifaId');
          } else {
            print('⚠️ LICENSE_INFO: No se pudo parsear tarifa_id desde String: "$tarifaIdValue"');
          }
        } else if (tarifaIdValue is num) {
          tarifaId = tarifaIdValue.toInt();
          print('✅ LICENSE_INFO: tarifa_id parseado desde num: $tarifaId');
        } else {
          print('⚠️ LICENSE_INFO: tarifa_id tiene tipo inesperado: ${tarifaIdValue.runtimeType}');
        }
      } else {
      print('⚠️ LICENSE_INFO: ⚠️⚠️⚠️ ADVERTENCIA: tarifa_id NO está presente en fieldValues');
      print('⚠️ LICENSE_INFO: El webhook no incluye tarifa_id - Verificar en el backend');
      }
      
      // Extraer empresa_id (puede venir como String o int)
      print('🏢 LICENSE_INFO: Buscando empresa_id en fieldValues...');
      
      final empresaIdValue = fieldValues['empresa_id'];
      print('🏢 LICENSE_INFO: empresa_id raw value: $empresaIdValue');
      print('🏢 LICENSE_INFO: empresa_id tipo: ${empresaIdValue?.runtimeType}');
      
      if (empresaIdValue != null) {
        if (empresaIdValue is int) {
          empresaId = empresaIdValue;
          print('✅ LICENSE_INFO: empresa_id parseado como int: $empresaId');
        } else if (empresaIdValue is String) {
          empresaId = int.tryParse(empresaIdValue);
          if (empresaId != null) {
            print('✅ LICENSE_INFO: empresa_id parseado desde String: $empresaId');
          } else {
            print('⚠️ LICENSE_INFO: No se pudo parsear empresa_id desde String: "$empresaIdValue"');
          }
        } else if (empresaIdValue is num) {
          empresaId = empresaIdValue.toInt();
          print('✅ LICENSE_INFO: empresa_id parseado desde num: $empresaId');
        } else {
          print('⚠️ LICENSE_INFO: empresa_id tiene tipo inesperado: ${empresaIdValue.runtimeType}');
        }
      } else {
        print('⚠️ LICENSE_INFO: ⚠️⚠️⚠️ ADVERTENCIA: empresa_id NO está presente en fieldValues');
        print('⚠️ LICENSE_INFO: El webhook no incluye empresa_id - Verificar en el backend');
      }
      
      print('🔍 LICENSE_INFO: Valores extraídos:');
      print('   - host: $serverUrl');
      print('   - nombre_bd: $database');
      print('   - usuario: $username');
      print('   - contrasena: ${password?.substring(0, 2)}*** (${password?.length} chars)');
      print('   - tipoven: $tipoven');
      print('   - tarifa_id: $tarifaId ${tarifaId == null ? "⚠️ (NULL)" : "✅"}');
      print('   - empresa_id: $empresaId ${empresaId == null ? "⚠️ (NULL)" : "✅"}');
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
      tarifaId: tarifaId,
      empresaId: empresaId,
    );
    
    print('✅ LICENSE_INFO: LicenseInfo creado - tipoven: $tipoven, empresaId: $empresaId');
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
    this.baseUrl = 'https://app.proandsys.net/api/webhook/license',
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
    print('   - Authorization: Bearer $apiKey');
    print('   - User-Agent: PostmanRuntime/7.32.3');
    print('   - Accept: */*');
    print('   - Cache-Control: no-cache');
    
    // 🔍 DEBUG FASE 1: Verificar que el API key no esté corrupto
    if (apiKey != 'lw_prod_8f4a2c1d9e6b3a5f7e2c8d4a1b6f9e3c') {
      print('🔍 DEBUG FASE 1: ⚠️ API Key modificado: $apiKey');
    } else {
      print('🔍 DEBUG FASE 1: ✅ API Key correcto');
    }
    
    try {
      final client = http.Client();
      final resp = await client.get(url, headers: {
        'Authorization': 'Bearer $apiKey',
        //'User-Agent': 'PostmanRuntime/7.32.3',
        'Accept': '*/*',
        //'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 30));
      
      client.close();
      
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


