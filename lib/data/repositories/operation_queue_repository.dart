import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_operation_model.dart';

/// Repository para manejar la cola de operaciones offline
class OperationQueueRepository {
  static const String _queueBox = 'offline_queue';
  late Box<List> _box;
  
  /// Inicializa el almacenamiento de la cola
  Future<void> init() async {
    _box = await Hive.openBox<List>(_queueBox);
  }
  
  /// Cierra el almacenamiento
  Future<void> close() async {
    await _box.close();
  }

  /// Agrega una operación a la cola
  Future<void> addOperation(PendingOperation operation) async {
    try {
      final operations = await getPendingOperations();
      operations.add(operation);
      await _saveOperations(operations);
      
      print('📋 QUEUE_REPO: Operación agregada - ${operation.operation} ${operation.model} (${operations.length} total)');
    } catch (e) {
      print('❌ QUEUE_REPO: Error agregando operación: $e');
      rethrow;
    }
  }

  /// Obtiene todas las operaciones pendientes
  Future<List<PendingOperation>> getPendingOperations() async {
    try {
      final data = _box.get('pending_operations', defaultValue: <Map<String, dynamic>>[]);
      if (data is List) {
        return data.map((json) => PendingOperation.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('❌ QUEUE_REPO: Error obteniendo operaciones: $e');
      return [];
    }
  }

  /// Obtiene operaciones pendientes por modelo
  Future<List<PendingOperation>> getPendingOperationsByModel(String model) async {
    final allOperations = await getPendingOperations();
    return allOperations.where((op) => op.model == model).toList();
  }

  /// Obtiene operaciones que pueden ser reintentadas
  Future<List<PendingOperation>> getRetryableOperations() async {
    final allOperations = await getPendingOperations();
    return allOperations.where((op) => op.canRetry).toList();
  }

  /// Actualiza una operación existente
  Future<void> updateOperation(PendingOperation operation) async {
    try {
      final operations = await getPendingOperations();
      final index = operations.indexWhere((op) => op.id == operation.id);
      
      if (index != -1) {
        operations[index] = operation;
        await _saveOperations(operations);
        print('📋 QUEUE_REPO: Operación actualizada - ${operation.id}');
      } else {
        print('⚠️ QUEUE_REPO: Operación no encontrada para actualizar - ${operation.id}');
      }
    } catch (e) {
      print('❌ QUEUE_REPO: Error actualizando operación: $e');
      rethrow;
    }
  }

  /// Elimina una operación de la cola
  Future<void> removeOperation(String operationId) async {
    try {
      final operations = await getPendingOperations();
      operations.removeWhere((op) => op.id == operationId);
      await _saveOperations(operations);
      
      print('📋 QUEUE_REPO: Operación eliminada - $operationId (${operations.length} restantes)');
    } catch (e) {
      print('❌ QUEUE_REPO: Error eliminando operación: $e');
      rethrow;
    }
  }

  /// Elimina operaciones completadas y abandonadas
  Future<void> cleanupCompletedOperations() async {
    try {
      final operations = await getPendingOperations();
      final activeOperations = operations.where((op) => op.status.isActive).toList();
      
      if (activeOperations.length != operations.length) {
        await _saveOperations(activeOperations);
        final cleaned = operations.length - activeOperations.length;
        print('🧹 QUEUE_REPO: Limpieza completada - $cleaned operaciones eliminadas');
      }
    } catch (e) {
      print('❌ QUEUE_REPO: Error en limpieza: $e');
      rethrow;
    }
  }

  /// Limpia todas las operaciones (usar con precaución)
  Future<void> clearAllOperations() async {
    try {
      await _saveOperations([]);
      print('🧹 QUEUE_REPO: Todas las operaciones eliminadas');
    } catch (e) {
      print('❌ QUEUE_REPO: Error limpiando todas las operaciones: $e');
      rethrow;
    }
  }

  /// Obtiene el número de operaciones pendientes
  Future<int> getPendingCount() async {
    final operations = await getPendingOperations();
    return operations.where((op) => op.status.isActive).length;
  }

  /// Obtiene estadísticas de la cola
  Future<QueueStats> getQueueStats() async {
    final operations = await getPendingOperations();
    
    return QueueStats(
      total: operations.length,
      pending: operations.where((op) => op.status == OperationStatus.pending).length,
      syncing: operations.where((op) => op.status == OperationStatus.syncing).length,
      completed: operations.where((op) => op.status == OperationStatus.completed).length,
      failed: operations.where((op) => op.status == OperationStatus.failed).length,
      abandoned: operations.where((op) => op.status == OperationStatus.abandoned).length,
    );
  }

  /// Guarda la lista de operaciones en el almacenamiento
  Future<void> _saveOperations(List<PendingOperation> operations) async {
    final jsonData = operations.map((op) => op.toJson()).toList();
    await _box.put('pending_operations', jsonData);
  }

  /// Obtiene operaciones por tipo
  Future<List<PendingOperation>> getOperationsByType(String operationType) async {
    final allOperations = await getPendingOperations();
    return allOperations.where((op) => op.operation == operationType).toList();
  }

  /// Obtiene operaciones que necesitan reintento
  Future<List<PendingOperation>> getOperationsNeedingRetry() async {
    final allOperations = await getPendingOperations();
    final now = DateTime.now();
    
    return allOperations.where((op) => 
      op.canRetry && 
      op.status == OperationStatus.failed &&
      now.isAfter(op.nextRetryTime)
    ).toList();
  }
}

/// Estadísticas de la cola de operaciones
class QueueStats {
  final int total;
  final int pending;
  final int syncing;
  final int completed;
  final int failed;
  final int abandoned;

  const QueueStats({
    required this.total,
    required this.pending,
    required this.syncing,
    required this.completed,
    required this.failed,
    required this.abandoned,
  });

  /// Obtiene operaciones activas (pending + syncing)
  int get active => pending + syncing;

  /// Obtiene operaciones finalizadas (completed + abandoned)
  int get finalised => completed + abandoned;

  /// Obtiene el porcentaje de éxito
  double get successRate => total > 0 ? (completed / total) * 100 : 0.0;

  @override
  String toString() {
    return 'QueueStats(total: $total, active: $active, completed: $completed, failed: $failed)';
  }
}
