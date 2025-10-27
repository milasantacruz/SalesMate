import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/sale_order_repository.dart';
import '../../data/repositories/shipping_address_repository.dart';
import '../../core/tenant/tenant_aware_cache.dart';
import 'sync_marker_store.dart';
import 'incremental_sync_state.dart';

/// Coordinador para sincronización incremental
/// 
/// Responsable de:
/// - Consultar marcadores de última sincronización
/// - Fetch incremental desde el servidor (solo registros modificados)
/// - Merge con caché local
/// - Actualizar marcadores después de sincronización exitosa
class IncrementalSyncCoordinator {
  final PartnerRepository _partnerRepo;
  final ProductRepository _productRepo;
  final EmployeeRepository _employeeRepo;
  final SaleOrderRepository _saleOrderRepo;
  final ShippingAddressRepository _shippingAddressRepo;
  final SyncMarkerStore _markerStore;
  final TenantAwareCache _tenantCache;

  /// Callback para reportar progreso en tiempo real
  Function(IncrementalSyncState)? onProgress;

  /// Estado actual de la sincronización
  late IncrementalSyncState _currentState;

  IncrementalSyncCoordinator({
    required PartnerRepository partnerRepo,
    required ProductRepository productRepo,
    required EmployeeRepository employeeRepo,
    required SaleOrderRepository saleOrderRepo,
    required ShippingAddressRepository shippingAddressRepo,
    required SyncMarkerStore markerStore,
    required TenantAwareCache tenantCache,
  })  : _partnerRepo = partnerRepo,
        _productRepo = productRepo,
        _employeeRepo = employeeRepo,
        _saleOrderRepo = saleOrderRepo,
        _shippingAddressRepo = shippingAddressRepo,
        _markerStore = markerStore,
        _tenantCache = tenantCache;

  /// Ejecuta sincronización incremental para todos los módulos
  /// 
  /// Retorna el estado final de la sincronización.
  /// Si no hay marcadores, omite la sincronización (usar bootstrap completo).
  Future<IncrementalSyncState> run() async {
    print('🔄 INCREMENTAL_SYNC: ===== INICIANDO SINCRONIZACIÓN INCREMENTAL =====');
    
    // Obtener el marcador más antiguo para mostrar la fecha de inicio
    final oldestMarker = _markerStore.getOldestMarker();
    if (oldestMarker != null) {
      print('🔄 INCREMENTAL_SYNC: Sincronizando cambios desde ${oldestMarker.toLocal()}');
    }

    _currentState = IncrementalSyncState.initial();
    _report();

    try {
      // Ejecutar sincronización de todos los módulos en paralelo
      await Future.wait(
        [
          _syncModule(SyncModule.partners),
          _syncModule(SyncModule.products),
          _syncModule(SyncModule.employees),
          _syncModule(SyncModule.shippingAddresses),
          _syncModule(SyncModule.saleOrders),
        ],
        eagerError: false, // No fallar todo si un módulo falla
      );

      _currentState = _currentState.complete();
      _report();

      print('✅ INCREMENTAL_SYNC: ===== COMPLETADO =====');
      print('📊 INCREMENTAL_SYNC: ${_currentState.totalRecordsMerged} registros actualizados de ${_currentState.totalRecordsFetched} obtenidos');
      print('⏱️ INCREMENTAL_SYNC: Duración: ${_currentState.duration?.inSeconds}s');

      return _currentState;
    } catch (e) {
      print('❌ INCREMENTAL_SYNC: Error general: $e');
      _currentState = _currentState.complete();
      _report();
      return _currentState;
    }
  }

  /// Sincroniza un módulo específico
  Future<void> _syncModule(SyncModule module) async {
    print('🔄 INCREMENTAL_SYNC [${module.displayName}]: Iniciando...');

    try {
      // 1. Obtener marcador de última sincronización
      final lastSync = _markerStore.getMarker(module.modelName);
      
      if (lastSync == null) {
        print('⚠️ INCREMENTAL_SYNC [${module.displayName}]: No hay marcador - omitiendo sync incremental');
        print('   💡 Sugerencia: Ejecutar bootstrap completo primero');
        _currentState = _currentState.updateModule(module, completed: true);
        _report();
        return;
      }

      final timeSinceLastSync = DateTime.now().difference(lastSync);
      print('🔄 INCREMENTAL_SYNC [${module.displayName}]: Último sync: $lastSync (hace ${timeSinceLastSync.inMinutes} minutos)');
      print('🔄 INCREMENTAL_SYNC [${module.displayName}]: Sincronizando cambios desde ${lastSync.toLocal()}');

      // 2. Fetch incremental desde el servidor
      final incrementalRecords = await _fetchIncrementalRecords(module, lastSync);
      print('🔄 INCREMENTAL_SYNC [${module.displayName}]: ${incrementalRecords.length} registros obtenidos');

      _currentState = _currentState.updateModule(
        module,
        recordsFetched: incrementalRecords.length,
      );
      _report();

      // 3. Merge con caché local (solo si hay registros nuevos)
      int mergedCount = 0;
      if (incrementalRecords.isNotEmpty) {
        mergedCount = await _mergeWithCache(module, incrementalRecords);
        print('🔄 INCREMENTAL_SYNC [${module.displayName}]: $mergedCount registros actualizados en caché');
      } else {
        print('✅ INCREMENTAL_SYNC [${module.displayName}]: Sin cambios desde último sync');
      }

      // 4. Actualizar marcador
      final newMarker = DateTime.now().toUtc();
      await _markerStore.setMarker(module.modelName, newMarker);

      // 5. Actualizar estado final
      _currentState = _currentState.updateModule(
        module,
        recordsMerged: mergedCount,
        completed: true,
      );
      _report();

      print('✅ INCREMENTAL_SYNC [${module.displayName}]: Completado');
    } catch (e) {
      print('❌ INCREMENTAL_SYNC [${module.displayName}]: Error: $e');
      _currentState = _currentState.updateModule(
        module,
        errorMessage: e.toString(),
        completed: true, // Marcamos como completado (con error) para no bloquear otros módulos
      );
      _report();
    }
  }

  /// Fetch incremental desde el servidor para un módulo
  /// 
  /// Retorna registros modificados desde [since] (write_date > since)
  Future<List<Map<String, dynamic>>> _fetchIncrementalRecords(
    SyncModule module,
    DateTime since,
  ) async {
    // Formato ISO8601 en UTC (compatible con Odoo)
    final sinceStr = since.toUtc().toIso8601String();

    switch (module) {
      case SyncModule.partners:
        return await _partnerRepo.fetchIncrementalRecords(sinceStr);
      case SyncModule.products:
        return await _productRepo.fetchIncrementalRecords(sinceStr);
      case SyncModule.employees:
        return await _employeeRepo.fetchIncrementalRecords(sinceStr);
      case SyncModule.shippingAddresses:
        return await _shippingAddressRepo.fetchIncrementalRecords(sinceStr);
      case SyncModule.saleOrders:
        return await _saleOrderRepo.fetchIncrementalRecords(sinceStr);
    }
  }

  /// Merge de registros incrementales con caché local
  /// 
  /// Estrategia: ServerWins (sobrescribe local con datos del servidor)
  /// Retorna el número de registros actualizados/agregados
  Future<int> _mergeWithCache(
    SyncModule module,
    List<Map<String, dynamic>> incrementalRecords,
  ) async {
    if (incrementalRecords.isEmpty) return 0;

    // Determinar cache key según el módulo
    String cacheKey;
    switch (module) {
      case SyncModule.partners:
        cacheKey = 'Partner_records';
        break;
      case SyncModule.products:
        cacheKey = 'Product_records';
        break;
      case SyncModule.employees:
        cacheKey = 'Employee_records';
        break;
      case SyncModule.shippingAddresses:
        cacheKey = 'ShippingAddress_records';
        break;
      case SyncModule.saleOrders:
        cacheKey = 'sale_orders';
        break;
    }

    print('🔄 INCREMENTAL_SYNC [${module.displayName}]: Mergeando con cache key "$cacheKey"');

    // 1. Cargar caché actual usando tenant-aware cache
    final cachedData = _tenantCache.get(cacheKey, defaultValue: <Map<String, dynamic>>[]);
    final List<Map<String, dynamic>> cachedRecords = cachedData is List
        ? List<Map<String, dynamic>>.from(
            (cachedData as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    print('🔄 INCREMENTAL_SYNC [${module.displayName}]: ${cachedRecords.length} registros en caché actual');

    // 2. Crear un mapa de ID → registro para merge rápido O(1)
    final cachedMap = <int, Map<String, dynamic>>{
      for (final record in cachedRecords)
        if (record['id'] is int) record['id'] as int: record,
    };

    int mergedCount = 0;

    // 3. Merge: actualizar existentes o agregar nuevos
    for (final incrementalRecord in incrementalRecords) {
      final id = incrementalRecord['id'];
      if (id is int) {
        final isNew = !cachedMap.containsKey(id);
        cachedMap[id] = incrementalRecord; // Sobrescribe (serverWins) o agrega (nuevo)
        mergedCount++;
        
        if (isNew) {
          print('  ➕ INCREMENTAL_SYNC [${module.displayName}]: Nuevo registro agregado - ID: $id');
        } else {
          print('  🔄 INCREMENTAL_SYNC [${module.displayName}]: Registro actualizado - ID: $id');
        }
      }
    }

    // 4. Guardar caché actualizada usando tenant-aware cache
    final updatedCache = cachedMap.values.toList();
    await _tenantCache.put(cacheKey, updatedCache);
    
    print('✅ INCREMENTAL_SYNC [${module.displayName}]: Cache actualizado - ${updatedCache.length} registros totales');

    return mergedCount;
  }

  /// Reporta progreso al callback si está configurado
  void _report() {
    if (onProgress != null) {
      onProgress!(_currentState);
    }
  }

  /// Verifica si hay marcadores de sincronización
  /// 
  /// Si no hay marcadores, significa que nunca se hizo bootstrap completo
  /// y se debe ejecutar bootstrap en lugar de sync incremental
  bool hasMarkers() {
    return _markerStore.hasAnyMarker();
  }

  /// Obtiene estadísticas de los marcadores actuales
  Map<String, DateTime?> getMarkerStats() {
    return {
      for (final module in SyncModule.values)
        module.displayName: _markerStore.getMarker(module.modelName),
    };
  }
}

