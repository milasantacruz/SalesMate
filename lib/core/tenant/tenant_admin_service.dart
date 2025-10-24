import 'tenant_aware_cache.dart';
import 'tenant_storage_config.dart';

/// Servicio de administración de tenants
/// 
/// Proporciona funcionalidades administrativas para gestionar
/// múltiples tenants en el cache (aunque v2.0 solo usa uno a la vez).
/// 
/// Útil para:
/// - Auditoría de almacenamiento
/// - Limpieza administrativa
/// - Debugging
/// - Métricas de uso
class TenantAdminService {
  final TenantAwareCache _cache;
  
  TenantAdminService(this._cache);
  
  /// Lista todos los tenants que tienen datos en cache
  /// 
  /// Retorna una lista de números de licencia.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final tenants = service.listAllTenants();
  /// print('Tenants: $tenants');
  /// // Resultado: ['POF0001', 'POF0003']
  /// ```
  List<String> listAllTenants() {
    print('🔍 TENANT_ADMIN: Listando todos los tenants...');
    final tenants = _cache.listAllTenants();
    print('✅ TENANT_ADMIN: ${tenants.length} tenant(s) encontrado(s)');
    return tenants;
  }
  
  /// Obtiene información detallada de un tenant
  /// 
  /// Retorna un mapa con:
  /// - `licenseNumber`: Número de licencia
  /// - `totalKeys`: Cantidad de claves en cache
  /// - `totalSizeMB`: Tamaño total en MB
  /// - `isNearLimit`: Si está cerca del límite de almacenamiento
  /// - `keys`: Lista de todas las claves (opcional)
  /// 
  /// Ejemplo:
  /// ```dart
  /// final info = service.getTenantInfo('POF0001');
  /// print('Tenant ${info['licenseNumber']} usa ${info['totalSizeMB']} MB');
  /// ```
  Map<String, dynamic> getTenantInfo(String licenseNumber, {bool includeKeys = false}) {
    print('📊 TENANT_ADMIN: Obteniendo info de $licenseNumber...');
    
    final keys = _cache.getAllKeysForTenant(licenseNumber);
    final sizeMB = _cache.getTenantSize(licenseNumber);
    final isNearLimit = TenantStorageConfig.isNearLimit(sizeMB);
    
    final info = {
      'licenseNumber': licenseNumber,
      'totalKeys': keys.length,
      'totalSizeMB': double.parse(sizeMB.toStringAsFixed(2)),
      'isNearLimit': isNearLimit,
      'maxLimitMB': TenantStorageConfig.maxTotalSizeMB,
      'usagePercentage': ((sizeMB / TenantStorageConfig.maxTotalSizeMB) * 100).toStringAsFixed(1) + '%',
    };
    
    if (includeKeys) {
      info['keys'] = keys;
    }
    
    if (isNearLimit) {
      print('⚠️ TENANT_ADMIN: $licenseNumber está cerca del límite (${info['usagePercentage']})');
    }
    
    print('✅ TENANT_ADMIN: Info obtenida para $licenseNumber');
    return info;
  }
  
  /// Elimina todos los tenants excepto el especificado
  /// 
  /// ⚠️ OPERACIÓN DESTRUCTIVA - No se puede deshacer
  /// 
  /// Útil para limpieza administrativa o migración.
  /// 
  /// Ejemplo:
  /// ```dart
  /// // Mantener solo POF0001, eliminar todos los demás
  /// await service.deleteAllTenantsExcept('POF0001');
  /// ```
  Future<void> deleteAllTenantsExcept(String currentLicense) async {
    print('🗑️ TENANT_ADMIN: Eliminando todos los tenants excepto $currentLicense...');
    
    final allTenants = listAllTenants();
    final tenantsToDelete = allTenants.where((t) => t != currentLicense).toList();
    
    if (tenantsToDelete.isEmpty) {
      print('✅ TENANT_ADMIN: No hay otros tenants para eliminar');
      return;
    }
    
    print('🧹 TENANT_ADMIN: Se eliminarán ${tenantsToDelete.length} tenant(s): $tenantsToDelete');
    
    for (final license in tenantsToDelete) {
      await _cache.clearTenant(license);
    }
    
    print('✅ TENANT_ADMIN: Limpieza completada. Solo queda: $currentLicense');
  }
  
  /// Calcula el tamaño total de cache de todos los tenants
  /// 
  /// Retorna el tamaño total en MB.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final totalMB = service.getTotalCacheSize();
  /// print('Cache total: $totalMB MB');
  /// ```
  double getTotalCacheSize() {
    print('📊 TENANT_ADMIN: Calculando tamaño total de cache...');
    
    final tenants = listAllTenants();
    double totalSize = 0.0;
    
    for (final license in tenants) {
      final size = _cache.getTenantSize(license);
      totalSize += size;
      print('  - $license: ${size.toStringAsFixed(2)} MB');
    }
    
    print('✅ TENANT_ADMIN: Tamaño total: ${totalSize.toStringAsFixed(2)} MB');
    
    if (TenantStorageConfig.isNearLimit(totalSize)) {
      print('⚠️ TENANT_ADMIN: Cache total cerca del límite!');
    }
    
    return totalSize;
  }
  
  /// Genera un reporte completo de todos los tenants
  /// 
  /// Útil para auditoría y debugging.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final report = service.generateStorageReport();
  /// print(report['summary']);
  /// ```
  Map<String, dynamic> generateStorageReport() {
    print('📊 TENANT_ADMIN: Generando reporte de almacenamiento...');
    
    final tenants = listAllTenants();
    final tenantsInfo = <Map<String, dynamic>>[];
    double totalSize = 0.0;
    int totalKeys = 0;
    
    for (final license in tenants) {
      final info = getTenantInfo(license);
      tenantsInfo.add(info);
      totalSize += info['totalSizeMB'] as double;
      totalKeys += info['totalKeys'] as int;
    }
    
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'totalTenants': tenants.length,
      'totalSizeMB': double.parse(totalSize.toStringAsFixed(2)),
      'totalKeys': totalKeys,
      'maxLimitMB': TenantStorageConfig.maxTotalSizeMB,
      'usagePercentage': ((totalSize / TenantStorageConfig.maxTotalSizeMB) * 100).toStringAsFixed(1) + '%',
      'isNearLimit': TenantStorageConfig.isNearLimit(totalSize),
      'tenants': tenantsInfo,
      'config': TenantStorageConfig.getDebugInfo(),
    };
    
    // Generar resumen legible
    final summary = StringBuffer();
    summary.writeln('========================================');
    summary.writeln('REPORTE DE ALMACENAMIENTO');
    summary.writeln('========================================');
    summary.writeln('Fecha: ${report['timestamp']}');
    summary.writeln('Tenants: ${report['totalTenants']}');
    summary.writeln('Tamaño total: ${report['totalSizeMB']} MB / ${report['maxLimitMB']} MB (${report['usagePercentage']})');
    summary.writeln('Keys totales: ${report['totalKeys']}');
    
    if (report['isNearLimit'] == true) {
      summary.writeln('⚠️ ALERTA: Cerca del límite de almacenamiento');
    }
    
    summary.writeln('\nDETALLE POR TENANT:');
    for (final info in tenantsInfo) {
      summary.writeln('  - ${info['licenseNumber']}: ${info['totalSizeMB']} MB (${info['totalKeys']} keys)');
    }
    
    summary.writeln('========================================');
    
    report['summary'] = summary.toString();
    
    print('✅ TENANT_ADMIN: Reporte generado');
    print(report['summary']);
    
    return report;
  }
  
  /// Verifica la salud del sistema de cache
  /// 
  /// Retorna un mapa con:
  /// - `healthy`: true si todo está OK
  /// - `warnings`: Lista de advertencias
  /// - `errors`: Lista de errores
  /// 
  /// Ejemplo:
  /// ```dart
  /// final health = service.checkHealth();
  /// if (!health['healthy']) {
  ///   print('Problemas detectados: ${health['warnings']}');
  /// }
  /// ```
  Map<String, dynamic> checkHealth() {
    print('🏥 TENANT_ADMIN: Verificando salud del sistema...');
    
    final warnings = <String>[];
    final errors = <String>[];
    
    // Verificar tamaño total
    final totalSize = getTotalCacheSize();
    if (totalSize > TenantStorageConfig.maxTotalSizeMB) {
      errors.add('Cache excede el límite máximo (${totalSize.toStringAsFixed(2)} MB > ${TenantStorageConfig.maxTotalSizeMB} MB)');
    } else if (TenantStorageConfig.isNearLimit(totalSize)) {
      warnings.add('Cache cerca del límite (${totalSize.toStringAsFixed(2)} MB)');
    }
    
    // Verificar múltiples tenants (en v2.0 debería haber solo 1)
    final tenants = listAllTenants();
    if (tenants.length > 1) {
      warnings.add('Múltiples tenants detectados (${tenants.length}). En Single-Tenant v2.0 debería haber solo 1.');
    }
    
    // Verificar tenants individuales
    for (final license in tenants) {
      final info = getTenantInfo(license);
      if (info['isNearLimit'] == true) {
        warnings.add('Tenant $license cerca del límite (${info['usagePercentage']})');
      }
    }
    
    final healthy = errors.isEmpty && warnings.isEmpty;
    
    final health = {
      'healthy': healthy,
      'warnings': warnings,
      'errors': errors,
      'totalTenants': tenants.length,
      'totalSizeMB': double.parse(totalSize.toStringAsFixed(2)),
    };
    
    if (healthy) {
      print('✅ TENANT_ADMIN: Sistema saludable');
    } else {
      if (warnings.isNotEmpty) {
        print('⚠️ TENANT_ADMIN: ${warnings.length} advertencia(s)');
      }
      if (errors.isNotEmpty) {
        print('❌ TENANT_ADMIN: ${errors.length} error(es)');
      }
    }
    
    return health;
  }
}

