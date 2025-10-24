/// Configuración de almacenamiento y límites para Single-Tenant
/// 
/// Define límites de almacenamiento, filtros temporales y políticas
/// de auto-limpieza para el sistema de cache offline.
/// 
/// ⚠️ v2.0: Configuración simplificada para Single-Tenant
/// (solo una licencia cacheada a la vez)
class TenantStorageConfig {
  // ==========================================
  // LÍMITES DE ALMACENAMIENTO
  // ==========================================
  
  /// Tamaño máximo de cache total (MB)
  /// 
  /// ⚠️ v2.0: Solo UNA licencia cacheada a la vez
  /// Con filtrado inteligente (6 meses), una licencia típica usa 25-40 MB.
  /// Este límite de 100 MB proporciona margen de seguridad (2.5x).
  static const int maxTotalSizeMB = 100;
  
  // ==========================================
  // FILTROS TEMPORALES (para reducir tamaño)
  // ==========================================
  
  /// Meses hacia atrás para Sale Orders
  /// 
  /// Solo se cachean Sale Orders de los últimos 6 meses.
  /// Esto reduce el tamaño de ~200 MB a ~15 MB.
  static const int saleOrdersMonthsBack = 6;
  
  /// Habilitar filtrado temporal
  /// 
  /// Si es false, se cachean TODOS los registros (no recomendado).
  static const bool enableTemporalFiltering = true;
  
  // ==========================================
  // LÍMITES POR ENTIDAD
  // ==========================================
  
  /// Máximo de productos por tenant
  /// 
  /// Si un tenant tiene más productos, se deben paginar o filtrar.
  static const int maxProductsPerTenant = 10000;
  
  /// Máximo de partners por tenant
  static const int maxPartnersPerTenant = 5000;
  
  /// Máximo de empleados por tenant
  static const int maxEmployeesPerTenant = 500;
  
  /// Máximo de shipping addresses por tenant
  static const int maxShippingAddressesPerTenant = 5000;
  
  // ==========================================
  // AUTO-LIMPIEZA (v2.0 - Single-Tenant)
  // ==========================================
  
  /// Limpieza automática al cambiar de licencia
  /// 
  /// Si true, al detectar cambio de licencia se limpia el cache anterior
  /// automáticamente en el flujo de login.
  static const bool autoCleanupOnLicenseChange = true;
  
  // ==========================================
  // MÉTRICAS Y MONITOREO
  // ==========================================
  
  /// Habilitar logs detallados de storage
  static const bool enableStorageLogs = true;
  
  /// Habilitar alertas de límite de almacenamiento
  /// 
  /// Si el cache supera el 80% del límite, se emite una alerta.
  static const bool enableStorageAlerts = true;
  
  /// Porcentaje de alerta (0.0 - 1.0)
  /// 
  /// Si el cache supera este porcentaje del límite, se emite una alerta.
  static const double storageAlertThreshold = 0.8;  // 80%
  
  // ==========================================
  // MÉTODOS HELPER
  // ==========================================
  
  /// Obtiene el dominio de fecha para Sale Orders
  /// 
  /// Retorna un domain list para filtrar Sale Orders por fecha (últimos 6 meses).
  /// 
  /// Ejemplo:
  /// ```dart
  /// final temporalDomain = TenantStorageConfig.getSaleOrdersDateDomain();
  /// // Resultado: [['date_order', '>=', '2024-07-17 00:00:00']]
  /// 
  /// // Usar en domain de Odoo con spread operator:
  /// final domain = [
  ///   ['state', '!=', 'cancel'],
  ///   ...temporalDomain,
  /// ];
  /// ```
  static List<List<dynamic>> getSaleOrdersDateDomain() {
    if (!enableTemporalFiltering) {
      return [];  // Sin filtro (todas las fechas)
    }
    
    final now = DateTime.now();
    final dateLimit = DateTime(
      now.year,
      now.month - saleOrdersMonthsBack,
      now.day,
    );
    
    final formattedDate = dateLimit.toIso8601String().split('T')[0] + ' 00:00:00';
    return [['date_order', '>=', formattedDate]];
  }
  
  /// Indica si se debe aplicar filtro temporal para un modelo
  /// 
  /// Por ahora solo Sale Orders usan filtro temporal.
  /// 
  /// Ejemplo:
  /// ```dart
  /// if (TenantStorageConfig.shouldApplyTemporalFilter('sale.order')) {
  ///   domain.add(['create_date', '>=', getSaleOrdersDateDomain()]);
  /// }
  /// ```
  static bool shouldApplyTemporalFilter(String modelName) {
    if (!enableTemporalFiltering) return false;
    
    return modelName == 'sale.order';
  }
  
  /// Obtiene el límite de registros para un modelo
  /// 
  /// Retorna el número máximo de registros permitidos para cacheo.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final limit = TenantStorageConfig.getEntityLimit('product.product');
  /// // Resultado: 10000
  /// ```
  static int getEntityLimit(String modelName) {
    switch (modelName) {
      case 'product.product':
        return maxProductsPerTenant;
      case 'res.partner':
        return maxPartnersPerTenant;
      case 'hr.employee':
        return maxEmployeesPerTenant;
      case 'res.partner.delivery':
        return maxShippingAddressesPerTenant;
      default:
        return 5000;  // Límite por defecto
    }
  }
  
  /// Calcula si un tamaño está cerca del límite
  /// 
  /// Retorna true si el tamaño supera el umbral de alerta.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final sizeMB = 85;
  /// if (TenantStorageConfig.isNearLimit(sizeMB)) {
  ///   print('⚠️ Almacenamiento cerca del límite!');
  /// }
  /// ```
  static bool isNearLimit(double sizeMB) {
    return sizeMB >= (maxTotalSizeMB * storageAlertThreshold);
  }
  
  /// [DEBUG] Obtiene información de configuración
  /// 
  /// Útil para logs y debugging.
  static Map<String, dynamic> getDebugInfo() {
    return {
      'maxTotalSizeMB': maxTotalSizeMB,
      'saleOrdersMonthsBack': saleOrdersMonthsBack,
      'enableTemporalFiltering': enableTemporalFiltering,
      'autoCleanupOnLicenseChange': autoCleanupOnLicenseChange,
      'saleOrdersDateLimit': getSaleOrdersDateDomain(),
      'storageAlertThreshold': '${(storageAlertThreshold * 100).toInt()}%',
    };
  }
}

