import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:odoo_sales_app/core/cache/custom_odoo_kv.dart';
import 'package:odoo_sales_app/core/tenant/tenant_context.dart';
import 'package:odoo_sales_app/core/tenant/tenant_aware_cache.dart';

void main() {
  late CustomOdooKv kv;
  late TenantAwareCache tenantCache;
  Directory? testDir;

  setUpAll(() async {
    // Crear directorio temporal para tests
    testDir = await Directory.systemTemp.createTemp('hive_integration_test_');
    // Inicializar Hive con el directorio temporal
    Hive.init(testDir!.path);
  });

  tearDownAll(() async {
    // Limpiar directorio temporal
    if (testDir != null && testDir!.existsSync()) {
      testDir!.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    // Reset completo del contexto
    TenantContext.resetForTesting();
    
    // Crear instancia de cache
    kv = CustomOdooKv();
    await kv.init();
    tenantCache = TenantAwareCache(kv);
    
    // Limpiar todos los datos
    await kv.close();
    await Hive.deleteBoxFromDisk('odoo_cache');
    kv = CustomOdooKv();
    await kv.init();
    tenantCache = TenantAwareCache(kv);
  });

  tearDown(() async {
    await kv.close();
  });

  group('Tenant Authentication Integration Tests', () {
    test('Login → Cache → Logout → Login (same license) → Cache preserved', () async {
      // Simular login con licencia POF0001
      final previousLicense1 = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(previousLicense1, isNull); // Primera vez
      
      // Simular bootstrap - agregar datos al cache
      final testData1 = [
        {'id': 1, 'name': 'Partner POF0001-1'},
        {'id': 2, 'name': 'Partner POF0001-2'},
      ];
      await tenantCache.put('Partner_records', testData1);
      
      // Verificar que los datos están en cache
      final cached1 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect(cached1, isNotNull);
      expect(cached1, isA<List>());
      final listCached1 = cached1 as List;
      expect(listCached1.length, equals(2));
      
      // Simular logout (clearTenant pero NO limpiar cache)
      TenantContext.clearTenant();
      expect(TenantContext.hasActiveTenant, isFalse);
      
      // Simular login con la MISMA licencia POF0001
      final previousLicense2 = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(previousLicense2, isNull); // No hay cambio de licencia
      
      // Verificar que los datos SÍ están en cache (misma licencia)
      final cached2 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect(cached2, isNotNull);
      final listCached2 = cached2 as List;
      expect(listCached2.length, equals(2));
    });

    test('Login → Cache → Logout → Login (different license) → Cache cleared', () async {
      // Simular login con licencia POF0001
      final previousLicense1 = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(previousLicense1, isNull);
      
      // Simular bootstrap - agregar datos al cache
      final testData1 = [
        {'id': 1, 'name': 'Partner POF0001-1'},
        {'id': 2, 'name': 'Partner POF0001-2'},
      ];
      await tenantCache.put('Partner_records', testData1);
      
      // Verificar que los datos están en cache
      final cached1 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      final listCached1 = cached1 as List;
      expect(listCached1.length, equals(2));
      
      // Simular logout
      TenantContext.clearTenant();
      
      // Simular login con DIFERENTE licencia POF0003
      final previousLicense2 = TenantContext.setTenant('POF0003', 'db_pof0003');
      expect(previousLicense2, equals('POF0001')); // ✅ Detecta cambio de licencia
      
      // SIMULAR limpieza de cache (como lo hace injection_container.dart)
      await tenantCache.clearTenant('POF0001');
      
      // Verificar que los datos de POF0001 fueron limpiados
      // Como ahora estamos en POF0003, el cache de POF0001 debe estar vacío
      final cached3 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      final listCached3 = cached3 as List;
      expect(listCached3.length, equals(0)); // ✅ Cache limpiado
      
      // Simular bootstrap para POF0003
      final testData2 = [
        {'id': 101, 'name': 'Partner POF0003-1'},
        {'id': 102, 'name': 'Partner POF0003-2'},
      ];
      await tenantCache.put('Partner_records', testData2);
      
      // Verificar que los datos de POF0003 están en cache
      final cached4 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      final listCached4 = cached4 as List;
      expect(listCached4.length, equals(2));
      expect((listCached4.first as Map)['name'], equals('Partner POF0003-1'));
    });

    test('Login → Bootstrap → Logout → Login (different) → Login (original) → Full bootstrap required', () async {
      // Login POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await tenantCache.put('Partner_records', [
        {'id': 1, 'name': 'Partner POF0001'},
      ]);
      
      // Logout
      TenantContext.clearTenant();
      
      // Login POF0003 (cambia licencia)
      final prevLicense = TenantContext.setTenant('POF0003', 'db_pof0003');
      expect(prevLicense, equals('POF0001'));
      
      // Limpiar cache de POF0001
      await tenantCache.clearTenant('POF0001');
      
      // Agregar datos para POF0003
      await tenantCache.put('Partner_records', [
        {'id': 101, 'name': 'Partner POF0003'},
      ]);
      
      // Logout
      TenantContext.clearTenant();
      
      // Login POF0001 de nuevo (regresa a licencia original)
      final prevLicense2 = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(prevLicense2, equals('POF0003'));
      
      // Limpiar cache de POF0003
      await tenantCache.clearTenant('POF0003');
      
      // Verificar que el cache de POF0001 está vacío (fue limpiado cuando cambiamos a POF0003)
      final cached = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      final listCached = cached as List;
      expect(listCached.length, equals(0)); // ✅ Debe hacer bootstrap completo
    });

    test('Multiple datasets isolated per license', () async {
      // POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await tenantCache.put('Partner_records', [
        {'id': 1, 'name': 'POF0001-Partner1'},
        {'id': 2, 'name': 'POF0001-Partner2'},
      ]);
      
      final cached1 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached1 as List).length, equals(2));
      
      // Cambiar a POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await tenantCache.clearTenant('POF0001');
      
      // POF0003 tiene datos diferentes
      await tenantCache.put('Partner_records', [
        {'id': 101, 'name': 'POF0003-Partner1'},
        {'id': 102, 'name': 'POF0003-Partner2'},
        {'id': 103, 'name': 'POF0003-Partner3'},
      ]);
      
      final cached2 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached2 as List).length, equals(3));
      
      // Volver a POF0001 (debe estar vacío porque fue limpiado)
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await tenantCache.clearTenant('POF0003');
      
      final cached3 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached3 as List).length, equals(0)); // ✅ Cache limpiado
    });

    test('Cache survives logout but not license change', () async {
      // Login POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      await tenantCache.put('Partner_records', [
        {'id': 1, 'name': 'Test1'},
      ]);
      
      final cached1 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached1 as List).length, equals(1));
      
      // Logout (clearTenant pero NO clearTenant cache)
      TenantContext.clearTenant();
      
      // Volver a login con MISMA licencia POF0001
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      // Cache debe estar intacto
      final cached2 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached2 as List).length, equals(1)); // ✅ Cache preservado
      
      // Cambiar a licencia diferente POF0003
      TenantContext.setTenant('POF0003', 'db_pof0003');
      await tenantCache.clearTenant('POF0001');
      
      // Cache debe estar vacío
      final cached3 = tenantCache.get('Partner_records', defaultValue: <Map<String, dynamic>>[]);
      expect((cached3 as List).length, equals(0)); // ✅ Cache limpiado
    });
  });

  group('Tenant Storage Size Tests', () {
    test('Cache size increases with data', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      // Sin datos
      final size1 = await tenantCache.getTenantSize('POF0001');
      print('Tamaño inicial: $size1 bytes');
      
      // Con datos
      await tenantCache.put('Partner_records', List.generate(100, (i) => {
        'id': i,
        'name': 'Partner $i',
        'email': 'partner$i@example.com',
        'phone': '1234567890',
      }));
      
      final size2 = await tenantCache.getTenantSize('POF0001');
      print('Tamaño con datos: $size2 bytes');
      expect(size2, greaterThan(size1));
    });

    test('Cache cleared reduces size', () async {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      // Agregar datos
      await tenantCache.put('Partner_records', List.generate(50, (i) => {'id': i, 'name': 'Partner $i'}));
      await tenantCache.put('Product_records', List.generate(30, (i) => {'id': i, 'name': 'Product $i'}));
      
      final size1 = await tenantCache.getTenantSize('POF0001');
      print('Tamaño antes de limpiar: $size1 bytes');
      
      // Limpiar cache
      await tenantCache.clearTenant('POF0001');
      
      final size2 = await tenantCache.getTenantSize('POF0001');
      print('Tamaño después de limpiar: $size2 bytes');
      expect(size2, lessThan(size1));
    });
  });
}

