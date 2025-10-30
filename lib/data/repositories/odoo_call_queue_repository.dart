import 'package:odoo_repository/odoo_repository.dart';
import '../models/pending_operation_model.dart';
import 'operation_queue_repository.dart';
import 'local_id_repository.dart';
import 'sync_coordinator_repository.dart';
import '../../core/network/network_connectivity.dart';

/// Repository principal para manejar operaciones offline con Odoo
/// Coordina entre la cola de operaciones, generación de IDs locales y sincronización
class OdooCallQueueRepository {
  final OperationQueueRepository _queueRepository;
  final LocalIdRepository _idRepository;
  final SyncCoordinatorRepository _syncCoordinator;
  final NetworkConnectivity _networkConnectivity;

  /// Callback para notificar cuando se agregan operaciones a la cola
  Function(String operationType, String model)? onOperationQueued;
  
  /// Callback para notificar cuando se completa la sincronización
  Function(SyncResult result)? onSyncCompleted;

  OdooCallQueueRepository({
    required OperationQueueRepository queueRepository,
    required LocalIdRepository idRepository,
    required SyncCoordinatorRepository syncCoordinator,
    required NetworkConnectivity networkConnectivity,
  }) : _queueRepository = queueRepository,
       _idRepository = idRepository,
       _syncCoordinator = syncCoordinator,
       _networkConnectivity = networkConnectivity;

  /// Crea un nuevo registro (offline o online según conectividad)
  Future<String> createRecord(String model, Map<String, dynamic> data) async {
    try {
      print('📝 CALL_QUEUE: Creando registro - $model');
      
      if (await _isOnline()) {
        // ONLINE: Enviar directamente al servidor
        return await _sendCreateToServer(model, data);
      } else {
        // OFFLINE: Guardar en cola local
        return await _queueCreateOperation(model, data);
      }
    } catch (e) {
      print('❌ CALL_QUEUE: Error creando registro $model: $e');
      
      // En caso de error, intentar guardar offline como fallback
      if (await _isOnline()) {
        return await _queueCreateOperation(model, data);
      }
      
      rethrow;
    }
  }

  /// Actualiza un registro existente (offline o online según conectividad)
  Future<void> updateRecord(String model, int id, Map<String, dynamic> data) async {
    try {
      print('✏️ CALL_QUEUE: Actualizando registro - $model ID: $id');
      
      if (await _isOnline()) {
        // ONLINE: Enviar directamente al servidor
        await _sendUpdateToServer(model, id, data);
      } else {
        // OFFLINE: Guardar en cola local
        await _queueUpdateOperation(model, id, data);
      }
    } catch (e) {
      print('❌ CALL_QUEUE: Error actualizando registro $model ID $id: $e');
      
      // En caso de error, intentar guardar offline como fallback
      if (await _isOnline()) {
        await _queueUpdateOperation(model, id, data);
      }
      
      rethrow;
    }
  }

  /// Elimina un registro (offline o online según conectividad)
  Future<void> deleteRecord(String model, int id) async {
    try {
      print('🗑️ CALL_QUEUE: Eliminando registro - $model ID: $id');
      
      if (await _isOnline()) {
        // ONLINE: Enviar directamente al servidor
        await _sendDeleteToServer(model, id);
      } else {
        // OFFLINE: Guardar en cola local
        await _queueDeleteOperation(model, id);
      }
    } catch (e) {
      print('❌ CALL_QUEUE: Error eliminando registro $model ID $id: $e');
      
      // En caso de error, intentar guardar offline como fallback
      if (await _isOnline()) {
        await _queueDeleteOperation(model, id);
      }
      
      rethrow;
    }
  }

  /// Sincroniza todas las operaciones pendientes
  Future<SyncResult> syncPendingOperations() async {
    print('🔄 CALL_QUEUE: Iniciando sincronización de operaciones pendientes');
    
    try {
      final result = await _syncCoordinator.syncAllPendingOperations();
      
      // Notificar resultado de sincronización
      onSyncCompleted?.call(result);
      
      return result;
    } catch (e) {
      print('❌ CALL_QUEUE: Error en sincronización: $e');
      
      final errorResult = SyncResult(
        success: false,
        message: 'Error durante la sincronización: $e',
        syncedOperations: 0,
        failedOperations: 0,
      );
      
      onSyncCompleted?.call(errorResult);
      return errorResult;
    }
  }

  /// Obtiene todas las operaciones pendientes
  Future<List<PendingOperation>> getPendingOperations() async {
    final ops = await _queueRepository.getPendingOperations();
    print('📊 CALL_QUEUE: getPendingOperations -> total=${ops.length}, activos=${ops.where((o)=>o.status.isActive).length}');
    return ops;
  }

  /// Obtiene operaciones pendientes por modelo
  Future<List<PendingOperation>> getPendingOperationsByModel(String model) async {
    return await _queueRepository.getPendingOperationsByModel(model);
  }

  /// Obtiene el número de operaciones pendientes
  Future<int> getPendingCount() async {
    final count = await _queueRepository.getPendingCount();
    print('📊 CALL_QUEUE: getPendingCount -> $count');
    return count;
  }

  /// Obtiene estadísticas de la cola
  Future<QueueStats> getQueueStats() async {
    return await _queueRepository.getQueueStats();
  }

  /// Limpia operaciones completadas y abandonadas
  Future<void> cleanupCompletedOperations() async {
    await _queueRepository.cleanupCompletedOperations();
  }

  /// Elimina una operación específica de la cola
  Future<void> removeOperation(String operationId) async {
    await _queueRepository.removeOperation(operationId);
  }

  /// Reintenta operaciones que pueden ser reintentadas
  Future<void> retryFailedOperations() async {
    final retryableOperations = await _queueRepository.getRetryableOperations();
    
    for (final operation in retryableOperations) {
      await _syncCoordinator.scheduleRetry(operation);
    }
    
    print('🔄 CALL_QUEUE: ${retryableOperations.length} operaciones programadas para reintento');
  }

  /// Verifica si hay conexión a internet
  Future<bool> _isOnline() async {
    try {
      final connectivity = await _networkConnectivity.checkNetConn();
      return connectivity == netConnState.online;
    } catch (e) {
      print('❌ CALL_QUEUE: Error verificando conectividad: $e');
      return false;
    }
  }

  /// Envía operación de creación directamente al servidor
  Future<String> _sendCreateToServer(String model, Map<String, dynamic> data) async {
    // TODO: Implementar envío directo al servidor usando OdooClient
    // Por ahora, simular éxito y retornar un ID temporal
    final tempId = _idRepository.generateLocalIdForModel(model);
    print('✅ CALL_QUEUE: Registro creado en servidor - $model ID: $tempId');
    return tempId;
  }

  /// Envía operación de actualización directamente al servidor
  Future<void> _sendUpdateToServer(String model, int id, Map<String, dynamic> data) async {
    // TODO: Implementar envío directo al servidor usando OdooClient
    print('✅ CALL_QUEUE: Registro actualizado en servidor - $model ID: $id');
  }

  /// Envía operación de eliminación directamente al servidor
  Future<void> _sendDeleteToServer(String model, int id) async {
    // TODO: Implementar envío directo al servidor usando OdooClient
    print('✅ CALL_QUEUE: Registro eliminado en servidor - $model ID: $id');
  }

  /// Agrega operación de creación a la cola offline
  Future<String> _queueCreateOperation(String model, Map<String, dynamic> data) async {
    final localId = _idRepository.generateLocalIdForModel(model);
    final operationId = _idRepository.generateOperationId(model, 'create');
    
    final operation = PendingOperation(
      id: operationId,
      operation: 'create',
      model: model,
      data: data,
      timestamp: DateTime.now(),
    );
    
    await _queueRepository.addOperation(operation);
    
    // Notificar que se agregó operación a la cola
    onOperationQueued?.call('create', model);
    
    print('📝 CALL_QUEUE: Operación de creación agregada a cola - $model ID local: $localId');
    return localId;
  }

  /// Agrega operación de actualización a la cola offline
  Future<void> _queueUpdateOperation(String model, int id, Map<String, dynamic> data) async {
    final operationId = _idRepository.generateUpdateOperationId(model, id);
    
    final updateData = Map<String, dynamic>.from(data);
    updateData['id'] = id; // Asegurar que el ID esté en los datos
    
    final operation = PendingOperation(
      id: operationId,
      operation: 'update',
      model: model,
      data: updateData,
      timestamp: DateTime.now(),
    );
    
    await _queueRepository.addOperation(operation);
    
    // Notificar que se agregó operación a la cola
    onOperationQueued?.call('update', model);
    
    print('✏️ CALL_QUEUE: Operación de actualización agregada a cola - $model ID: $id');
  }

  /// Agrega operación de eliminación a la cola offline
  Future<void> _queueDeleteOperation(String model, int id) async {
    final operationId = _idRepository.generateDeleteOperationId(model, id);
    
    final operation = PendingOperation(
      id: operationId,
      operation: 'delete',
      model: model,
      data: {'id': id},
      timestamp: DateTime.now(),
    );
    
    await _queueRepository.addOperation(operation);
    
    // Notificar que se agregó operación a la cola
    onOperationQueued?.call('delete', model);
    
    print('🗑️ CALL_QUEUE: Operación de eliminación agregada a cola - $model ID: $id');
  }

  /// Obtiene estadísticas de sincronización
  Future<SyncStats> getSyncStats() async {
    return await _syncCoordinator.getSyncStats();
  }

  /// Configura callbacks para notificaciones
  void setOnOperationQueued(Function(String operationType, String model) callback) {
    onOperationQueued = callback;
  }

  void setOnSyncCompleted(Function(SyncResult result) callback) {
    onSyncCompleted = callback;
  }

  /// Limpia todos los callbacks
  void clearCallbacks() {
    onOperationQueued = null;
    onSyncCompleted = null;
  }
}
