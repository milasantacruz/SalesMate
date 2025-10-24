import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sales_app/core/tenant/tenant_context.dart';
import 'package:odoo_sales_app/core/tenant/tenant_exception.dart';

void main() {
  setUp(() {
    // Reset completo del estado antes de cada test
    TenantContext.resetForTesting();
  });

  group('TenantContext - setTenant()', () {
    test('Primera vez - retorna null', () {
      final previousLicense = TenantContext.setTenant('POF0001', 'db_pof0001');
      
      expect(previousLicense, isNull);
      expect(TenantContext.currentLicenseNumber, equals('POF0001'));
      expect(TenantContext.currentDatabase, equals('db_pof0001'));
      expect(TenantContext.hasActiveTenant, isTrue);
    });

    test('Misma licencia - retorna null', () {
      // Primera vez
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      // Segunda vez con la misma licencia
      final previousLicense = TenantContext.setTenant('POF0001', 'db_pof0001');
      
      expect(previousLicense, isNull);
      expect(TenantContext.currentLicenseNumber, equals('POF0001'));
    });

    test('Licencia diferente - retorna anterior', () {
      // Primera licencia
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      // Cambiar a licencia diferente
      final previousLicense = TenantContext.setTenant('POF0003', 'db_pof0003');
      
      expect(previousLicense, equals('POF0001'));
      expect(TenantContext.currentLicenseNumber, equals('POF0003'));
      expect(TenantContext.currentDatabase, equals('db_pof0003'));
    });

    test('Múltiples cambios de licencia', () {
      // POF0001
      var previous = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(previous, isNull);
      
      // POF0003
      previous = TenantContext.setTenant('POF0003', 'db_pof0003');
      expect(previous, equals('POF0001'));
      
      // POF0005
      previous = TenantContext.setTenant('POF0005', 'db_pof0005');
      expect(previous, equals('POF0003'));
      
      // Volver a POF0001
      previous = TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(previous, equals('POF0005'));
    });

    test('tenantSetAt se actualiza', () {
      final before = DateTime.now();
      TenantContext.setTenant('POF0001', 'db_pof0001');
      final after = DateTime.now();
      
      expect(TenantContext.tenantSetAt, isNotNull);
      expect(
        TenantContext.tenantSetAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        TenantContext.tenantSetAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('TenantContext - clearTenant()', () {
    test('Limpia contexto correctamente', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      expect(TenantContext.hasActiveTenant, isTrue);
      
      TenantContext.clearTenant();
      
      expect(TenantContext.currentLicenseNumber, isNull);
      expect(TenantContext.currentDatabase, isNull);
      expect(TenantContext.hasActiveTenant, isFalse);
    });

    test('Puede volver a establecer tenant después de clear', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      TenantContext.clearTenant();
      
      final previous = TenantContext.setTenant('POF0003', 'db_pof0003');
      
      // Debe detectar cambio de POF0001 a POF0003
      expect(previous, equals('POF0001'));
      expect(TenantContext.currentLicenseNumber, equals('POF0003'));
    });
  });

  group('TenantContext - scopeKey()', () {
    test('Genera prefijo correcto', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      final scopedKey = TenantContext.scopeKey('Partner_records');
      
      expect(scopedKey, equals('POF0001:Partner_records'));
    });

    test('Diferentes tenants generan diferentes scopes', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      final key1 = TenantContext.scopeKey('Partner_records');
      
      TenantContext.setTenant('POF0003', 'db_pof0003');
      final key2 = TenantContext.scopeKey('Partner_records');
      
      expect(key1, equals('POF0001:Partner_records'));
      expect(key2, equals('POF0003:Partner_records'));
      expect(key1, isNot(equals(key2)));
    });

    test('Lanza excepción si no hay tenant activo', () {
      expect(
        () => TenantContext.scopeKey('Partner_records'),
        throwsA(isA<TenantException>()),
      );
    });
  });

  group('TenantContext - requireTenant()', () {
    test('No lanza excepción si hay tenant activo', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      expect(
        () => TenantContext.requireTenant(),
        returnsNormally,
      );
    });

    test('Lanza excepción si no hay tenant activo', () {
      expect(
        () => TenantContext.requireTenant(),
        throwsA(isA<TenantException>()),
      );
    });
  });

  group('TenantContext - getDebugInfo()', () {
    test('Retorna información correcta con tenant activo', () {
      TenantContext.setTenant('POF0001', 'db_pof0001');
      
      final info = TenantContext.getDebugInfo();
      
      expect(info['currentLicenseNumber'], equals('POF0001'));
      expect(info['currentDatabase'], equals('db_pof0001'));
      expect(info['hasActiveTenant'], isTrue);
      expect(info['tenantSetAt'], isNotNull);
    });

    test('Retorna información correcta sin tenant activo', () {
      final info = TenantContext.getDebugInfo();
      
      expect(info['currentLicenseNumber'], isNull);
      expect(info['currentDatabase'], isNull);
      expect(info['hasActiveTenant'], isFalse);
      expect(info['tenantSetAt'], isNull);
    });
  });
}

