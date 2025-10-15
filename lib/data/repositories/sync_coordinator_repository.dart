import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:odoo_repository/odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import '../models/pending_operation_model.dart';
import 'operation_queue_repository.dart';

/// Repository para coordinar la sincronización de operaciones offline
class SyncCoordinatorRepository {
  final NetworkConnectivity _networkConnectivity;
  final OperationQueueRepository _queueRepository;
  final OdooClient _odooClient;
  
  /// Callback para notificar cambios de estado
  Function(SyncProgress)? onProgressChanged;
  
  /// Callback para notificar errores
  Function(SyncError)? onError;

  SyncCoordinatorRepository({
    required NetworkConnectivity networkConnectivity,
    required OperationQueueRepository queueRepository,
    required OdooClient odooClient,
  }) : _networkConnectivity = networkConnectivity,
       _queueRepository = queueRepository,
       _odooClient = odooClient;

  /// Verifica si hay conexión a internet
  Future<bool> isOnline() async {
    try {
      final connectivity = await _networkConnectivity.checkNetConn();
      return connectivity == netConnState.online;
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error verificando conectividad: $e');
      return false;
    }
  }

  /// Sincroniza todas las operaciones pendientes
  Future<SyncResult> syncAllPendingOperations() async {
    print('🔄 SYNC_COORDINATOR: Iniciando sincronización de operaciones pendientes');
    
    if (!await isOnline()) {
      print('📱 SYNC_COORDINATOR: Sin conexión - cancelando sincronización');
      return SyncResult(
        success: false,
        message: 'Sin conexión a internet',
        syncedOperations: 0,
        failedOperations: 0,
      );
    }

    try {
      final pendingOperations = await _queueRepository.getPendingOperations();
      final activeOperations = pendingOperations.where((op) => op.status.isActive).toList();
      
      print('📋 SYNC_COORDINATOR: ${activeOperations.length} operaciones pendientes encontradas');
      
      if (activeOperations.isEmpty) {
        return SyncResult(
          success: true,
          message: 'No hay operaciones pendientes',
          syncedOperations: 0,
          failedOperations: 0,
        );
      }

      int syncedCount = 0;
      int failedCount = 0;
      
      for (int i = 0; i < activeOperations.length; i++) {
        final operation = activeOperations[i];
        
        // Notificar progreso
        onProgressChanged?.call(SyncProgress(
          currentOperation: i + 1,
          totalOperations: activeOperations.length,
          currentOperationType: operation.operation,
          currentModel: operation.model,
        ));
        
        try {
          final success = await _syncSingleOperation(operation);
          if (success) {
            syncedCount++;
            print('✅ SYNC_COORDINATOR: Operación sincronizada - ${operation.id}');
          } else {
            failedCount++;
            print('❌ SYNC_COORDINATOR: Falló sincronización - ${operation.id}');
          }
        } catch (e) {
          failedCount++;
          print('❌ SYNC_COORDINATOR: Error sincronizando operación ${operation.id}: $e');
          
          // Notificar error
          onError?.call(SyncError(
            operation: operation,
            error: e.toString(),
            timestamp: DateTime.now(),
          ));
        }
      }
      
      print('🏁 SYNC_COORDINATOR: Sincronización completada - $syncedCount exitosas, $failedCount fallidas');
      
      return SyncResult(
        success: failedCount == 0,
        message: failedCount == 0 
            ? 'Todas las operaciones sincronizadas exitosamente'
            : '$syncedCount operaciones sincronizadas, $failedCount fallidas',
        syncedOperations: syncedCount,
        failedOperations: failedCount,
      );
      
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en sincronización general: $e');
      return SyncResult(
        success: false,
        message: 'Error durante la sincronización: $e',
        syncedOperations: 0,
        failedOperations: 0,
      );
    }
  }

  /// Sincroniza una operación específica
  Future<bool> syncSingleOperation(PendingOperation operation) async {
    try {
      // Marcar como sincronizando
      final syncingOperation = operation.copyWith(status: OperationStatus.syncing);
      await _queueRepository.updateOperation(syncingOperation);
      
      final success = await _syncSingleOperation(operation);
      
      if (success) {
        // Marcar como completada y eliminar de la cola
        final completedOperation = operation.copyWith(status: OperationStatus.completed);
        await _queueRepository.updateOperation(completedOperation);
        await _queueRepository.removeOperation(operation.id);
        return true;
      } else {
        // Marcar como fallida y incrementar contador de reintentos
        final failedOperation = operation.copyWith(
          status: OperationStatus.failed,
          retryCount: operation.retryCount + 1,
          errorMessage: 'Error de sincronización',
        );
        await _queueRepository.updateOperation(failedOperation);
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error sincronizando operación ${operation.id}: $e');
      
      // Marcar como fallida
      final failedOperation = operation.copyWith(
        status: OperationStatus.failed,
        retryCount: operation.retryCount + 1,
        errorMessage: e.toString(),
      );
      await _queueRepository.updateOperation(failedOperation);
      
      return false;
    }
  }

  /// Ejecuta la sincronización de una operación individual
  Future<bool> _syncSingleOperation(PendingOperation operation) async {
    try {
      switch (operation.operation) {
        case 'create':
          return await _syncCreateOperation(operation);
        case 'update':
          return await _syncUpdateOperation(operation);
        case 'delete':
          return await _syncDeleteOperation(operation);
        default:
          print('⚠️ SYNC_COORDINATOR: Operación no soportada: ${operation.operation}');
          return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en _syncSingleOperation: $e');
      return false;
    }
  }

  /// Sincroniza una operación de creación
  Future<bool> _syncCreateOperation(PendingOperation operation) async {
    try {
      final result = await _odooClient.callKw({
        'model': operation.model,
        'method': 'create',
        'args': [operation.data],
        'kwargs': {},
      });
      
      if (result is int && result > 0) {
        print('✅ SYNC_COORDINATOR: Registro creado - ${operation.model} ID: $result');
        return true;
      } else {
        print('❌ SYNC_COORDINATOR: Error creando registro - resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en creación: $e');
      return false;
    }
  }

  /// Sincroniza una operación de actualización
  Future<bool> _syncUpdateOperation(PendingOperation operation) async {
    try {
      final recordId = operation.data['id'];
      if (recordId == null) {
        print('❌ SYNC_COORDINATOR: ID de registro no encontrado en operación de actualización');
        return false;
      }
      
      // Remover el ID de los datos antes de enviar
      final updateData = Map<String, dynamic>.from(operation.data);
      updateData.remove('id');
      
      final result = await _odooClient.callKw({
        'model': operation.model,
        'method': 'write',
        'args': [[recordId], updateData],
        'kwargs': {},
      });
      
      if (result is bool && result) {
        print('✅ SYNC_COORDINATOR: Registro actualizado - ${operation.model} ID: $recordId');
        return true;
      } else {
        print('❌ SYNC_COORDINATOR: Error actualizando registro - resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en actualización: $e');
      return false;
    }
  }

  /// Sincroniza una operación de eliminación
  Future<bool> _syncDeleteOperation(PendingOperation operation) async {
    try {
      final recordId = operation.data['id'];
      if (recordId == null) {
        print('❌ SYNC_COORDINATOR: ID de registro no encontrado en operación de eliminación');
        return false;
      }
      
      final result = await _odooClient.callKw({
        'model': operation.model,
        'method': 'unlink',
        'args': [[recordId]],
        'kwargs': {},
      });
      
      if (result is bool && result) {
        print('✅ SYNC_COORDINATOR: Registro eliminado - ${operation.model} ID: $recordId');
        return true;
      } else {
        print('❌ SYNC_COORDINATOR: Error eliminando registro - resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en eliminación: $e');
      return false;
    }
  }

  /// Programa un reintento para operaciones fallidas
  Future<void> scheduleRetry(PendingOperation operation) async {
    if (!operation.canRetry) {
      print('⚠️ SYNC_COORDINATOR: Operación no puede ser reintentada - ${operation.id}');
      return;
    }
    
    final retryOperation = operation.copyWith(
      status: OperationStatus.pending,
      retryCount: operation.retryCount + 1,
      errorMessage: null,
    );
    
    await _queueRepository.updateOperation(retryOperation);
    print('🔄 SYNC_COORDINATOR: Reintento programado para operación - ${operation.id}');
  }

  /// Obtiene estadísticas de sincronización
  Future<SyncStats> getSyncStats() async {
    final queueStats = await _queueRepository.getQueueStats();
    final isConnected = await isOnline();
    
    return SyncStats(
      totalOperations: queueStats.total,
      pendingOperations: queueStats.pending,
      syncingOperations: queueStats.syncing,
      completedOperations: queueStats.completed,
      failedOperations: queueStats.failed,
      abandonedOperations: queueStats.abandoned,
      isOnline: isConnected,
      lastSyncTime: DateTime.now(), // TODO: Implementar almacenamiento de último sync
    );
  }
}

/// Resultado de una sincronización
class SyncResult {
  final bool success;
  final String message;
  final int syncedOperations;
  final int failedOperations;

  const SyncResult({
    required this.success,
    required this.message,
    required this.syncedOperations,
    required this.failedOperations,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, synced: $syncedOperations, failed: $failedOperations)';
  }
}

/// Progreso de sincronización
class SyncProgress {
  final int currentOperation;
  final int totalOperations;
  final String currentOperationType;
  final String currentModel;

  const SyncProgress({
    required this.currentOperation,
    required this.totalOperations,
    required this.currentOperationType,
    required this.currentModel,
  });

  double get progress => totalOperations > 0 ? currentOperation / totalOperations : 0.0;
}

/// Error de sincronización
class SyncError {
  final PendingOperation operation;
  final String error;
  final DateTime timestamp;

  const SyncError({
    required this.operation,
    required this.error,
    required this.timestamp,
  });
}

/// Estadísticas de sincronización
class SyncStats {
  final int totalOperations;
  final int pendingOperations;
  final int syncingOperations;
  final int completedOperations;
  final int failedOperations;
  final int abandonedOperations;
  final bool isOnline;
  final DateTime lastSyncTime;

  const SyncStats({
    required this.totalOperations,
    required this.pendingOperations,
    required this.syncingOperations,
    required this.completedOperations,
    required this.failedOperations,
    required this.abandonedOperations,
    required this.isOnline,
    required this.lastSyncTime,
  });

  int get activeOperations => pendingOperations + syncingOperations;
  double get successRate => totalOperations > 0 ? (completedOperations / totalOperations) * 100 : 0.0;
}
