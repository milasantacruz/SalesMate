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

  const LicenseInfo({
    required this.success,
    required this.isActive,
    required this.licenseNumber,
    this.serverUrl,
    this.database,
    this.username,
    this.password,
  });

  factory LicenseInfo.fromWebhook(Map<String, dynamic> json) {
    print('🔍 LICENSE_INFO: Parseando respuesta del webhook...');
    
    final license = json['license'] as Map<String, dynamic>?;
    final connections = (json['connections'] as List?) ?? const [];
    String? serverUrl;
    String? database;
    String? username;
    String? password;

    print('🔍 LICENSE_INFO: Número de conexiones: ${connections.length}');
    
    if (connections.isNotEmpty) {
      final conn = connections.first as Map<String, dynamic>;
      final fieldValues = (conn['fieldValues'] as Map<String, dynamic>?) ?? {};
      
      print('🔍 LICENSE_INFO: fieldValues completos: $fieldValues');
      
      serverUrl = fieldValues['host'] as String?;
      database = fieldValues['nombre_bd'] as String?;
      username = fieldValues['usuario'] as String?;
      password = fieldValues['contrasena'] as String?;
      
      print('🔍 LICENSE_INFO: Valores extraídos:');
      print('   - host: $serverUrl');
      print('   - nombre_bd: $database');
      print('   - usuario: $username');
      print('   - contrasena: ${password?.substring(0, 2)}*** (${password?.length} chars)');
    }

    final info = LicenseInfo(
      success: (json['success'] as bool?) ?? false,
      isActive: (license?['isActive'] as bool?) ?? false,
      licenseNumber: (license?['licenseNumber'] as String?) ?? '',
      serverUrl: serverUrl,
      database: database,
      username: username,
      password: password,
    );
    
    print('✅ LICENSE_INFO: LicenseInfo creado exitosamente');
    return info;
  }
}

class LicenseService {
  final String baseUrl;
  final String apiKey;
  
  const LicenseService({
    this.baseUrl = 'http://app.proandsys.net/api/webhook/license',
    this.apiKey = 'lw_prod_8f4a2c1d9e6b3a5f7e2c8d4a1b6f9e3c',
  });

  Future<LicenseInfo> fetchLicense(String licenseNumber) async {
    print('🔑 LICENSE_SERVICE: Iniciando validación de licencia: $licenseNumber');
    
    final url = Uri.parse('$baseUrl/$licenseNumber');
    print('🌐 LICENSE_SERVICE: URL completa: $url');
    print('📤 LICENSE_SERVICE: Headers de petición:');
    print('   - Accept: application/json');
    print('   - Authorization: Bearer $apiKey');
    
    try {
      final resp = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      
      print('📥 LICENSE_SERVICE: Status code recibido: ${resp.statusCode}');
      print('📥 LICENSE_SERVICE: Headers de respuesta: ${resp.headers}');
      print('📥 LICENSE_SERVICE: Body de respuesta: ${resp.body}');

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


