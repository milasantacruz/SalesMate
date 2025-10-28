import 'package:flutter/material.dart';
import 'package:odoo_repository/odoo_repository.dart';
import '../../core/di/injection_container.dart';
import '../../data/repositories/odoo_call_queue_repository.dart';
import '../../core/sync/incremental_sync_coordinator.dart';
import '../../core/network/network_connectivity.dart';

class OfflineTestPage extends StatefulWidget {
  const OfflineTestPage({super.key});

  @override
  State<OfflineTestPage> createState() => _OfflineTestPageState();
}

class _OfflineTestPageState extends State<OfflineTestPage> {
  late OdooCallQueueRepository _callQueue;
  late NetworkConnectivity _networkConnectivity;
  
  String _status = 'Inicializando...';
  List<String> _logs = [];
  int _pendingOperationsCount = 0;
  bool _isSyncing = false;
  bool _hasConnectivity = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      _callQueue = getIt<OdooCallQueueRepository>();
      _networkConnectivity = getIt<NetworkConnectivity>();
      _checkConnectivity();
      _loadPendingOperations();
      _updateStatus('Servicios inicializados correctamente');
    } catch (e) {
      _updateStatus('Error inicializando servicios: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final netState = await _networkConnectivity.checkNetConn();
      final hasConnection = netState == netConnState.online;
      setState(() {
        _hasConnectivity = hasConnection;
      });
      _updateStatus('Conectividad: ${hasConnection ? "Online" : "Offline"}');
    } catch (e) {
      _updateStatus('Error verificando conectividad: $e');
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _status = message;
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 10) {
        _logs.removeAt(0); // Mantener solo los últimos 10 logs
      }
    });
    print('OFFLINE_TEST: $message');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 30) {
        _logs.removeRange(0, _logs.length - 30);
      }
    });
    print('OFFLINE_TEST: $message');
  }

  Future<void> _loadPendingOperations() async {
    try {
      final operations = await _callQueue.getPendingOperations();
      final count = await _callQueue.getPendingCount();
      
      setState(() {
        _pendingOperationsCount = count;
      });
      
      if (operations.isNotEmpty) {
        final lastOp = operations.last;
        _updateStatus('📋 Operaciones pendientes: $count - Última: ${lastOp.operation} (${lastOp.model})');
      } else {
        _updateStatus('✅ No hay operaciones pendientes');
      }
    } catch (e) {
      _updateStatus('❌ Error cargando operaciones: $e');
    }
  }

  Future<void> _testSync() async {
    if (_isSyncing) {
      _updateStatus('⏳ Sincronización en progreso...');
      return;
    }

    if (!_hasConnectivity) {
      _updateStatus('⚠️ Sin conectividad. Activar WiFi o datos móviles.');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      _updateStatus('🚀 Iniciando sincronización...');
      
      // PASO 1: Sincronizar cola offline (operaciones pendientes)
      _updateStatus('📤 Enviando operaciones offline...');
      final result = await _callQueue.syncPendingOperations();
      
      if (result.success) {
        _updateStatus('✅ ${result.syncedOperations} operaciones sincronizadas exitosamente');
        await _loadPendingOperations(); // Actualizar contador
      } else {
        // Mostrar detalles de errores
        if (result.failedOperations > 0) {
          _updateStatus('⚠️ ${result.syncedOperations} exitosas, ${result.failedOperations} fallidas');
          
          // Obtener operaciones pendientes para ver cuáles fallaron
          final failedOps = await _callQueue.getPendingOperations();
          for (final op in failedOps.take(3)) { // Mostrar máximo 3 errores
            _addLog('❌ ${op.operation} ${op.model}: ${op.errorMessage ?? 'error desconocido'}');
          }
          
          if (failedOps.length > 3) {
            _addLog('... y ${failedOps.length - 3} más');
          }
        } else {
          _updateStatus('⚠️ Sincronización: ${result.message}');
        }
      }
      
      // PASO 2: Ejecutar incremental sync (traer cambios del servidor)
      _updateStatus('🔄 Descargando actualizaciones...');
      final incrementalSync = getIt<IncrementalSyncCoordinator>();
      
      incrementalSync.onProgress = (state) {
        final progress = (state.progressPercent * 100).toStringAsFixed(0);
        _updateStatus('📊 Progreso: $progress%');
      };
      
      final syncResult = await incrementalSync.run();
      
      if (syncResult.modules.values.any((m) => m.errorMessage != null)) {
        final errors = syncResult.modules.values
            .where((m) => m.errorMessage != null)
            .map((m) => m.errorMessage)
            .join(', ');
        _updateStatus('❌ Error: $errors');
      } else {
        _updateStatus('✅ Sincronización completa: ${syncResult.totalRecordsMerged} registros actualizados');
      }
      
      // Actualizar conectividad después de sync
      await _checkConnectivity();
      
    } catch (e) {
      _updateStatus('❌ Error durante sincronización: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Sincronización'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingOperations,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingOperations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de conectividad
              _buildConnectivityCard(context),
              
              const SizedBox(height: 16),
              
              // Operaciones pendientes
              _buildPendingOperationsCard(context),
              
              const SizedBox(height: 16),
              
              // Botones de acción
              _buildActionButtons(context),
              
              const SizedBox(height: 16),
              
              // Estado actual
              _buildStatusCard(context),
              
              const SizedBox(height: 16),
              
              // Logs
              _buildLogsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectivityCard(BuildContext context) {
    return Card(
      color: _hasConnectivity ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _hasConnectivity ? Icons.wifi : Icons.wifi_off,
              color: _hasConnectivity ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de Conexión',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _hasConnectivity ? 'Conectado' : 'Sin conexión',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _hasConnectivity ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOperationsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operaciones Pendientes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_pendingOperationsCount operaciones esperando sincronización',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_pendingOperationsCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tienes operaciones guardadas localmente que se sincronizarán cuando tengas conexión.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loadPendingOperations,
            icon: const Icon(Icons.list),
            label: const Text('Ver Cola'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSyncing || !_hasConnectivity ? null : _testSync,
            icon: _isSyncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text(
                  'Estado Actual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text(
                  'Historial de Actividad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No hay actividad reciente',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
