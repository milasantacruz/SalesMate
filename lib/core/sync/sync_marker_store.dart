import 'package:odoo_repository/odoo_repository.dart';

/// Store para gestionar marcadores de última sincronización por modelo
/// 
/// Los marcadores se guardan en formato ISO8601 (UTC) para cada modelo de Odoo.
/// Esto permite implementar sincronización incremental: solo fetch de registros
/// modificados desde el último marcador.
class SyncMarkerStore {
  final OdooKv _cache;
  static const String _markerKey = 'sync_markers';

  SyncMarkerStore(this._cache);

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
    await _cache.put(_markerKey, markers);
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
    await _cache.put(_markerKey, currentMarkers);
    print('✅ SYNC_MARKER_STORE: ${markers.length} marcadores guardados');
  }

  /// Elimina el marcador de un modelo (para forzar full sync)
  Future<void> clearMarker(String model) async {
    final markers = _getAllMarkers();
    markers.remove(model);
    await _cache.put(_markerKey, markers);
    print('🗑️ SYNC_MARKER_STORE: Marcador eliminado para $model');
  }

  /// Limpia todos los marcadores (para forzar full sync de todos los modelos)
  Future<void> clearAllMarkers() async {
    await _cache.delete(_markerKey);
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
    final data = _cache.get(_markerKey, defaultValue: <String, String>{});
    if (data is Map) {
      return Map<String, String>.from(data);
    }
    return {};
  }

  /// Verifica si existe un marcador para un modelo
  bool hasMarker(String model) {
    return _getAllMarkers().containsKey(model);
  }

  /// Verifica si existen marcadores para cualquier modelo
  bool hasAnyMarker() {
    return _getAllMarkers().isNotEmpty;
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

