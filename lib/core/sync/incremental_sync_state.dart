import 'package:equatable/equatable.dart';

/// Módulos disponibles para sincronización incremental
enum SyncModule {
  partners,
  products,
  employees,
  shippingAddresses,
  saleOrders;

  /// Nombre del modelo en Odoo
  String get modelName {
    switch (this) {
      case SyncModule.partners:
        return 'res.partner';
      case SyncModule.products:
        return 'product.product';
      case SyncModule.employees:
        return 'hr.employee';
      case SyncModule.shippingAddresses:
        return 'res.partner.delivery';
      case SyncModule.saleOrders:
        return 'sale.order';
    }
  }

  /// Nombre para mostrar en UI
  String get displayName {
    switch (this) {
      case SyncModule.partners:
        return 'Partners';
      case SyncModule.products:
        return 'Products';
      case SyncModule.employees:
        return 'Employees';
      case SyncModule.shippingAddresses:
        return 'Shipping Addresses';
      case SyncModule.saleOrders:
        return 'Sale Orders';
    }
  }
}

/// Estado de sincronización de un módulo individual
class ModuleSyncStatus extends Equatable {
  final SyncModule module;
  final int recordsFetched;
  final int recordsMerged;
  final int recordsDeleted;
  final bool completed;
  final String? errorMessage;

  const ModuleSyncStatus({
    required this.module,
    this.recordsFetched = 0,
    this.recordsMerged = 0,
    this.recordsDeleted = 0,
    this.completed = false,
    this.errorMessage,
  });

  ModuleSyncStatus copyWith({
    int? recordsFetched,
    int? recordsMerged,
    int? recordsDeleted,
    bool? completed,
    String? errorMessage,
  }) {
    return ModuleSyncStatus(
      module: module,
      recordsFetched: recordsFetched ?? this.recordsFetched,
      recordsMerged: recordsMerged ?? this.recordsMerged,
      recordsDeleted: recordsDeleted ?? this.recordsDeleted,
      completed: completed ?? this.completed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isSkipped => completed && recordsFetched == 0 && !hasError;

  @override
  List<Object?> get props => [
        module,
        recordsFetched,
        recordsMerged,
        recordsDeleted,
        completed,
        errorMessage,
      ];

  @override
  String toString() {
    if (hasError) return '${module.displayName}: Error - $errorMessage';
    if (isSkipped) return '${module.displayName}: Skipped (no marker)';
    if (!completed) return '${module.displayName}: In progress...';
    return '${module.displayName}: $recordsMerged merged from $recordsFetched fetched';
  }
}

/// Estado global de sincronización incremental
class IncrementalSyncState extends Equatable {
  final Map<SyncModule, ModuleSyncStatus> modules;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const IncrementalSyncState({
    required this.modules,
    this.startedAt,
    this.completedAt,
  });

  /// Verifica si la sincronización está completa
  bool get isCompleted => completedAt != null;

  /// Verifica si hay errores en algún módulo
  bool get hasErrors => modules.values.any((m) => m.errorMessage != null);

  /// Total de registros obtenidos del servidor
  int get totalRecordsFetched =>
      modules.values.fold(0, (sum, m) => sum + m.recordsFetched);

  /// Total de registros actualizados en caché local
  int get totalRecordsMerged =>
      modules.values.fold(0, (sum, m) => sum + m.recordsMerged);

  /// Total de registros eliminados
  int get totalRecordsDeleted =>
      modules.values.fold(0, (sum, m) => sum + m.recordsDeleted);

  /// Progreso global (0.0 - 1.0)
  double get progress {
    if (modules.isEmpty) return 0.0;
    final completed = modules.values.where((m) => m.completed).length;
    return completed / modules.length;
  }

  /// Progreso en porcentaje (0-100)
  int get progressPercent => (progress * 100).round();

  /// Duración de la sincronización
  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Crea un estado inicial con todos los módulos pendientes
  factory IncrementalSyncState.initial() {
    return IncrementalSyncState(
      modules: {
        for (final module in SyncModule.values)
          module: ModuleSyncStatus(module: module),
      },
      startedAt: DateTime.now(),
    );
  }

  /// Marca la sincronización como completada
  IncrementalSyncState complete() {
    return IncrementalSyncState(
      modules: modules,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  /// Actualiza el estado de un módulo específico
  IncrementalSyncState updateModule(
    SyncModule module, {
    int? recordsFetched,
    int? recordsMerged,
    int? recordsDeleted,
    bool? completed,
    String? errorMessage,
  }) {
    final currentStatus = modules[module];
    if (currentStatus == null) return this;

    final updatedStatus = currentStatus.copyWith(
      recordsFetched: recordsFetched,
      recordsMerged: recordsMerged,
      recordsDeleted: recordsDeleted,
      completed: completed,
      errorMessage: errorMessage,
    );

    return IncrementalSyncState(
      modules: {...modules, module: updatedStatus},
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  @override
  List<Object?> get props => [modules, startedAt, completedAt];

  @override
  String toString() {
    final status = isCompleted ? 'Completed' : 'In Progress';
    final errorInfo = hasErrors ? ' (with errors)' : '';
    return 'IncrementalSyncState: $status$errorInfo - '
        '$totalRecordsMerged merged from $totalRecordsFetched fetched - '
        '${progressPercent}%';
  }
}

