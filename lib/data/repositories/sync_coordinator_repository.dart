import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:odoo_repository/odoo_repository.dart';
import '../../core/network/network_connectivity.dart';
import '../../core/tenant/tenant_aware_cache.dart';
import '../models/pending_operation_model.dart';
import 'operation_queue_repository.dart';

/// Repository para coordinar la sincronización de operaciones offline
class SyncCoordinatorRepository {
  final NetworkConnectivity _networkConnectivity;
  final OperationQueueRepository _queueRepository;
  final OdooClient _odooClient;
  final TenantAwareCache _tenantCache;
  
  /// Callback para notificar cambios de estado
  Function(SyncProgress)? onProgressChanged;
  
  /// Callback para notificar errores
  Function(SyncError)? onError;

  SyncCoordinatorRepository({
    required NetworkConnectivity networkConnectivity,
    required OperationQueueRepository queueRepository,
    required OdooClient odooClient,
    required TenantAwareCache tenantCache,
  }) : _networkConnectivity = networkConnectivity,
       _queueRepository = queueRepository,
       _odooClient = odooClient,
       _tenantCache = tenantCache;

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
    // Log de contexto de tenant/keys
    try {
      final dbg = _tenantCache.getDebugInfo();
      print('🧭 SYNC_COORDINATOR: Tenant actual=${dbg['currentTenant']}, keysTenant=${dbg['currentTenantKeys']}, totalKeys=${dbg['totalKeys']}');
    } catch (_) {}
    
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
      
      print('📋 SYNC_COORDINATOR: ${activeOperations.length} operaciones pendientes encontradas (total=${pendingOperations.length})');
      
      if (activeOperations.isEmpty) {
        return SyncResult(
          success: true,
          message: 'No hay operaciones pendientes',
          syncedOperations: 0,
          failedOperations: 0,
        );
      }

      // NUEVO: Ordenar operaciones por dependencias (direcciones antes de orders)
      final sortedOperations = _sortByDependencies(activeOperations);
      print('🔀 SYNC_COORDINATOR: Operaciones ordenadas: ${sortedOperations.length}');
      for (final op in sortedOperations) {
        print('   - ${op.operation} ${op.model}');
      }

      int syncedCount = 0;
      int failedCount = 0;
      
      for (int i = 0; i < sortedOperations.length; i++) {
        final operation = sortedOperations[i];
        
        // Notificar progreso
        onProgressChanged?.call(SyncProgress(
          currentOperation: i + 1,
          totalOperations: sortedOperations.length,
          currentOperationType: operation.operation,
          currentModel: operation.model,
        ));
        
        try {
          final success = await _syncSingleOperationWithDependencyResolution(operation);
          if (success) {
            syncedCount++;
            print('✅ SYNC_COORDINATOR: Operación sincronizada - ${operation.id}');
            
            // Eliminar operación de la cola después de sincronización exitosa
            await _queueRepository.removeOperation(operation.id);
            print('🗑️ SYNC_COORDINATOR: Operación eliminada de la cola');
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

  /// Helper method to sort operations by dependencies
  /// Rule: res.partner (delivery addresses) must be created before sale.order
  List<PendingOperation> _sortByDependencies(List<PendingOperation> operations) {
    // Separate operations by model
    final addressOps = operations.where((op) => op.model == 'res.partner').toList();
    final saleOrderOps = operations.where((op) => op.model == 'sale.order').toList();
    final otherOps = operations.where((op) => 
      op.model != 'res.partner' && op.model != 'sale.order').toList();
    
    // Return sorted: addresses first, then sale orders, then others
    return [...addressOps, ...saleOrderOps, ...otherOps];
  }

  /// Maps temporary IDs to real IDs during sync
  final Map<int, int> _tempIdToRealId = {};

  /// Sync operation with dependency resolution
  Future<bool> _syncSingleOperationWithDependencyResolution(PendingOperation operation) async {
    // NUEVO: Resolver dependencias antes de sincronizar
    if (operation.model == 'sale.order') {
      print('🔍 SYNC_COORDINATOR: Resolviendo dependencias para sale.order...');
      
      // Verificar si hay un partner_shipping_id (dirección) que debe crearse primero
      final shippingId = operation.data['partner_shipping_id'];
      if (shippingId is int && shippingId < 0) {
        print('🔍 SYNC_COORDINATOR: Detectado ID temporal: $shippingId');
        
        // Verificar si ya tenemos el ID real mapeado (desde la sincronización anterior de la dirección)
        if (_tempIdToRealId.containsKey(shippingId)) {
          final realId = _tempIdToRealId[shippingId]!;
          operation.data['partner_shipping_id'] = realId;
          print('✅ SYNC_COORDINATOR: ID temporal $shippingId → real $realId');
        } else {
          print('⚠️ SYNC_COORDINATOR: ID temporal $shippingId no encontrado en cache');
          print('🔄 SYNC_COORDINATOR: Eliminando partner_shipping_id temporal');
          operation.data.remove('partner_shipping_id');
          print('✅ SYNC_COORDINATOR: partner_shipping_id eliminado - orden se creará sin dirección');
        }
      }
    }
    
    // Continuar con la sincronización normal
    return await _syncSingleOperation(operation);
  }

  /// Sincroniza una operación de creación
  Future<bool> _syncCreateOperation(PendingOperation operation) async {
    try {
      // Eliminar ID temporal antes de enviar (si existe)
      final createData = Map<String, dynamic>.from(operation.data);
      int? tempId;
      
      // Extraer el ID temporal (si existe)
      if (createData.containsKey('id') && createData['id'] is int) {
        tempId = createData.remove('id') as int?;
        print('📍 SYNC_COORDINATOR: ID temporal removido: $tempId');
      }
      
      // ✅ FILTRAR: Remover campos de enriquecimiento que Odoo no acepta
      if (operation.model == 'sale.order') {
        createData.remove('partner_name');
        createData.remove('partner_shipping_name');
        // ✅ FILTRAR: Campo solo para cache offline
        if (createData.containsKey('order_lines')) {
          createData.remove('order_lines');
          print('🧹 SYNC_COORDINATOR: order_lines removido del payload (solo cache)');
        }
        print('🧹 SYNC_COORDINATOR: Campos de enriquecimiento removidos para sale.order');
      }
      
      final result = await _odooClient.callKw({
        'model': operation.model,
        'method': 'create',
        'args': [createData],
        'kwargs': {},
      });
      
      if (result is int && result > 0) {
        print('✅ SYNC_COORDINATOR: Registro creado - ${operation.model} ID: $result');
        
        // Mapear ID temporal a ID real para dependencias
        if (tempId != null && tempId < 0) {
          _tempIdToRealId[tempId] = result;
          print('📍 SYNC_COORDINATOR: ID temporal $tempId → real $result');
        }
        
        // Actualizar cache local según el modelo
        if (operation.model == 'sale.order') {
          await _updateSaleOrderCache(tempId, result, createData);
        } else if (operation.model == 'res.partner') {
          // ✅ INCREMENTO 2: Actualizar cache usando tempId si existe
          await _updateAddressCache(result, tempId: tempId);
        }
        
        return true;
      } else {
        print('❌ SYNC_COORDINATOR: Error creando registro - resultado inválido: $result');
        await _logSyncError(operation, 'Resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en creación: $e');
      await _logSyncError(operation, e);
      return false;
    }
  }

  /// Actualiza cache local de sale orders después de sincronización
  Future<void> _updateSaleOrderCache(int? tempId, int serverId, Map<String, dynamic> orderData) async {
    try {
      if (tempId == null) {
        print('⚠️ SYNC_COORDINATOR: No hay ID temporal para actualizar');
        return;
      }
      
      final cacheKey = 'sale_orders';
      final cachedData = _tenantCache.get(cacheKey, defaultValue: []);
      
      if (cachedData != null) {
        final index = cachedData.indexWhere((o) => o is Map && o['id'] == tempId);
        if (index >= 0) {
          // Actualizar con ID real
          final updatedOrder = Map<String, dynamic>.from(cachedData[index])
            ..['id'] = serverId
            ..['state'] = 'sent';
          
          cachedData[index] = updatedOrder;
          
          // Guardar de vuelta
          await _tenantCache.put(cacheKey, cachedData);
          
          print('✅ SYNC_COORDINATOR: Cache actualizado: sale.order temporal $tempId → real $serverId');
        } else {
          print('⚠️ SYNC_COORDINATOR: No se encontró orden temporal $tempId en cache');
        }
      }
    } catch (e) {
      print('⚠️ SYNC_COORDINATOR: Error actualizando cache de sale orders: $e');
    }
  }
  
  /// ✅ INCREMENTO 2: Actualiza el cache local con una dirección recién creada
  /// Si hay tempId, reemplaza el ID temporal con el real
  Future<void> _updateAddressCache(int addressId, {int? tempId}) async {
    try {
      print('🔄 SYNC_COORDINATOR: Actualizando cache local con dirección $addressId${tempId != null ? " (tempId: $tempId)" : ""}');
      
      // Leer la dirección recién creada del servidor
      final readResponse = await _odooClient.callKw({
        'model': 'res.partner',
        'method': 'read',
        'args': [[addressId]],
        'kwargs': {
          'fields': ['id', 'name', 'email', 'phone', 'is_company', 'customer_rank', 'supplier_rank', 
                     'active', 'type', 'parent_id', 'commercial_partner_id', 'street', 'street2', 
                     'city', 'city_id', 'state_id', 'country_id', 'zip']
        },
      });
      
      if (readResponse is List && readResponse.isNotEmpty) {
        final addressJson = readResponse.first as Map<String, dynamic>;
        
        // Obtener direcciones del cache
        final cachedData = _tenantCache.get('ShippingAddress_records', 
          defaultValue: <Map<String, dynamic>>[]);
        final List<Map<String, dynamic>> currentAddresses = cachedData is List
            ? List<Map<String, dynamic>>.from((cachedData as List).map((e) => Map<String, dynamic>.from(e as Map)))
            : [];
        
        // ✅ INCREMENTO 2: Si hay tempId, buscar y reemplazar ID temporal
        if (tempId != null && tempId < 0) {
          final tempIndex = currentAddresses.indexWhere((a) => a['id'] == tempId);
          if (tempIndex >= 0) {
            // Reemplazar dirección temporal con la real
            currentAddresses[tempIndex] = addressJson;
            print('✅ SYNC_COORDINATOR: Dirección temporal $tempId reemplazada con ID real $addressId');
          } else {
            // No se encontró temporal, agregar como nueva
            currentAddresses.add(addressJson);
            print('⚠️ SYNC_COORDINATOR: No se encontró dirección temporal $tempId, agregando como nueva');
          }
        } else {
          // Sin tempId: verificar si la dirección ya existe en el cache
          final existingIndex = currentAddresses.indexWhere((a) => a['id'] == addressId);
          
          if (existingIndex >= 0) {
            // Actualizar dirección existente
            currentAddresses[existingIndex] = addressJson;
            print('🔄 SYNC_COORDINATOR: Dirección $addressId actualizada en cache');
          } else {
            // Agregar nueva dirección
            currentAddresses.add(addressJson);
            print('✅ SYNC_COORDINATOR: Dirección $addressId agregada al cache');
          }
        }
        
        // Guardar cache actualizado
        await _tenantCache.put('ShippingAddress_records', currentAddresses);
        print('✅ SYNC_COORDINATOR: Cache actualizado (total: ${currentAddresses.length})');
      }
    } catch (e) {
      print('⚠️ SYNC_COORDINATOR: Error actualizando cache de dirección: $e');
    }
  }

  /// ✅ INCREMENTO 1: Registra errores de sincronización en cache para debugging
  Future<void> _logSyncError(PendingOperation operation, dynamic error) async {
    try {
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'model': operation.model,
        'operation': operation.operation,
        'error': error.toString(),
        'data': operation.data.toString().length > 200 
            ? operation.data.toString().substring(0, 200) + '...'
            : operation.data.toString(),
      };
      
      // Obtener logs actuales desde tenantCache
      final cacheKey = 'sync_error_logs';
      List<dynamic> logs = _tenantCache.get(cacheKey, defaultValue: []) as List? ?? [];
      
      // Agregar nuevo error
      logs.add(logEntry);
      
      // Mantener solo últimos 50
      if (logs.length > 50) {
        logs.removeAt(0);
      }
      
      // Guardar en cache
      await _tenantCache.put(cacheKey, logs);
      
      print('❌ SYNC_ERROR: ${operation.model} ${operation.operation} - $error');
    } catch (e) {
      print('⚠️ SYNC_COORDINATOR: Error guardando log de error: $e');
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
        await _logSyncError(operation, 'Resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en actualización: $e');
      await _logSyncError(operation, e);
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
        await _logSyncError(operation, 'Resultado inválido: $result');
        return false;
      }
    } catch (e) {
      print('❌ SYNC_COORDINATOR: Error en eliminación: $e');
      await _logSyncError(operation, e);
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
