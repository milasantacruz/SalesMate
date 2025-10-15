import 'package:equatable/equatable.dart';

/// Representa una operación pendiente de sincronización
class PendingOperation extends Equatable {
  /// ID único de la operación
  final String id;
  
  /// Tipo de operación: 'create', 'update', 'delete'
  final String operation;
  
  /// Modelo de Odoo afectado (ej: 'res.partner', 'sale.order')
  final String model;
  
  /// Datos de la operación
  final Map<String, dynamic> data;
  
  /// Timestamp de creación de la operación
  final DateTime timestamp;
  
  /// Número de intentos de sincronización
  final int retryCount;
  
  /// Mensaje de error del último intento (si aplica)
  final String? errorMessage;
  
  /// Estado de la operación
  final OperationStatus status;

  const PendingOperation({
    required this.id,
    required this.operation,
    required this.model,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.errorMessage,
    this.status = OperationStatus.pending,
  });

  /// Crea una copia de la operación con nuevos valores
  PendingOperation copyWith({
    String? id,
    String? operation,
    String? model,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
    String? errorMessage,
    OperationStatus? status,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      model: model ?? this.model,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }

  /// Convierte la operación a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation,
      'model': model,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'status': status.name,
    };
  }

  /// Crea una operación desde JSON
  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as String,
      operation: json['operation'] as String,
      model: json['model'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      status: OperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OperationStatus.pending,
      ),
    );
  }

  /// Verifica si la operación puede ser reintentada
  bool get canRetry => retryCount < 3 && status != OperationStatus.completed;

  /// Verifica si la operación ha fallado definitivamente
  bool get hasFailed => retryCount >= 3 && status == OperationStatus.failed;

  /// Obtiene el próximo timestamp para reintento
  DateTime get nextRetryTime {
    // Backoff exponencial: 5min, 15min, 45min
    final delays = [5, 15, 45];
    final delayMinutes = delays[retryCount.clamp(0, delays.length - 1)];
    return timestamp.add(Duration(minutes: delayMinutes));
  }

  @override
  List<Object?> get props => [
        id,
        operation,
        model,
        data,
        timestamp,
        retryCount,
        errorMessage,
        status,
      ];

  @override
  String toString() {
    return 'PendingOperation(id: $id, operation: $operation, model: $model, retryCount: $retryCount, status: $status)';
  }
}

/// Estados posibles de una operación pendiente
enum OperationStatus {
  /// Operación pendiente de sincronización
  pending,
  
  /// Operación siendo sincronizada actualmente
  syncing,
  
  /// Operación completada exitosamente
  completed,
  
  /// Operación falló y puede ser reintentada
  failed,
  
  /// Operación falló definitivamente
  abandoned,
}

/// Extensiones para OperationStatus
extension OperationStatusExtension on OperationStatus {
  /// Verifica si el estado indica que la operación está activa
  bool get isActive => this == OperationStatus.pending || this == OperationStatus.syncing;
  
  /// Verifica si el estado indica que la operación está finalizada
  bool get isFinal => this == OperationStatus.completed || this == OperationStatus.abandoned;
  
  /// Obtiene el emoji representativo del estado
  String get emoji {
    switch (this) {
      case OperationStatus.pending:
        return '⏳';
      case OperationStatus.syncing:
        return '🔄';
      case OperationStatus.completed:
        return '✅';
      case OperationStatus.failed:
        return '❌';
      case OperationStatus.abandoned:
        return '🚫';
    }
  }
}
