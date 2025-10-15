import 'package:flutter/material.dart';
import '../../core/di/injection_container.dart';
import '../../data/models/partner_model.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/odoo_call_queue_repository.dart';

class OfflineTestPage extends StatefulWidget {
  const OfflineTestPage({super.key});

  @override
  State<OfflineTestPage> createState() => _OfflineTestPageState();
}

class _OfflineTestPageState extends State<OfflineTestPage> {
  late PartnerRepository _partnerRepository;
  late OdooCallQueueRepository _callQueue;
  
  String _status = 'Inicializando...';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      _partnerRepository = getIt<PartnerRepository>();
      _callQueue = getIt<OdooCallQueueRepository>();
      _updateStatus('Servicios inicializados correctamente');
    } catch (e) {
      _updateStatus('Error inicializando servicios: $e');
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

  Future<void> _testCreatePartner() async {
    try {
      _updateStatus('Probando creación de partner offline...');
      
      final newPartner = Partner(
        id: 0, // ID temporal
        name: 'Partner Test Offline ${DateTime.now().millisecond}',
        email: 'test${DateTime.now().millisecond}@example.com',
        phone: '+1234567890',
        isCompany: false,
        customerRank: 1,
        supplierRank: 0,
        active: true,
      );

      final localId = await _partnerRepository.createPartner(newPartner);
      _updateStatus('✅ Partner creado offline con ID local: $localId');
      
      await _showPendingOperations();
    } catch (e) {
      _updateStatus('❌ Error creando partner: $e');
    }
  }

  Future<void> _testUpdatePartner() async {
    try {
      _updateStatus('Probando actualización de partner offline...');
      
      final existingPartner = Partner(
        id: 999, // ID simulado
        name: 'Partner Actualizado Offline',
        email: 'updated@example.com',
        phone: '+9876543210',
        isCompany: false,
        customerRank: 1,
        supplierRank: 0,
        active: true,
      );

      await _partnerRepository.updatePartner(existingPartner);
      _updateStatus('✅ Partner actualizado offline');
      
      await _showPendingOperations();
    } catch (e) {
      _updateStatus('❌ Error actualizando partner: $e');
    }
  }

  Future<void> _testDeletePartner() async {
    try {
      _updateStatus('Probando eliminación de partner offline...');
      
      await _partnerRepository.deletePartner(888); // ID simulado
      _updateStatus('✅ Partner eliminado offline');
      
      await _showPendingOperations();
    } catch (e) {
      _updateStatus('❌ Error eliminando partner: $e');
    }
  }

  Future<void> _showPendingOperations() async {
    try {
      final operations = await _callQueue.getPendingOperations();
      final count = await _callQueue.getPendingCount();
      
      _updateStatus('📋 Operaciones pendientes: $count');
      
      if (operations.isNotEmpty) {
        _updateStatus('Última operación: ${operations.last.operation} ${operations.last.model}');
      }
    } catch (e) {
      _updateStatus('❌ Error obteniendo operaciones pendientes: $e');
    }
  }

  Future<void> _testSync() async {
    try {
      _updateStatus('Iniciando sincronización...');
      
      final result = await _callQueue.syncPendingOperations();
      
      if (result.success) {
        _updateStatus('✅ Sincronización exitosa: ${result.syncedOperations} operaciones');
      } else {
        _updateStatus('❌ Error en sincronización: ${result.message}');
      }
    } catch (e) {
      _updateStatus('❌ Error durante sincronización: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba Funcionalidad Offline'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado actual
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botones de prueba
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testCreatePartner,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Partner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testUpdatePartner,
                    icon: const Icon(Icons.edit),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testDeletePartner,
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showPendingOperations,
                    icon: const Icon(Icons.list),
                    label: const Text('Ver Cola'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testSync,
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logs:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
