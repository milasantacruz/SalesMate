/// Constantes de la aplicación para configuración de Odoo
class AppConstants {
  // Configuración del servidor Odoo - DATOS REALES DEL CLIENTE
  static const String _odooServerURL = 'https://odooconsultores-mtfood-staging-22669119.dev.odoo.com';
  static const String _proxyServerURL = 'http://localhost:8080';
  static const String odooDbName = 'odooconsultores-mtfood-staging-22669119';
  
  // URL dinámica basada en configuración CORS
  static String get odooServerURL => useCorsProxy ? _proxyServerURL : _odooServerURL;
  
  // CONFIGURACIÓN CORS - IMPORTANTE
  // El servidor puede tener restricciones CORS (Cross-Origin Resource Sharing)
  // Referrer Policy detectada: strict-origin-when-cross-origin
  // Esto puede bloquear requests desde Flutter app
  
  // Credenciales de prueba (para testing inicial)
  static const String testUsername = 'admin';
  static const String testPassword = '89554632';
  
  // Endpoints de Odoo disponibles
  static const String xmlrpcCommonEndpoint = '/xmlrpc/2/common';     // Login/Auth
  static const String xmlrpcObjectEndpoint = '/xmlrpc/object';       // CRUD Operations
  
  // URLs completas para referencia (dinámicas)
  static String get xmlrpcCommonURL => '$odooServerURL$xmlrpcCommonEndpoint';
  static String get xmlrpcObjectURL => '$odooServerURL$xmlrpcObjectEndpoint';
  //static String get webDatasetURL => '$odooServerURL$webDatasetEndpoint';
  
  // Configuración alternativa para CORS (si es necesario)
  static const bool useCorsProxy = true; // Usar proxy mejorado con soporte para cookies
  
  // Headers para manejar CORS y cookies
  static const Map<String, String> corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, Cookie, Set-Cookie',
    'Access-Control-Allow-Credentials': 'true',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'withCredentials': 'true',
  };
  
  // Nombre de la caja de cache
  static const String odooCacheBox = 'odoo_cache';
  
  // Claves de cache
  static const String cacheSessionKey = 'odooSession';
  static const String cachePartnersKey = 'cachePartnersKey';
  static const String cacheUsersKey = 'cacheUsersKey';
  
  // Configuración de red
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Configuración de cache
  static const int cacheExpirationDays = 7;
  static const int maxCacheSize = 1000;
  
  // Configuración de UI
  static const int itemsPerPage = 20;
  static const int maxRetryAttempts = 3;
  
  // Mensajes de error
  static const String networkErrorMessage = 'Error de conexión. Verifique su internet.';
  static const String serverErrorMessage = 'Error del servidor. Intente más tarde.';
  static const String cacheErrorMessage = 'Error de cache local.';
  static const String unknownErrorMessage = 'Error desconocido.';
  static const String corsErrorMessage = 'Error CORS. Contacte al administrador del servidor.';
}
