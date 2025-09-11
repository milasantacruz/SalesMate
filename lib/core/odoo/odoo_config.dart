import '../constants/app_constants.dart';

/// Configuración específica para Odoo
class OdooConfig {
  /// URL del servidor Odoo
  static const String serverURL = AppConstants.odooServerURL;
  
  /// Nombre de la base de datos
  static const String databaseName = AppConstants.odooDbName;
  
  /// Clave para almacenar la sesión en cache
  static const String sessionCacheKey = AppConstants.cacheSessionKey;
  
  /// Timeout para conexiones (en milisegundos)
  static const int connectionTimeout = AppConstants.connectionTimeout;
  
  /// Timeout para recepción de datos (en milisegundos)
  static const int receiveTimeout = AppConstants.receiveTimeout;
  
  /// Días de expiración del cache
  static const int cacheExpirationDays = AppConstants.cacheExpirationDays;
  
  /// Tamaño máximo del cache
  static const int maxCacheSize = AppConstants.maxCacheSize;
  
  /// Elementos por página en listas
  static const int itemsPerPage = AppConstants.itemsPerPage;
  
  /// Intentos máximos de reintento
  static const int maxRetryAttempts = AppConstants.maxRetryAttempts;
  
  /// Configuración de modelos Odoo
  static const Map<String, List<String>> modelFields = {
    'res.partner': ['id', 'name', 'email', 'phone', 'is_company', 'customer_rank', 'supplier_rank'],
    'res.users': ['id', 'name', 'login', 'email', 'active'],
    'sale.order': ['id', 'name', 'partner_id', 'date_order', 'amount_total', 'state'],
    'sale.order.line': ['id', 'order_id', 'product_id', 'name', 'product_uom_qty', 'price_unit'],
  };
  
  /// Configuración de filtros por defecto
  static const Map<String, List<dynamic>> defaultFilters = {
    'res.partner': [
      ['active', '=', true],
    ],
    'res.users': [
      ['active', '=', true],
    ],
    'sale.order': [
      ['state', 'in', ['draft', 'sale', 'done']],
    ],
  };
}
