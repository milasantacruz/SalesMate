import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/cache/custom_odoo_kv.dart';
import '../../core/di/injection_container.dart';
import '../../core/tenant/tenant_aware_cache.dart';
import '../../core/tenant/tenant_context.dart';
import '../../core/tenant/tenant_admin_service.dart';
import '../../data/models/pending_operation_model.dart';
import '../../data/repositories/operation_queue_repository.dart';
import 'package:odoo_repository/odoo_repository.dart';
import '../../core/audit/audit_event_service.dart';
import '../../core/audit/audit_event.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  DiagnosticsSnapshot? _snapshot;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final kv = getIt<CustomOdooKv>();
      final queueRepo = getIt<OperationQueueRepository>();
      final tenantCache = getIt<TenantAwareCache>();
      final tenantAdmin = getIt<TenantAdminService>();
      final auditService = getIt<AuditEventService>();

      final licenseNumber = kv.get('licenseNumber');

      final sessionInfo = <String, dynamic>{
        'licenseNumber': licenseNumber,
        'companyId': kv.get('companyId'),
        'userId (cache)': kv.get('userId'),
        'username (cache)': kv.get('username'),
        'serverUrl (cache)': kv.get('serverUrl'),
        'database (cache)': kv.get('database'),
      };

      if (getIt.isRegistered<OdooSession>()) {
        final session = getIt<OdooSession>();
        sessionInfo.addAll({
          'session.userId': session.userId,
          'session.dbName': session.dbName,
          'session.id': session.id,
        });
      }

      if (getIt.isRegistered<OdooClient>()) {
        final client = getIt<OdooClient>();
        sessionInfo.addAll({
          'client.baseURL': client.baseURL,
          'client.sessionId': client.sessionId?.id,
        });
      }

      if (getIt.isRegistered<OdooEnvironment>()) {
        final env = getIt<OdooEnvironment>();
        sessionInfo['environment.dbName'] = env.dbName;
      }

      final queueStats = await queueRepo.getQueueStats();
      final pendingOperations = await queueRepo.getPendingOperations();

      final tenantInfo = tenantCache.getDebugInfo();
      final tenantContextInfo = TenantContext.getDebugInfo();
      final auditEvents = auditService.getRecentEvents(limit: 100);

      Map<String, dynamic> tenantAdminInfo = {};
      if (licenseNumber is String && licenseNumber.isNotEmpty) {
        tenantAdminInfo = tenantAdmin.getTenantInfo(
          licenseNumber,
          includeKeys: true,
        );
      }

      DiagnosticsSnapshot snapshot;
      try {
        snapshot = DiagnosticsSnapshot(
          sessionInfo: sessionInfo,
          queueStats: queueStats,
          pendingOperations: pendingOperations,
          tenantCacheInfo: tenantInfo,
          tenantContextInfo: tenantContextInfo,
          tenantAdminInfo: tenantAdminInfo,
          auditEvents: auditEvents,
          capturedAt: DateTime.now(),
        );
      } catch (e) {
        snapshot = DiagnosticsSnapshot(
          sessionInfo: sessionInfo,
          queueStats: queueStats,
          pendingOperations: pendingOperations,
          tenantCacheInfo: tenantInfo,
          tenantContextInfo: tenantContextInfo,
          tenantAdminInfo: const {},
          auditEvents: auditEvents,
          capturedAt: DateTime.now(),
        );
      }

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando diagnóstico: $e';
        _loading = false;
      });
    }
  }

  Future<void> _cleanupCompletedOperations() async {
    try {
      final queueRepo = getIt<OperationQueueRepository>();
      await queueRepo.cleanupCompletedOperations();
      await _loadSnapshot();
    } catch (e) {
      setState(() {
        _error = 'Error limpiando operaciones: $e';
      });
    }
  }

  Future<void> _clearQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar cola offline'),
        content: const Text(
          'Esto eliminará todas las operaciones pendientes. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final queueRepo = getIt<OperationQueueRepository>();
        await queueRepo.clearAllOperations();
        await _loadSnapshot();
      } catch (e) {
        setState(() {
          _error = 'Error limpiando cola: $e';
        });
      }
    }
  }

  Future<void> _clearAuditEvents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar eventos de auditoría'),
        content: const Text(
          'Se eliminarán todos los eventos registrados para esta licencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final auditService = getIt<AuditEventService>();
        await auditService.clearAll();
        await _loadSnapshot();
      } catch (e) {
        setState(() {
          _error = 'Error limpiando eventos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSnapshot,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : snapshot == null
                  ? const Center(child: Text('No hay datos que mostrar'))
                  : RefreshIndicator(
                      onRefresh: _loadSnapshot,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSection(
                            title: 'Sesión y conexión',
                            children: snapshot.sessionInfo.entries
                                .map((entry) => _buildInfoTile(entry.key, entry.value))
                                .toList(),
                          ),
                          _buildSection(
                            title: 'Tenant Cache',
                            children: snapshot.tenantCacheInfo.entries
                                .map((entry) => _buildInfoTile(entry.key, entry.value))
                                .toList(),
                          ),
                          _buildSection(
                            title: 'Tenant Context',
                            children: snapshot.tenantContextInfo.entries
                                .map((entry) => _buildInfoTile(entry.key, entry.value))
                                .toList(),
                          ),
                          _buildSection(
                            title: 'Tenant Admin',
                            children: snapshot.tenantAdminInfo.entries
                                .map((entry) => _buildInfoTile(entry.key, entry.value))
                                .toList(),
                          ),
                          _buildEventsSection(snapshot.auditEvents),
                          _buildQueueSection(snapshot),
                          const SizedBox(height: 12),
                          Text(
                            'Última actualización: ${snapshot.capturedAt.toLocal()} ',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSection(DiagnosticsSnapshot snapshot) {
    final stats = snapshot.queueStats;
    final pendingOps = snapshot.pendingOperations.take(10).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cola offline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _cleanupCompletedOperations,
                      child: const Text('Limpiar completadas'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _clearQueue,
                      child: const Text('Borrar todo'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoTile('Total', stats.total),
            _buildInfoTile('Pendientes', stats.pending),
            _buildInfoTile('Sincronizando', stats.syncing),
            _buildInfoTile('Completadas', stats.completed),
            _buildInfoTile('Fallidas', stats.failed),
            _buildInfoTile('Abandonadas', stats.abandoned),
            if (pendingOps.isNotEmpty) ...[
              const Text('Operaciones pendientes:'),
              const SizedBox(height: 6),
              ...pendingOps.map(
                (op) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text(op.status.emoji, style: const TextStyle(fontSize: 18)),
                  title: Text('${op.operation} → ${op.model}'),
                  subtitle: Text(
                    'ID: ${op.id}\nIntentos: ${op.retryCount}\nFecha: ${op.timestamp.toLocal()}',
                  ),
                ),
              ),
            ] else
              const Text(
                'No hay operaciones pendientes',
                style: TextStyle(color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection(List<AuditEvent> events) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Eventos recientes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: events.isEmpty ? null : _clearAuditEvents,
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text(
                'Sin eventos registrados aún.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...events.map(_buildEventTile),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(AuditEvent event) {
    final color = _levelColor(event.level);
    final icon = _levelIcon(event.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[${event.category.toUpperCase()}] ${event.message}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  _formatTimestamp(event.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (event.metadata != null && event.metadata!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      event.metadata!.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join('  •  '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.toLocal()}';
  }

  IconData _levelIcon(AuditEventLevel level) {
    switch (level) {
      case AuditEventLevel.info:
        return Icons.info_outline;
      case AuditEventLevel.warning:
        return Icons.warning_amber_outlined;
      case AuditEventLevel.error:
        return Icons.error_outline;
    }
  }

  Color _levelColor(AuditEventLevel level) {
    switch (level) {
      case AuditEventLevel.info:
        return Colors.blue.shade700;
      case AuditEventLevel.warning:
        return Colors.orange.shade700;
      case AuditEventLevel.error:
        return Colors.red.shade700;
    }
  }
}

class DiagnosticsSnapshot {
  DiagnosticsSnapshot({
    required this.sessionInfo,
    required this.queueStats,
    required this.pendingOperations,
    required this.tenantCacheInfo,
    required this.tenantContextInfo,
    required this.tenantAdminInfo,
    required this.auditEvents,
    required this.capturedAt,
  });

  final Map<String, dynamic> sessionInfo;
  final QueueStats queueStats;
  final List<PendingOperation> pendingOperations;
  final Map<String, dynamic> tenantCacheInfo;
  final Map<String, dynamic> tenantContextInfo;
  final Map<String, dynamic> tenantAdminInfo;
  final List<AuditEvent> auditEvents;
  final DateTime capturedAt;
}
