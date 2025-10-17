import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bootstrap/bootstrap_coordinator.dart';
import '../../../core/bootstrap/bootstrap_state.dart' as core;
import 'bootstrap_event.dart';
import 'bootstrap_state.dart';
import '../../../core/di/injection_container.dart';

class BootstrapBloc extends Bloc<BootstrapEvent, UiBootstrapState> {
  final BootstrapCoordinator _coordinator = getIt<BootstrapCoordinator>();

  BootstrapBloc() : super(UiBootstrapInitial()) {
    on<BootstrapStarted>(_onStarted);
    on<BootstrapDismissed>(_onDismissed);
  }

  Future<void> _onStarted(BootstrapStarted event, Emitter<UiBootstrapState> emit) async {
    try {
      // Configurar callback de progreso
      _coordinator.onProgress = (core.BootstrapState progressState) {
        // Verificar si algún módulo tiene error
        final hasError = progressState.modules.values.any((m) => m.errorMessage != null);
        if (hasError) {
          final errorMessages = progressState.modules.values
              .where((m) => m.errorMessage != null)
              .map((m) => '${m.module.name}: ${m.errorMessage}')
              .join(', ');
          emit(UiBootstrapFailed(errorMessages));
        } else if (_coordinator.isMinimumReady(progressState)) {
          emit(UiBootstrapCompleted(progressState));
        } else {
          emit(UiBootstrapInProgress(progressState));
        }
      };

      // Emitir estado inicial
      emit(UiBootstrapInProgress(core.BootstrapState(
        modules: {
          for (final m in core.BootstrapModule.values)
            m: core.ModuleBootstrapStatus(module: m),
        },
        startedAt: DateTime.now(),
      )));
      
      // Ejecutar el bootstrap
      final finalState = await _coordinator.run(pageSize: event.pageSize);
      
      // Verificar estado final: si no está listo el mínimo, mantener overlay con progreso
      if (_coordinator.isMinimumReady(finalState)) {
        emit(UiBootstrapCompleted(finalState));
      } else {
        emit(UiBootstrapInProgress(finalState));
      }
    } catch (e) {
      emit(UiBootstrapFailed(e.toString()));
    }
  }

  void _onDismissed(BootstrapDismissed event, Emitter<UiBootstrapState> emit) {
    emit(UiBootstrapCompleted(core.BootstrapState(
      modules: {
        for (final m in core.BootstrapModule.values)
          m: core.ModuleBootstrapStatus(module: m, completed: true),
      },
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
    )));
  }
}


