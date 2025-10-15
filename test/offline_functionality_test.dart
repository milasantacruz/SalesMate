import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'dart:io';

import '../lib/data/models/pending_operation_model.dart';
import '../lib/data/repositories/operation_queue_repository.dart';
import '../lib/data/repositories/local_id_repository.dart';
import '../lib/data/repositories/sync_coordinator_repository.dart';
import '../lib/data/repositories/odoo_call_queue_repository.dart';
import '../lib/core/network/network_connectivity.dart';
import '../lib/core/cache/custom_odoo_kv.dart';

void main() {
  group('Offline Functionality Tests', () {
    late GetIt getIt;
    late OperationQueueRepository queueRepo;
    late LocalIdRepository idRepo;
    late OdooCallQueueRepository callQueue;

    setUpAll(() async {
      // Inicializar Hive para testing con directorio temporal
      final tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
    });

    setUp(() async {
      // Limpiar GetIt antes de cada test
      await GetIt.instance.reset();
      getIt = GetIt.instance;

      // Registrar dependencias básicas
      getIt.registerLazySingleton<NetworkConnectivity>(() => NetworkConnectivity());
      getIt.registerLazySingleton<CustomOdooKv>(() => CustomOdooKv());
      getIt.registerLazySingleton<LocalIdRepository>(() => LocalIdRepository());
      
      // Inicializar y registrar OperationQueueRepository
      queueRepo = OperationQueueRepository();
      await queueRepo.init();
      getIt.registerSingleton<OperationQueueRepository>(queueRepo);

      // Mock OdooClient para testing
      getIt.registerLazySingleton<OdooClient>(() => MockOdooClient());

      // Registrar servicios offline
      getIt.registerLazySingleton<SyncCoordinatorRepository>(() => SyncCoordinatorRepository(
        networkConnectivity: getIt<NetworkConnectivity>(),
        queueRepository: getIt<OperationQueueRepository>(),
        odooClient: getIt<OdooClient>(),
      ));

      getIt.registerLazySingleton<OdooCallQueueRepository>(() => OdooCallQueueRepository(
        queueRepository: getIt<OperationQueueRepository>(),
        idRepository: getIt<LocalIdRepository>(),
        syncCoordinator: getIt<SyncCoordinatorRepository>(),
        networkConnectivity: getIt<NetworkConnectivity>(),
      ));

      // Obtener instancias para testing
      idRepo = getIt<LocalIdRepository>();
      callQueue = getIt<OdooCallQueueRepository>();
    });

    tearDown(() async {
      // Limpiar cola después de cada test
      await queueRepo.clearAllOperations();
      await queueRepo.close();
    });

    test('LocalIdRepository genera IDs únicos', () {
      // Test generación de IDs locales
      final id1 = idRepo.generateLocalId();
      final id2 = idRepo.generateLocalId();
      
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
      
      // Test IDs para modelos específicos
      final partnerId = idRepo.generateLocalIdForModel('res.partner');
      expect(partnerId, startsWith('PART_'));
      
      final productId = idRepo.generateLocalIdForModel('product.product');
      expect(productId, startsWith('PROD_'));
    });

    test('OperationQueueRepository maneja operaciones correctamente', () async {
      // Crear una operación de prueba
      final operation = PendingOperation(
        id: 'test_operation_1',
        operation: 'create',
        model: 'res.partner',
        data: {'name': 'Test Partner'},
        timestamp: DateTime.now(),
      );

      // Agregar operación a la cola
      await queueRepo.addOperation(operation);
      
      // Verificar que se agregó
      final operations = await queueRepo.getPendingOperations();
      expect(operations.length, equals(1));
      expect(operations.first.id, equals('test_operation_1'));
      
      // Verificar estadísticas
      final stats = await queueRepo.getQueueStats();
      expect(stats.total, equals(1));
      expect(stats.pending, equals(1));
    });

    test('OdooCallQueueRepository crea operaciones offline', () async {
      // Simular datos de partner
      final partnerData = {
        'name': 'Test Partner Offline',
        'email': 'test@example.com',
        'phone': '+1234567890',
      };

      // Crear registro offline (simulando sin conexión)
      final localId = await callQueue.createRecord('res.partner', partnerData);
      
      expect(localId, isNotEmpty);
      expect(idRepo.isLocalId(localId), isTrue);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperations();
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('create'));
      expect(operations.first.model, equals('res.partner'));
    });

    test('OdooCallQueueRepository maneja operaciones de actualización', () async {
      // Simular datos de partner existente
      final partnerData = {
        'id': 123,
        'name': 'Updated Partner Name',
        'email': 'updated@example.com',
      };

      // Actualizar registro offline
      await callQueue.updateRecord('res.partner', 123, partnerData);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperations();
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('update'));
      expect(operations.first.data['id'], equals(123));
      expect(operations.first.data['name'], equals('Updated Partner Name'));
    });

    test('OdooCallQueueRepository maneja operaciones de eliminación', () async {
      // Eliminar registro offline
      await callQueue.deleteRecord('res.partner', 456);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperations();
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('delete'));
      expect(operations.first.data['id'], equals(456));
    });

    test('Cola persiste múltiples operaciones', () async {
      // Crear múltiples operaciones
      await callQueue.createRecord('res.partner', {'name': 'Partner 1'});
      await callQueue.updateRecord('res.partner', 1, {'name': 'Updated Partner 1'});
      await callQueue.deleteRecord('res.partner', 2);
      
      // Verificar que todas se agregaron
      final operations = await queueRepo.getPendingOperations();
      expect(operations.length, equals(3));
      
      // Verificar estadísticas
      final stats = await queueRepo.getQueueStats();
      expect(stats.total, equals(3));
      expect(stats.pending, equals(3));
    });

    test('Operaciones se pueden filtrar por modelo', () async {
      // Crear operaciones para diferentes modelos
      await callQueue.createRecord('res.partner', {'name': 'Partner'});
      await callQueue.createRecord('product.product', {'name': 'Product'});
      await callQueue.createRecord('sale.order', {'name': 'Order'});
      
      // Filtrar por modelo
      final partnerOps = await queueRepo.getPendingOperationsByModel('res.partner');
      final productOps = await queueRepo.getPendingOperationsByModel('product.product');
      
      expect(partnerOps.length, equals(1));
      expect(productOps.length, equals(1));
      expect(partnerOps.first.model, equals('res.partner'));
      expect(productOps.first.model, equals('product.product'));
    });

    test('OdooCallQueueRepository maneja operaciones para Employee', () async {
      // Simular datos de empleado
      final employeeData = {
        'name': 'Test Employee',
        'work_email': 'employee@test.com',
        'pin': '1234',
      };

      // Crear empleado offline
      final localId = await callQueue.createRecord('hr.employee', employeeData);
      
      expect(localId, isNotEmpty);
      expect(idRepo.isLocalId(localId), isTrue);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperationsByModel('hr.employee');
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('create'));
      expect(operations.first.data['name'], equals('Test Employee'));
    });

    test('OdooCallQueueRepository maneja operaciones para City', () async {
      // Simular datos de ciudad
      final cityData = {
        'name': 'Test City',
        'country_id': 1,
        'state_id': 1,
      };

      // Crear ciudad offline
      final localId = await callQueue.createRecord('res.city', cityData);
      
      expect(localId, isNotEmpty);
      expect(idRepo.isLocalId(localId), isTrue);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperationsByModel('res.city');
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('create'));
      expect(operations.first.data['name'], equals('Test City'));
    });

    test('OdooCallQueueRepository maneja operaciones para PricelistItem', () async {
      // Simular datos de pricelist item
      final pricelistData = {
        'product_id': 1,
        'fixed_price': 100.0,
        'min_quantity': 1,
      };

      // Crear pricelist item offline
      final localId = await callQueue.createRecord('product.pricelist.item', pricelistData);
      
      expect(localId, isNotEmpty);
      expect(idRepo.isLocalId(localId), isTrue);
      
      // Verificar que se agregó a la cola
      final operations = await queueRepo.getPendingOperationsByModel('product.pricelist.item');
      expect(operations.length, equals(1));
      expect(operations.first.operation, equals('create'));
      expect(operations.first.data['fixed_price'], equals(100.0));
    });

    test('Sistema offline maneja operaciones múltiples para todos los modelos', () async {
      // Limpiar cola antes del test
      await queueRepo.clearAllOperations();
      
      // Crear operaciones para todos los modelos
      await callQueue.createRecord('res.partner', {'name': 'Partner Test'});
      await callQueue.createRecord('product.product', {'name': 'Product Test'});
      await callQueue.createRecord('sale.order', {'name': 'Order Test'});
      await callQueue.createRecord('hr.employee', {'name': 'Employee Test'});
      await callQueue.createRecord('res.city', {'name': 'City Test'});
      await callQueue.createRecord('product.pricelist.item', {'fixed_price': 50.0});
      
      // Verificar que todas las operaciones se agregaron
      final allOperations = await queueRepo.getPendingOperations();
      expect(allOperations.length, equals(6));
      
      // Verificar estadísticas
      final stats = await queueRepo.getQueueStats();
      expect(stats.total, equals(6));
      expect(stats.pending, equals(6));
      
      // Verificar que cada modelo tiene su operación
      final models = allOperations.map((op) => op.model).toSet();
      expect(models.contains('res.partner'), isTrue);
      expect(models.contains('product.product'), isTrue);
      expect(models.contains('sale.order'), isTrue);
      expect(models.contains('hr.employee'), isTrue);
      expect(models.contains('res.city'), isTrue);
      expect(models.contains('product.pricelist.item'), isTrue);
    });
  });
}

/// Mock OdooClient para testing
class MockOdooClient extends OdooClient {
  MockOdooClient() : super('http://mock.odoo.com');
  
  @override
  Future<dynamic> callKw(dynamic params) async {
    final args = params as Map<String, dynamic>;
    // Simular respuesta exitosa para testing
    if (args['method'] == 'create') {
      return 999; // ID simulado
    } else if (args['method'] == 'write' || args['method'] == 'unlink') {
      return true; // Operación exitosa
    }
    return [];
  }
  
  @override
  Future<OdooSession> authenticate(String database, String username, String password) async {
    // Mock session para testing
    return OdooSession(
      id: 'mock_session_id',
      userId: 1,
      userName: 'Test User',
      userLogin: 'test',
      userLang: 'es',
      userTz: 'America/Santiago',
      serverVersion: '1.0',
      isSystem: false,
      partnerId: 0,
      allowedCompanies: [Company(id: 1, name: 'Test Company')],
      dbName: 'test_db',
      companyId: 1,
    );
  }
}
