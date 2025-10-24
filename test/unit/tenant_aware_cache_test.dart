import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:odoo_sales_app/core/cache/custom_odoo_kv.dart';
import 'package:odoo_sales_app/core/tenant/tenant_context.dart';
import 'package:odoo_sales_app/core/tenant/tenant_aware_cache.dart';
import 'package:odoo_sales_app/core/tenant/tenant_exception.dart';
import 'package:path/path.dart' as path;

void main() {
  late CustomOdooKv kv;
  late TenantAwareCache cache;
  late Directory testDir;

  setUpAll(() async {
    // Crear directorio temporal para tests
    testDir = await Directory.systemTemp.createTemp('hive_test_');
    // Inicializar Hive con el directorio temporal
    Hive.init(testDir.path);
  });
  
  tearDownAll(() async {
    // Limpiar directorio temporal
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    // Reset completo del contexto
    TenantContext.resetForTesting();
    
    // Crear instancia de cache
    kv = CustomOdooKv();
    await kv.init();
    cache = TenantAwareCache(kv);
    
    // Limpiar todos los datos
    await kv.close();
    await Hive.deleteBoxFromDisk('odoo_cache');
    kv = CustomOdooKv();
    await kv.init();
    cache = TenantAwareCache(kv);
  });

  tearDown(() async {
    await kv.close();
  });

  group('TenantAwareCache - put() y get()', () {
    test('put() y get() con scope automático', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      await cache.put('Partner_records', [
        {'id': 1, 'name': 'Partner A'},
      ]);
      
      final result = cache.get<List>('Partner_records');
      
      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result[0]['name'], equals('Partner A'));
    });

    test('Diferentes tenants tienen datos aislados', () async {
      // Guardar en POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', [
        {'id': 1, 'name': 'Partner A from POF0001'},
      ]);
      
      // Guardar en POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', [
        {'id': 2, 'name': 'Partner B from POF0003'},
      ]);
      
      // Verificar POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      final data1 = cache.get<List>('Partner_records');
      expect(data1![0]['name'], equals('Partner A from POF0001'));
      
      // Verificar POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      final data3 = cache.get<List>('Partner_records');
      expect(data3![0]['name'], equals('Partner B from POF0003'));
    });

    test('get() retorna null si no existe dato', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      final result = cache.get<List>('NonExistent_records');
      
      expect(result, isNull);
    });

    test('put() y get() lanza excepción sin tenant activo', () async {
      expect(
        () async => await cache.put('Partner_records', []),
        throwsA(isA<TenantException>()),
      );
      
      expect(
        () => cache.get<List>('Partner_records'),
        throwsA(isA<TenantException>()),
      );
    });
  });

  group('TenantAwareCache - delete()', () {
    test('delete() elimina dato correctamente', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      await cache.put('Partner_records', [{'id': 1}]);
      expect(cache.get<List>('Partner_records'), isNotNull);
      
      await cache.delete('Partner_records');
      expect(cache.get<List>('Partner_records'), isNull);
    });

    test('delete() solo elimina del tenant actual', () async {
      // Guardar en POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', [{'id': 1}]);
      
      // Guardar en POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', [{'id': 2}]);
      
      // Eliminar en POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.delete('Partner_records');
      
      // Verificar que POF0001 fue eliminado
      expect(cache.get<List>('Partner_records'), isNull);
      
      // Verificar que POF0003 sigue existiendo
      TenantContext.setTenant('POF0003', 'db_pof0003');
      expect(cache.get<List>('Partner_records'), isNotNull);
    });
  });

  group('TenantAwareCache - getAllKeysForTenant()', () {
    test('Retorna todas las keys de un tenant', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      await cache.put('Partner_records', []);
      await cache.put('Product_records', []);
      await cache.put('Employee_records', []);
      
      final keys = cache.getAllKeysForTenant('POF0001');
      
      expect(keys.length, equals(3));
      expect(keys, contains('POF0001:Partner_records'));
      expect(keys, contains('POF0001:Product_records'));
      expect(keys, contains('POF0001:Employee_records'));
    });

    test('Filtra correctamente por tenant', () async {
      // POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', []);
      await cache.put('Product_records', []);
      
      // POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', []);
      
      // Verificar POF0001
      final keys1 = cache.getAllKeysForTenant('POF0001');
      expect(keys1.length, equals(2));
      
      // Verificar POF0003
      final keys3 = cache.getAllKeysForTenant('POF0003');
      expect(keys3.length, equals(1));
    });

    test('Retorna lista vacía si no hay keys', () {
      final keys = cache.getAllKeysForTenant('POF9999');
      
      expect(keys, isEmpty);
    });
  });

  group('TenantAwareCache - clearTenant()', () {
    test('Elimina TODOS los datos de un tenant', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      await cache.put('Partner_records', []);
      await cache.put('Product_records', []);
      await cache.put('Employee_records', []);
      
      expect(cache.getAllKeysForTenant('POF0001').length, equals(3));
      
      await cache.clearTenant('POF0001');
      
      expect(cache.getAllKeysForTenant('POF0001'), isEmpty);
    });

    test('Solo elimina el tenant especificado', () async {
      // POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', [{'id': 1}]);
      
      // POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', [{'id': 3}]);
      
      // Limpiar POF0001
      await cache.clearTenant('POF0001');
      
      // POF0001 debe estar vacío
      expect(cache.getAllKeysForTenant('POF0001'), isEmpty);
      
      // POF0003 debe seguir existiendo
      expect(cache.getAllKeysForTenant('POF0003').length, equals(1));
      TenantContext.setTenant('POF0003', 'db_pof0003');
      expect(cache.get<List>('Partner_records'), isNotNull);
    });

    test('No lanza error si tenant no existe', () async {
      expect(
        () async => await cache.clearTenant('POF9999'),
        returnsNormally,
      );
    });
  });

  group('TenantAwareCache - contains()', () {
    test('Retorna true si la key existe', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', []);
      
      expect(cache.contains('Partner_records'), isTrue);
    });

    test('Retorna false si la key no existe', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      expect(cache.contains('NonExistent_records'), isFalse);
    });

    test('Retorna false si no hay tenant activo', () {
      expect(cache.contains('Partner_records'), isFalse);
    });
  });

  group('TenantAwareCache - listAllTenants()', () {
    test('Lista todos los tenants correctamente', () async {
      // POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', []);
      
      // POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', []);
      
      // POF0005
      TenantContext.setTenant('POF0005', 'db_pof0005');
      await cache.put('Partner_records', []);
      
      final tenants = cache.listAllTenants();
      
      expect(tenants.length, equals(3));
      expect(tenants, contains('POF0001'));
      expect(tenants, contains('POF0003'));
      expect(tenants, contains('POF0005'));
    });

    test('Retorna lista vacía si no hay tenants', () {
      final tenants = cache.listAllTenants();
      
      expect(tenants, isEmpty);
    });

    test('Lista está ordenada', () async {
      // Crear en orden aleatorio
      TenantContext.setTenant('POF0005', 'db');
      await cache.put('data', []);
      
      TenantContext.setTenant('POF0001', 'db');
      await cache.put('data', []);
      
      TenantContext.setTenant('POF0003', 'db');
      await cache.put('data', []);
      
      final tenants = cache.listAllTenants();
      
      expect(tenants, equals(['POF0001', 'POF0003', 'POF0005']));
    });
  });

  group('TenantAwareCache - getTenantSize()', () {
    test('Calcula tamaño aproximado', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      await cache.put('Partner_records', [
        {'id': 1, 'name': 'Partner A'},
        {'id': 2, 'name': 'Partner B'},
      ]);
      
      final sizeMB = cache.getTenantSize('POF0001');
      
      expect(sizeMB, greaterThan(0.0));
    });

    test('Diferentes tenants tienen diferentes tamaños', () async {
      // POF0001 con 2 registros
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await cache.put('Partner_records', [
        {'id': 1, 'name': 'Partner A'},
        {'id': 2, 'name': 'Partner B'},
      ]);
      
      // POF0003 con 1 registro
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await cache.put('Partner_records', [
        {'id': 3, 'name': 'Partner C'},
      ]);
      
      final size1 = cache.getTenantSize('POF0001');
      final size3 = cache.getTenantSize('POF0003');
      
      expect(size1, greaterThan(size3));
    });
  });
}

