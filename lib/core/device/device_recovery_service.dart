import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Servicio para generar, persistir y recuperar UUID de recuperación de dispositivo
/// 
/// Este servicio gestiona el UUID que se usa como identificador de dispositivo
/// y se guarda en el backend. El UUID se genera una vez y se persiste localmente
/// para permitir la recuperación tras reinstalación mediante key/QR.
class DeviceRecoveryService {
  static const String _boxName = 'device_recovery';
  static const String _uuidKey = 'device_recovery_uuid';
  static const Uuid _uuid = Uuid();

  Box<String>? _box;

  /// Inicializa el almacenamiento de Hive para UUID
  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return; // Ya está inicializado
    }
    _box = await Hive.openBox<String>(_boxName);
    print('🔑 DEVICE_RECOVERY: Box "$_boxName" inicializado');
  }

  /// Cierra el almacenamiento de Hive
  Future<void> close() async {
    await _box?.close();
    _box = null;
    print('🔑 DEVICE_RECOVERY: Box "$_boxName" cerrado');
  }

  /// Genera un nuevo UUID v4 en formato legible
  /// 
  /// Formato: `550e8400-e29b-41d4-a716-446655440000`
  String generateUUID() {
    final uuid = _uuid.v4();
    print('🔑 DEVICE_RECOVERY: UUID generado: $uuid');
    return uuid;
  }

  /// Obtiene el UUID almacenado en cache local
  /// 
  /// Retorna `null` si no existe un UUID almacenado.
  String? getStoredUUID() {
    if (_box == null || !_box!.isOpen) {
      print('⚠️ DEVICE_RECOVERY: Box no inicializado, no se puede obtener UUID');
      return null;
    }

    final uuid = _box!.get(_uuidKey);
    if (uuid != null) {
      print('🔑 DEVICE_RECOVERY: UUID obtenido de cache: $uuid');
    } else {
      print('🔑 DEVICE_RECOVERY: No hay UUID en cache');
    }
    return uuid;
  }

  /// Almacena un UUID en cache local
  /// 
  /// Si se proporciona un UUID, se guarda ese. Si no, se genera uno nuevo.
  /// Retorna el UUID que fue guardado.
  /// 
  /// Lanza [ArgumentError] si el UUID proporcionado no es válido.
  Future<String> storeUUID([String? uuid]) async {
    if (_box == null || !_box!.isOpen) {
      print('⚠️ DEVICE_RECOVERY: Box no inicializado, inicializando...');
      await init();
    }

    // Validar UUID si se proporciona
    if (uuid != null) {
      final normalizedUuid = normalizeUUID(uuid);
      if (!isValidUUID(normalizedUuid)) {
        print('❌ DEVICE_RECOVERY: Intento de guardar UUID inválido: $uuid');
        throw ArgumentError('UUID inválido: $uuid. Debe ser un UUID v4 válido.');
      }
      await _box!.put(_uuidKey, normalizedUuid);
      print('🔑 DEVICE_RECOVERY: UUID guardado en cache: $normalizedUuid');
      return normalizedUuid;
    }

    // Generar nuevo UUID si no se proporciona
    final uuidToStore = generateUUID();
    await _box!.put(_uuidKey, uuidToStore);
    print('🔑 DEVICE_RECOVERY: UUID generado y guardado en cache: $uuidToStore');
    return uuidToStore;
  }

  /// Elimina el UUID almacenado en cache local
  /// 
  /// Útil para testing o cuando se necesita forzar la generación de un nuevo UUID.
  Future<void> clearUUID() async {
    if (_box == null || !_box!.isOpen) {
      print('⚠️ DEVICE_RECOVERY: Box no inicializado, no hay UUID que eliminar');
      return;
    }

    await _box!.delete(_uuidKey);
    print('🔑 DEVICE_RECOVERY: UUID eliminado de cache');
  }

  /// Valida si una cadena es un UUID v4 válido
  /// 
  /// Formato esperado: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
  /// donde x es hexadecimal e y es uno de 8, 9, a, o b
  bool isValidUUID(String uuid) {
    // Validar que no esté vacío
    if (uuid.trim().isEmpty) {
      print('⚠️ DEVICE_RECOVERY: UUID vacío');
      return false;
    }
    
    // Validar longitud (UUID tiene 36 caracteres con guiones)
    if (uuid.trim().length != 36) {
      print('⚠️ DEVICE_RECOVERY: UUID con longitud incorrecta: ${uuid.trim().length} (esperado: 36)');
      return false;
    }
    
    final regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final isValid = regex.hasMatch(uuid.trim());
    if (!isValid) {
      print('⚠️ DEVICE_RECOVERY: UUID con formato inválido: $uuid');
    }
    return isValid;
  }

  /// Normaliza un UUID eliminando espacios y convirtiendo a minúsculas
  /// 
  /// Útil para comparar UUIDs que pueden tener diferencias de formato.
  String normalizeUUID(String uuid) {
    return uuid.trim().toLowerCase();
  }

  /// Compara dos UUIDs ignorando mayúsculas/minúsculas y espacios
  /// 
  /// Retorna `true` si los UUIDs son equivalentes.
  /// Retorna `false` si alguno de los UUIDs es inválido.
  bool compareUUIDs(String uuid1, String uuid2) {
    final normalized1 = normalizeUUID(uuid1);
    final normalized2 = normalizeUUID(uuid2);
    
    // Validar ambos UUIDs antes de comparar
    if (!isValidUUID(normalized1)) {
      print('⚠️ DEVICE_RECOVERY: UUID1 inválido en comparación: $uuid1');
      return false;
    }
    if (!isValidUUID(normalized2)) {
      print('⚠️ DEVICE_RECOVERY: UUID2 inválido en comparación: $uuid2');
      return false;
    }
    
    return normalized1 == normalized2;
  }
  
  /// Verifica si el almacenamiento está disponible y funcional
  /// 
  /// Útil para detectar problemas con Hive antes de intentar operaciones.
  bool isStorageAvailable() {
    return _box != null && _box!.isOpen;
  }
  
  /// Obtiene información de diagnóstico del servicio
  /// 
  /// Retorna un mapa con información útil para debugging.
  Map<String, dynamic> getDiagnostics() {
    return {
      'boxInitialized': _box != null,
      'boxOpen': _box?.isOpen ?? false,
      'hasStoredUUID': getStoredUUID() != null,
      'storedUUID': getStoredUUID(),
    };
  }
}

