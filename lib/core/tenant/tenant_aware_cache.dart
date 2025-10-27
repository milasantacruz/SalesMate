import 'package:odoo_repository/odoo_repository.dart';
import 'tenant_context.dart';

/// Cache con aislamiento automático por tenant
/// 
/// Wrapper sobre CustomOdooKv que añade scope automático basado en la licencia actual.
/// Todas las operaciones de cache se aíslan automáticamente por tenant.
/// 
/// ⚠️ v2.0: Single-Tenant - Solo una licencia cacheada a la vez
/// 
/// Ejemplo de uso:
/// ```dart
/// final cache = TenantAwareCache(customOdooKv);
/// 
/// TenantContext.setTenant('POF0001', 'db');
/// await cache.put('Partner_records', [...]);
/// // Se guarda como: "POF0001:Partner_records"
/// 
/// final data = cache.get<List>('Partner_records');
/// // Se busca: "POF0001:Partner_records"
/// ```
class TenantAwareCache {
  final OdooKv _kv;
  
  TenantAwareCache(this._kv);
  
  /// Obtiene un valor del cache con scope del tenant actual
  /// 
  /// Genera automáticamente la clave con scope: `"licenseId:key"`
  /// 
  /// Ejemplo:
  /// ```dart
  /// TenantContext.setTenant('POF0001', 'db');
  /// final partners = cache.get<List>('Partner_records');
  /// // Busca en: "POF0001:Partner_records"
  /// ```
  /// 
  /// Lanza [TenantException] si no hay tenant activo.
  T? get<T>(String key, {T? defaultValue}) {
    final scopedKey = TenantContext.scopeKey(key);
    final value = _kv.get(scopedKey, defaultValue: defaultValue);
    
    if (value != null) {
      print('💾 TENANT_CACHE: GET "$key" → "$scopedKey" (${value.runtimeType})');
      
      // Log detallado para listas
      if (value is List) {
        print('📊 TENANT_CACHE: Lista tiene ${value.length} elementos');
        if (value.isEmpty) {
          print('⚠️ TENANT_CACHE: Lista VACÍA (${value.runtimeType})');
        }
      }
    } else {
      print('💾 TENANT_CACHE: GET "$key" → "$scopedKey" (null o defaultValue)');
    }
    
    return value as T?;
  }
  
  /// Guarda un valor en el cache con scope del tenant actual
  /// 
  /// Genera automáticamente la clave con scope: `"licenseId:key"`
  /// 
  /// Ejemplo:
  /// ```dart
  /// TenantContext.setTenant('POF0001', 'db');
  /// await cache.put('Partner_records', [...]);
  /// // Se guarda en: "POF0001:Partner_records"
  /// ```
  /// 
  /// Lanza [TenantException] si no hay tenant activo.
  Future<void> put(String key, dynamic value) async {
    final scopedKey = TenantContext.scopeKey(key);
    await _kv.put(scopedKey, value);
    
    print('💾 TENANT_CACHE: PUT "$key" → "$scopedKey" (${value.runtimeType})');
  }
  
  /// Elimina un valor del cache con scope del tenant actual
  /// 
  /// Ejemplo:
  /// ```dart
  /// TenantContext.setTenant('POF0001', 'db');
  /// await cache.delete('Partner_records');
  /// // Elimina: "POF0001:Partner_records"
  /// ```
  /// 
  /// Lanza [TenantException] si no hay tenant activo.
  Future<void> delete(String key) async {
    final scopedKey = TenantContext.scopeKey(key);
    await _kv.delete(scopedKey);
    
    print('🗑️ TENANT_CACHE: DELETE "$key" → "$scopedKey"');
  }
  
  /// Obtiene todas las claves para un tenant específico
  /// 
  /// ⚠️ IMPORTANTE: No requiere tenant activo (puede buscar otras licencias).
  /// 
  /// Útil para:
  /// - Listar todos los datos de un tenant
  /// - Limpiar cache de un tenant específico
  /// - Auditoría de almacenamiento
  /// 
  /// Ejemplo:
  /// ```dart
  /// final keys = cache.getAllKeysForTenant('POF0001');
  /// // Resultado: ['POF0001:Partner_records', 'POF0001:Product_records', ...]
  /// ```
  List<String> getAllKeysForTenant(String licenseNumber) {
    final prefix = '$licenseNumber:';
    final allKeys = _kv.keys.cast<String>();
    final tenantKeys = allKeys.where((key) => key.startsWith(prefix)).toList();
    
    print('🔍 TENANT_CACHE: Encontradas ${tenantKeys.length} keys para $licenseNumber');
    
    return tenantKeys;
  }
  
  /// Elimina TODOS los datos de un tenant específico
  /// 
  /// ⚠️ OPERACIÓN DESTRUCTIVA - No se puede deshacer
  /// 
  /// ⚠️ IMPORTANTE: No requiere que ese tenant esté activo.
  /// Esto es crítico para limpiar el cache de la licencia ANTERIOR
  /// cuando se detecta un cambio de licencia en login.
  /// 
  /// Ejemplo de uso en cambio de licencia:
  /// ```dart
  /// // Usuario tenía POF0001, ahora hace login con POF0003
  /// final previousLicense = TenantContext.setTenant('POF0003', 'db');
  /// if (previousLicense != null) {
  ///   // Limpiar cache de POF0001 (anterior)
  ///   await cache.clearTenant(previousLicense);
  /// }
  /// ```
  Future<void> clearTenant(String licenseNumber) async {
    print('🧹 TENANT_CACHE: Limpiando todos los datos de $licenseNumber...');
    
    final keysToDelete = getAllKeysForTenant(licenseNumber);
    
    if (keysToDelete.isEmpty) {
      print('✅ TENANT_CACHE: No hay datos para limpiar ($licenseNumber)');
      return;
    }
    
    int deletedCount = 0;
    for (final key in keysToDelete) {
      await _kv.delete(key);
      deletedCount++;
    }
    
    print('✅ TENANT_CACHE: $deletedCount keys eliminadas para $licenseNumber');
    print('🗑️ TENANT_CACHE: Cache de $licenseNumber completamente limpio');
  }
  
  /// Calcula el tamaño aproximado del cache para un tenant (en MB)
  /// 
  /// ⚠️ NOTA: Este cálculo es aproximado basado en la serialización JSON.
  /// El tamaño real en disco puede variar.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final sizeMB = cache.getTenantSize('POF0001');
  /// print('Tenant POF0001 usa $sizeMB MB');
  /// ```
  double getTenantSize(String licenseNumber) {
    final keys = getAllKeysForTenant(licenseNumber);
    int totalBytes = 0;
    
    for (final key in keys) {
      final value = _kv.get(key);
      if (value != null) {
        // Estimación aproximada del tamaño
        final valueString = value.toString();
        totalBytes += valueString.length;
      }
    }
    
    final sizeMB = totalBytes / (1024 * 1024);
    
    print('📊 TENANT_CACHE: Tamaño de $licenseNumber: ${sizeMB.toStringAsFixed(2)} MB');
    
    return sizeMB;
  }
  
  /// Verifica si una clave existe para el tenant actual
  /// 
  /// Ejemplo:
  /// ```dart
  /// TenantContext.setTenant('POF0001', 'db');
  /// if (cache.contains('Partner_records')) {
  ///   print('Ya hay partners cacheados');
  /// }
  /// ```
  bool contains(String key) {
    try {
      final scopedKey = TenantContext.scopeKey(key);
      final allKeys = _kv.keys.cast<String>();
      return allKeys.contains(scopedKey);
    } catch (e) {
      // Si no hay tenant activo, retorna false
      return false;
    }
  }
  
  /// Lista todos los tenants que tienen datos en cache
  /// 
  /// Útil para:
  /// - Auditoría de almacenamiento
  /// - Debugging
  /// - Limpieza administrativa
  /// 
  /// Ejemplo:
  /// ```dart
  /// final tenants = cache.listAllTenants();
  /// print('Tenants en cache: $tenants');
  /// // Resultado: ['POF0001', 'POF0003']
  /// ```
  List<String> listAllTenants() {
    final allKeys = _kv.keys.cast<String>();
    final tenants = <String>{};
    
    for (final key in allKeys) {
      if (key.contains(':')) {
        final license = key.split(':').first;
        tenants.add(license);
      }
    }
    
    final tenantList = tenants.toList()..sort();
    
    print('🔍 TENANT_CACHE: ${tenantList.length} tenant(s) en cache: $tenantList');
    
    return tenantList;
  }
  
  /// [DEBUG] Obtiene información detallada del cache actual
  /// 
  /// Útil para debugging y logs.
  Map<String, dynamic> getDebugInfo() {
    final currentLicense = TenantContext.currentLicenseNumber;
    final allTenants = listAllTenants();
    
    return {
      'currentTenant': currentLicense,
      'allTenants': allTenants,
      'currentTenantKeys': currentLicense != null 
          ? getAllKeysForTenant(currentLicense).length 
          : 0,
      'currentTenantSizeMB': currentLicense != null
          ? getTenantSize(currentLicense)
          : 0.0,
      'totalKeys': _kv.keys.length,
    };
  }
}

