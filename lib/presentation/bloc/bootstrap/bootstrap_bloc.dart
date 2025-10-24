import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bootstrap/bootstrap_coordinator.dart';
import '../../../core/bootstrap/bootstrap_state.dart' as core;
import '../../../core/sync/sync_marker_store.dart';
import '../../../core/sync/incremental_sync_coordinator.dart';
import '../../../core/sync/sync_state_converter.dart';
import '../../../core/session/session_ready.dart';
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
      final markerStore = getIt<SyncMarkerStore>();
      
      // 🎯 DECISIÓN AUTOMÁTICA: Bootstrap vs Incremental Sync
      final hasMarkers = markerStore.hasAllCriticalMarkers();
      final hasCache = markerStore.hasCacheContent();
      final hasRecent = markerStore.hasRecentMarkers(maxDays: 7);
      
      print('🔍 BOOTSTRAP_BLOC: Analizando estrategia de sincronización...');
      print('   Marcadores: ${hasMarkers ? "✅" : "❌"}');
      print('   Caché: ${hasCache ? "✅" : "❌"}');
      print('   Reciente (<7 días): ${hasRecent ? "✅" : "❌"}');
      
      // Decidir estrategia
      if (hasMarkers && hasCache && hasRecent) {
        // ✅ Usar Incremental Sync (reconexión)
        print('🔄 BOOTSTRAP_BLOC: Usando INCREMENTAL SYNC (reconexión)');
        await _runIncrementalSync(emit);
      } else {
        // ✅ Usar Bootstrap Completo (primera vez, caché corrupta, o muy antiguo)
        if (!hasMarkers) {
          print('📦 BOOTSTRAP_BLOC: Usando BOOTSTRAP COMPLETO (primera vez, sin marcadores)');
        } else if (!hasCache) {
          print('📦 BOOTSTRAP_BLOC: Usando BOOTSTRAP COMPLETO (caché corrupta)');
          // Limpiar marcadores si caché está corrupta
          await markerStore.clearAllMarkers();
        } else if (!hasRecent) {
          print('📦 BOOTSTRAP_BLOC: Usando BOOTSTRAP COMPLETO (marcadores antiguos >7 días)');
          // Limpiar marcadores antiguos
          await markerStore.clearAllMarkers();
        }
        await _runFullBootstrap(emit, event.pageSize);
      }
    } catch (e) {
      print('❌ BOOTSTRAP_BLOC: Error en sincronización: $e');
      emit(UiBootstrapFailed(e.toString()));
    }
  }

  /// Ejecuta sincronización incremental (reconexiones)
  Future<void> _runIncrementalSync(Emitter<UiBootstrapState> emit) async {
    try {
      final incrementalSync = getIt<IncrementalSyncCoordinator>();
      
      // ✅ v2.0: Esperar a que complete la re-autenticación antes de iniciar sync
      print('⏳ BOOTSTRAP_BLOC: Esperando re-autenticación antes de incremental sync...');
      await SessionReadyCoordinator.waitIfReauthenticationInProgress();
      print('✅ BOOTSTRAP_BLOC: Re-autenticación completada, iniciando incremental sync');
      
      // Configurar callback de progreso
      incrementalSync.onProgress = (incrementalState) {
        // Convertir IncrementalSyncState a BootstrapState para UI
        final bootstrapState = SyncStateConverter.fromIncrementalSync(incrementalState);
        
        // Verificar si hay errores
        final hasError = incrementalState.hasErrors;
        if (hasError) {
          final errorMessages = incrementalState.modules.values
              .where((m) => m.errorMessage != null)
              .map((m) => '${m.module.displayName}: ${m.errorMessage}')
              .join(', ');
          emit(UiBootstrapFailed(errorMessages));
        } else {
          // Emitir progreso
          emit(UiBootstrapInProgress(bootstrapState, isIncremental: true));
        }
      };
      
      // Emitir estado inicial
      emit(UiBootstrapInProgress(
        SyncStateConverter.initialDeciding(),
        isIncremental: true,
      ));
      
      // Ejecutar incremental sync
      final result = await incrementalSync.run();
      
      // Convertir resultado a BootstrapState
      final finalState = SyncStateConverter.fromIncrementalSync(result);
      
      // Emitir completado
      print('✅ BOOTSTRAP_BLOC: Incremental sync completado');
      print('   Registros fetched: ${result.totalRecordsFetched}');
      print('   Registros merged: ${result.totalRecordsMerged}');
      emit(UiBootstrapCompleted(finalState, isIncremental: true));
      
    } catch (e) {
      print('❌ BOOTSTRAP_BLOC: Error en incremental sync: $e');
      print('🔄 BOOTSTRAP_BLOC: Fallback a bootstrap completo');
      
      // Fallback: Limpiar marcadores y hacer bootstrap completo
      final markerStore = getIt<SyncMarkerStore>();
      await markerStore.clearAllMarkers();
      
      // Reintentar con bootstrap completo
      await _runFullBootstrap(emit, 200);
    }
  }

  /// Ejecuta bootstrap completo (primera vez o fallback)
  Future<void> _runFullBootstrap(Emitter<UiBootstrapState> emit, int pageSize) async {
    bool hasEmittedCompleted = false;
    
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
      } else {
        // SOLO emitir progreso, NO completed (eso se hará al final)
        emit(UiBootstrapInProgress(progressState, isIncremental: false));
      }
    };

    // Emitir estado inicial
    emit(UiBootstrapInProgress(
      core.BootstrapState(
        modules: {
          for (final m in core.BootstrapModule.values)
            m: core.ModuleBootstrapStatus(module: m),
        },
        startedAt: DateTime.now(),
      ),
      isIncremental: false,
    ));
    
    // Ejecutar el bootstrap
    final finalState = await _coordinator.run(pageSize: pageSize);
    
    // Emitir completed SOLO UNA VEZ al final
    if (!hasEmittedCompleted) {
      hasEmittedCompleted = true;
      if (_coordinator.isMinimumReady(finalState)) {
        print('🎯 BOOTSTRAP_BLOC: Bootstrap completo finalizado (ÚNICA VEZ)');
        emit(UiBootstrapCompleted(finalState, isIncremental: false));
      } else {
        print('⚠️ BOOTSTRAP_BLOC: Mínimo no alcanzado, manteniendo InProgress');
        emit(UiBootstrapInProgress(finalState, isIncremental: false));
      }
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


