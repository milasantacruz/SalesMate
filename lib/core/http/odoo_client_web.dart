import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:http/browser_client.dart';

/// Implementación para plataformas web con soporte CORS completo
OdooClient createClient(String baseUrl) {
  print('🌐 PLATAFORMA WEB DETECTADA - Creando cliente con soporte CORS');
  print('🔧 URL: $baseUrl');
  print('🔧 Configurando BrowserClient con withCredentials = true');
  
  // Crear cliente HTTP específico para web con CORS
  final browserClient = BrowserClient()..withCredentials = true;
  
  // Crear cliente Odoo con configuración web
  final client = OdooClient(
    baseUrl,
    httpClient: browserClient,
    isWebPlatform: true,  // CRÍTICO: Indicar que es plataforma web
  );
  
  print('✅ Cliente web creado exitosamente con soporte CORS');
  print('🔍 Cliente tipo: ${client.runtimeType}');
  print('🔍 Cliente baseURL: ${client.baseURL}');
  print('🔍 Cliente httpClient tipo: ${client.httpClient.runtimeType}');
  print('🔍 Cliente isWebPlatform: ${client.isWebPlatform}');
  print('🔍 BrowserClient withCredentials: ${browserClient.withCredentials}');
  
  return client;
}