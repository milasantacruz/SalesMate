import 'package:equatable/equatable.dart';

/// Módulos soportados por el bootstrap de caché
enum BootstrapModule {
  partners,
  products,
  employees,
  saleOrders,
  shippingAddresses,
  pricelists,
  cities,
}

/// Estado por módulo
class ModuleBootstrapStatus extends Equatable {
  final BootstrapModule module;
  final int completedPages;
  final int totalPages; // -1 si es desconocido
  final int recordsFetched;
  final bool completed;
  final String? errorMessage;

  const ModuleBootstrapStatus({
    required this.module,
    this.completedPages = 0,
    this.totalPages = -1,
    this.recordsFetched = 0,
    this.completed = false,
    this.errorMessage,
  });

  double get progress {
    if (completed) return 1.0;
    if (totalPages <= 0) return completedPages > 0 ? 0.5 : 0.0;
    return (completedPages / totalPages).clamp(0.0, 1.0);
  }

  ModuleBootstrapStatus copyWith({
    int? completedPages,
    int? totalPages,
    int? recordsFetched,
    bool? completed,
    String? errorMessage,
  }) {
    return ModuleBootstrapStatus(
      module: module,
      completedPages: completedPages ?? this.completedPages,
      totalPages: totalPages ?? this.totalPages,
      recordsFetched: recordsFetched ?? this.recordsFetched,
      completed: completed ?? this.completed,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        module,
        completedPages,
        totalPages,
        recordsFetched,
        completed,
        errorMessage,
      ];
}

/// Estado global del bootstrap
class BootstrapState extends Equatable {
  final Map<BootstrapModule, ModuleBootstrapStatus> modules;
  final DateTime startedAt;
  final DateTime? completedAt;

  const BootstrapState({
    required this.modules,
    required this.startedAt,
    this.completedAt,
  });

  double get totalProgress {
    if (modules.isEmpty) return 0.0;
    final sum = modules.values.fold<double>(0.0, (p, m) => p + m.progress);
    return (sum / modules.length).clamp(0.0, 1.0);
  }

  bool get isCompleted =>
      modules.values.every((m) => m.completed) && completedAt != null;

  BootstrapState copyWith({
    Map<BootstrapModule, ModuleBootstrapStatus>? modules,
    DateTime? completedAt,
  }) {
    return BootstrapState(
      modules: modules ?? this.modules,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [modules, startedAt, completedAt];
}


