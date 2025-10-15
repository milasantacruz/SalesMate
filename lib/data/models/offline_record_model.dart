import 'package:equatable/equatable.dart';

/// Representa un registro que puede existir offline con mapeo a servidor
class OfflineRecord extends Equatable {
  /// ID único generado localmente (UUID)
  final String localId;
  
  /// ID del servidor (null si no se ha sincronizado)
  final int? serverId;
  
  /// Modelo de Odoo (ej: 'res.partner', 'sale.order')
  final String model;
  
  /// Datos del registro
  final Map<String, dynamic> data;
  
  /// Timestamp de creación local
  final DateTime createdAt;
  
  /// Timestamp de última sincronización exitosa
  final DateTime? syncedAt;
  
  /// Indica si el registro tiene cambios no sincronizados
  final bool isDirty;
  
  /// Hash de los datos para detectar cambios
  final String? dataHash;
  
  /// Versión del registro (incrementa con cada cambio)
  final int version;

  const OfflineRecord({
    required this.localId,
    this.serverId,
    required this.model,
    required this.data,
    required this.createdAt,
    this.syncedAt,
    this.isDirty = true,
    this.dataHash,
    this.version = 1,
  });

  /// Crea una copia del registro con nuevos valores
  OfflineRecord copyWith({
    String? localId,
    int? serverId,
    String? model,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? syncedAt,
    bool? isDirty,
    String? dataHash,
    int? version,
  }) {
    return OfflineRecord(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      model: model ?? this.model,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDirty: isDirty ?? this.isDirty,
      dataHash: dataHash ?? this.dataHash,
      version: version ?? this.version,
    );
  }

  /// Marca el registro como sincronizado
  OfflineRecord markAsSynced(int serverId) {
    return copyWith(
      serverId: serverId,
      syncedAt: DateTime.now(),
      isDirty: false,
    );
  }

  /// Marca el registro como modificado
  OfflineRecord markAsDirty() {
    return copyWith(
      isDirty: true,
      version: version + 1,
    );
  }

  /// Verifica si el registro necesita sincronización
  bool get needsSync => isDirty && (serverId != null || localId.isNotEmpty);

  /// Verifica si es un registro completamente local (nunca sincronizado)
  bool get isLocalOnly => serverId == null && localId.isNotEmpty;

  /// Verifica si es un registro del servidor (ya sincronizado)
  bool get isServerRecord => serverId != null && !isDirty;

  /// Convierte el registro a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'serverId': serverId,
      'model': model,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'isDirty': isDirty,
      'dataHash': dataHash,
      'version': version,
    };
  }

  /// Crea un registro desde JSON
  factory OfflineRecord.fromJson(Map<String, dynamic> json) {
    return OfflineRecord(
      localId: json['localId'] as String,
      serverId: json['serverId'] as int?,
      model: json['model'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncedAt: json['syncedAt'] != null 
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      isDirty: json['isDirty'] as bool? ?? true,
      dataHash: json['dataHash'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  /// Genera un hash de los datos para detectar cambios
  String generateDataHash() {
    // Convertir datos a string ordenado para generar hash consistente
    final sortedKeys = data.keys.toList()..sort();
    final dataString = sortedKeys.map((key) => '$key:${data[key]}').join('|');
    return dataString.hashCode.toString();
  }

  /// Verifica si los datos han cambiado comparando hashes
  bool hasDataChanged() {
    final currentHash = generateDataHash();
    return dataHash != currentHash;
  }

  /// Actualiza el hash de datos
  OfflineRecord updateDataHash() {
    return copyWith(dataHash: generateDataHash());
  }

  @override
  List<Object?> get props => [
        localId,
        serverId,
        model,
        data,
        createdAt,
        syncedAt,
        isDirty,
        dataHash,
        version,
      ];

  @override
  String toString() {
    return 'OfflineRecord(localId: $localId, serverId: $serverId, model: $model, isDirty: $isDirty, version: $version)';
  }
}
