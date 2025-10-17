import '../bootstrap/bootstrap_state.dart';
import 'incremental_sync_state.dart';

/// Utilidades para convertir entre estados de Bootstrap e Incremental Sync
/// 
/// Esto permite que el UI use siempre BootstrapState, independientemente
/// de si se está ejecutando un bootstrap completo o un sync incremental
class SyncStateConverter {
  /// Convierte IncrementalSyncState a BootstrapState para compatibilidad con UI
  /// 
  /// El mapping es:
  /// - SyncModule.partners → BootstrapModule.partners
  /// - SyncModule.products → BootstrapModule.products
  /// - SyncModule.employees → BootstrapModule.employees
  /// - SyncModule.saleOrders → BootstrapModule.saleOrders
  /// 
  /// Los campos que no existen en IncrementalSync se mapean así:
  /// - completedPages: 1 si completed, 0 si no
  /// - totalPages: 1 (siempre completo en una "página" para incremental)
  /// - recordsFetched: recordsMerged (lo que se descargó)
  static BootstrapState fromIncrementalSync(IncrementalSyncState incrementalState) {
    final bootstrapModules = <BootstrapModule, ModuleBootstrapStatus>{};
    
    // Convertir cada módulo
    for (final entry in incrementalState.modules.entries) {
      final syncModule = entry.key;
      final syncStatus = entry.value;
      
      // Mapear SyncModule a BootstrapModule
      final bootstrapModule = _mapSyncModuleToBootstrapModule(syncModule);
      if (bootstrapModule == null) continue; // Skip si no hay mapping
      
      // Convertir estado del módulo
      final bootstrapStatus = ModuleBootstrapStatus(
        module: bootstrapModule,
        completedPages: syncStatus.completed ? 1 : 0,
        totalPages: 1, // Incremental sync siempre es "1 página"
        recordsFetched: syncStatus.recordsMerged, // Lo que se actualizó
        completed: syncStatus.completed,
        errorMessage: syncStatus.errorMessage,
      );
      
      bootstrapModules[bootstrapModule] = bootstrapStatus;
    }
    
    return BootstrapState(
      modules: bootstrapModules,
      startedAt: incrementalState.startedAt ?? DateTime.now(),
      completedAt: incrementalState.completedAt,
    );
  }
  
  /// Mapea SyncModule a BootstrapModule
  static BootstrapModule? _mapSyncModuleToBootstrapModule(SyncModule syncModule) {
    switch (syncModule) {
      case SyncModule.partners:
        return BootstrapModule.partners;
      case SyncModule.products:
        return BootstrapModule.products;
      case SyncModule.employees:
        return BootstrapModule.employees;
      case SyncModule.saleOrders:
        return BootstrapModule.saleOrders;
    }
  }
  
  /// Crea un BootstrapState inicial para mostrar antes de decidir
  /// entre bootstrap o incremental
  static BootstrapState initialDeciding() {
    return BootstrapState(
      modules: {
        for (final module in [
          BootstrapModule.partners,
          BootstrapModule.products,
          BootstrapModule.employees,
          BootstrapModule.saleOrders,
        ])
          module: ModuleBootstrapStatus(
            module: module,
            completedPages: 0,
            totalPages: -1,
            recordsFetched: 0,
            completed: false,
          ),
      },
      startedAt: DateTime.now(),
    );
  }
}

