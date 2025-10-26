import 'package:odoo_repository/odoo_repository.dart';
import '../tenant/tenant_aware_cache.dart';

/// Store para gestionar marcadores de última sincronización por modelo
/// 
/// Los marcadores se guardan en formato ISO8601 (UTC) para cada modelo de Odoo.
/// Esto permite implementar sincronización incremental: solo fetch de registros
/// modificados desde el último marcador.
/// 
/// ✅ v2.0: USA TenantAwareCache para aislar marcadores por licencia
class SyncMarkerStore {
  final OdooKv _cache;
  final TenantAwareCache? _tenantCache;
  
  // ✅ v2.0: Key base sin prefijo (tenantCache agrega el prefijo automáticamente)
  static const String _markerKey = 'sync_markers';

  SyncMarkerStore(this._cache, {TenantAwareCache? tenantCache})
      : _tenantCache = tenantCache;

  /// Obtiene el marcador de sincronización para un modelo
  /// 
  /// Retorna null si no existe marcador (primera sincronización)
  DateTime? getMarker(String model) {
    final markers = _getAllMarkers();
    final timestampStr = markers[model];
    if (timestampStr == null) return null;
    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      print('⚠️ SYNC_MARKER_STORE: Error parsing timestamp for $model: $e');
      return null;
    }
  }

  /// Guarda el marcador de sincronización para un modelo
  /// 
  /// El timestamp se guarda en UTC y formato ISO8601
  Future<void> setMarker(String model, DateTime timestamp) async {
    final markers = _getAllMarkers();
    markers[model] = timestamp.toUtc().toIso8601String();
    
    // ✅ v2.0: Usar tenantCache si está disponible
    if (_tenantCache != null) {
      await _tenantCache!.put(_markerKey, markers);
    } else {
      await _cache.put(_markerKey, markers);
    }
    
    print('✅ SYNC_MARKER_STORE: Marcador guardado para $model: ${timestamp.toUtc().toIso8601String()}');
  }

  /// Actualiza múltiples marcadores a la vez
  /// 
  /// Útil para actualizar todos los modelos después de un bootstrap completo
  Future<void> setMultipleMarkers(Map<String, DateTime> markers) async {
    final currentMarkers = _getAllMarkers();
    for (final entry in markers.entries) {
      currentMarkers[entry.key] = entry.value.toUtc().toIso8601String();
    }
    
    // ✅ v2.0: Usar tenantCache si está disponible
    if (_tenantCache != null) {
      await _tenantCache!.put(_markerKey, currentMarkers);
    } else {
      await _cache.put(_markerKey, currentMarkers);
    }
    
    print('✅ SYNC_MARKER_STORE: ${markers.length} marcadores guardados');
  }

  /// Elimina el marcador de un modelo (para forzar full sync)
  Future<void> clearMarker(String model) async {
    final markers = _getAllMarkers();
    markers.remove(model);
    
    // ✅ v2.0: Usar tenantCache si está disponible
    if (_tenantCache != null) {
      await _tenantCache!.put(_markerKey, markers);
    } else {
      await _cache.put(_markerKey, markers);
    }
    
    print('🗑️ SYNC_MARKER_STORE: Marcador eliminado para $model');
  }

  /// Limpia todos los marcadores (para forzar full sync de todos los modelos)
  Future<void> clearAllMarkers() async {
    // ✅ v2.0: Usar tenantCache si está disponible
    if (_tenantCache != null) {
      await _tenantCache!.delete(_markerKey);
    } else {
      await _cache.delete(_markerKey);
    }
    
    print('🗑️ SYNC_MARKER_STORE: Todos los marcadores eliminados');
  }

  /// Obtiene todos los marcadores como Map
  Map<String, String> getAllMarkersRaw() {
    return Map<String, String>.from(_getAllMarkers());
  }

  /// Obtiene todos los marcadores como Map<String, DateTime>
  Map<String, DateTime> getAllMarkers() {
    final rawMarkers = _getAllMarkers();
    final parsed = <String, DateTime>{};
    
    for (final entry in rawMarkers.entries) {
      try {
        parsed[entry.key] = DateTime.parse(entry.value);
      } catch (e) {
        print('⚠️ SYNC_MARKER_STORE: Error parsing timestamp for ${entry.key}: $e');
      }
    }
    
    return parsed;
  }

  /// Obtiene todos los marcadores (interno)
  Map<String, String> _getAllMarkers() {
    // ✅ v2.0: Usar tenantCache si está disponible
    final data = _tenantCache != null
        ? _tenantCache!.get(_markerKey, defaultValue: <String, String>{})
        : _cache.get(_markerKey, defaultValue: <String, String>{});
    
    if (data is Map) {
      // Convertir de forma segura Map<dynamic, dynamic> a Map<String, String>
      final result = <String, String>{};
      data.forEach((key, value) {
        if (key is String && value is String) {
          result[key] = value;
        } else if (key != null && value != null) {
          result[key.toString()] = value.toString();
        }
      });
      return result;
    }
    return <String, String>{};
  }

  /// Verifica si existe un marcador para un modelo
  bool hasMarker(String model) {
    return _getAllMarkers().containsKey(model);
  }

  /// Verifica si existen marcadores para cualquier modelo
  bool hasAnyMarker() {
    return _getAllMarkers().isNotEmpty;
  }

  /// Verifica si existen marcadores para todos los módulos críticos
  /// 
  /// Los módulos críticos son: partners, products, employees, shipping_addresses, sale_orders
  /// Si todos tienen marcador, significa que ya se hizo un bootstrap completo
  /// y podemos usar sincronización incremental
  bool hasAllCriticalMarkers() {
    final hasPartner = hasMarker('res.partner');
    final hasProduct = hasMarker('product.product');
    final hasEmployee = hasMarker('hr.employee');
    final hasShipping = hasMarker('res.partner.delivery');
    final hasSaleOrder = hasMarker('sale.order');
    
    final result = hasPartner && hasProduct && hasEmployee && hasShipping && hasSaleOrder;
    
    if (!result) {
      final allMarkers = _getAllMarkers();
      print('⚠️ SYNC_MARKER_STORE: Marcadores incompletos');
      print('   Disponibles: ${allMarkers.keys.toList()}');
      print('   Faltantes: ${[
        if (!hasPartner) 'res.partner',
        if (!hasProduct) 'product.product',
        if (!hasEmployee) 'hr.employee',
        if (!hasShipping) 'res.partner.delivery',
        if (!hasSaleOrder) 'sale.order',
      ]}');
    }
    
    return result;
  }

  /// Verifica si la caché tiene contenido válido
  /// 
  /// Útil para detectar si tenemos marcadores pero la caché está corrupta
  bool hasCacheContent() {
    try {
      // ✅ v2.0: Usar tenantCache si está disponible
      final partnerCache = _tenantCache != null
          ? _tenantCache!.get('Partner_records')
          : _cache.get('Partner_records');
      final productCache = _tenantCache != null
          ? _tenantCache!.get('Product_records')
          : _cache.get('Product_records');
      final employeeCache = _tenantCache != null
          ? _tenantCache!.get('Employee_records')
          : _cache.get('Employee_records');
      final shippingAddressCache = _tenantCache != null
          ? _tenantCache!.get('ShippingAddress_records')
          : _cache.get('ShippingAddress_records');
      final saleOrderCache = _tenantCache != null
          ? _tenantCache!.get('sale_orders')
          : _cache.get('sale_orders');
      
      print('🔍 SYNC_MARKER_STORE: Verificando caché:');
      print('   - Partners (Partner_records): ${partnerCache != null ? "✅" : "❌"}');
      print('   - Products (Product_records): ${productCache != null ? "✅" : "❌"}');
      print('   - Employees (Employee_records): ${employeeCache != null ? "✅" : "❌"}');
      print('   - Shipping Addresses (ShippingAddress_records): ${shippingAddressCache != null ? "✅" : "❌"}');
      print('   - Sale Orders (sale_orders): ${saleOrderCache != null ? "✅" : "❌"}');
      
      return partnerCache != null &&
             productCache != null &&
             employeeCache != null &&
             shippingAddressCache != null &&
             saleOrderCache != null;
    } catch (e) {
      print('⚠️ SYNC_MARKER_STORE: Error verificando caché: $e');
      return false;
    }
  }

  /// Verifica si los marcadores son recientes (< 7 días)
  /// 
  /// Si los marcadores son muy antiguos, puede ser mejor hacer bootstrap completo
  bool hasRecentMarkers({int maxDays = 7}) {
    final oldest = getOldestMarker();
    if (oldest == null) return false;
    
    final now = DateTime.now();
    final hoursSinceSync = now.difference(oldest).inHours;
    final daysSinceSync = (hoursSinceSync / 24).ceil();
    
    return daysSinceSync <= maxDays;
  }

  /// Obtiene el marcador más antiguo (útil para diagnostics)
  DateTime? getOldestMarker() {
    final markers = getAllMarkers();
    if (markers.isEmpty) return null;
    
    DateTime? oldest;
    for (final timestamp in markers.values) {
      if (oldest == null || timestamp.isBefore(oldest)) {
        oldest = timestamp;
      }
    }
    return oldest;
  }

  /// Obtiene el marcador más reciente (útil para diagnostics)
  DateTime? getNewestMarker() {
    final markers = getAllMarkers();
    if (markers.isEmpty) return null;
    
    DateTime? newest;
    for (final timestamp in markers.values) {
      if (newest == null || timestamp.isAfter(newest)) {
        newest = timestamp;
      }
    }
    return newest;
  }
}

