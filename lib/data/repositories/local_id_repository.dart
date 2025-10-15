import 'dart:math';

/// Repository para manejar IDs locales únicos para operaciones offline
class LocalIdRepository {
  static final _random = Random();
  
  /// Prefijos para diferentes modelos
  static const Map<String, String> _modelPrefixes = {
    'res.partner': 'PART',
    'sale.order': 'SO',
    'product.product': 'PROD',
    'hr.employee': 'EMP',
    'res.city': 'CITY',
    'product.pricelist.item': 'PLI',
  };

  /// Genera un ID local único
  String generateLocalId() {
    return _generateUuid();
  }

  /// Genera un ID local con prefijo para un modelo específico
  String generateLocalIdForModel(String model) {
    final prefix = _modelPrefixes[model] ?? 'GEN';
    final uuid = _generateUuid().substring(0, 8); // Usar solo 8 caracteres del UUID
    return '${prefix}_$uuid';
  }

  /// Genera un ID local para una operación específica
  String generateOperationId(String model, String operation) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = _modelPrefixes[model] ?? 'GEN';
    return '${prefix}_${operation.toUpperCase()}_$timestamp';
  }

  /// Verifica si un ID es un ID local (no del servidor)
  bool isLocalId(String id) {
    if (id.isEmpty) return false;
    
    // Verificar si es un UUID válido
    if (_isValidUuid(id)) return true;
    
    // Verificar si tiene un prefijo conocido
    return _modelPrefixes.values.any((prefix) => id.startsWith('${prefix}_'));
  }

  /// Verifica si un ID es válido
  bool isValidId(String id) {
    return id.isNotEmpty && (isLocalId(id) || _isNumericId(id));
  }

  /// Extrae el modelo de un ID local (si es posible)
  String? extractModelFromLocalId(String localId) {
    if (!isLocalId(localId)) return null;
    
    for (final entry in _modelPrefixes.entries) {
      if (localId.startsWith('${entry.value}_')) {
        return entry.key;
      }
    }
    
    return null;
  }

  /// Obtiene el prefijo para un modelo
  String getPrefixForModel(String model) {
    return _modelPrefixes[model] ?? 'GEN';
  }

  /// Convierte un ID local a un ID de servidor (para mapeo después de sincronización)
  String mapLocalToServerId(String localId, int serverId) {
    // En una implementación real, esto podría almacenar el mapeo
    // Por ahora, simplemente retornamos el serverId como string
    return serverId.toString();
  }

  /// Obtiene todos los prefijos disponibles
  List<String> getAvailablePrefixes() {
    return _modelPrefixes.values.toList();
  }

  /// Obtiene todos los modelos con prefijos definidos
  List<String> getModelsWithPrefixes() {
    return _modelPrefixes.keys.toList();
  }

  /// Verifica si un UUID es válido
  bool _isValidUuid(String id) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(id);
  }

  /// Verifica si un ID es numérico (ID del servidor)
  bool _isNumericId(String id) {
    return int.tryParse(id) != null;
  }

  /// Genera un UUID simple usando timestamp y números aleatorios
  String _generateUuid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999);
    return '${timestamp}_$random';
  }

  /// Genera un ID único para una operación de actualización
  String generateUpdateOperationId(String model, int recordId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = _modelPrefixes[model] ?? 'GEN';
    return '${prefix}_UPDATE_${recordId}_$timestamp';
  }

  /// Genera un ID único para una operación de eliminación
  String generateDeleteOperationId(String model, int recordId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = _modelPrefixes[model] ?? 'GEN';
    return '${prefix}_DELETE_${recordId}_$timestamp';
  }

  /// Valida que un ID tenga el formato correcto para un modelo específico
  bool validateIdForModel(String id, String model) {
    if (!isValidId(id)) return false;
    
    // Si es un ID local, verificar que tenga el prefijo correcto
    if (isLocalId(id)) {
      final expectedPrefix = getPrefixForModel(model);
      return id.startsWith('${expectedPrefix}_');
    }
    
    // Si es un ID numérico, es válido para cualquier modelo
    return _isNumericId(id);
  }
}
