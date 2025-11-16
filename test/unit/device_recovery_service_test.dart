import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import '../../lib/core/device/device_recovery_service.dart';

void main() {
  group('DeviceRecoveryService Tests', () {
    late DeviceRecoveryService service;

    setUpAll(() async {
      // Inicializar Hive para testing con directorio temporal
      final tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
    });

    setUp(() async {
      service = DeviceRecoveryService();
      await service.init();
      // Limpiar UUID antes de cada test
      await service.clearUUID();
    });

    tearDown(() async {
      await service.close();
    });

    test('debe generar un UUID v4 válido', () {
      final uuid = service.generateUUID();
      
      expect(uuid, isNotEmpty);
      expect(service.isValidUUID(uuid), isTrue);
    });

    test('debe validar UUID v4 válido', () {
      const validUUID = '550e8400-e29b-41d4-a716-446655440000';
      
      expect(service.isValidUUID(validUUID), isTrue);
    });

    test('debe rechazar UUID inválido', () {
      const invalidUUIDs = [
        'not-a-uuid',
        '550e8400-e29b-41d4-a716', // Incompleto
        '550e8400-e29b-41d4-a716-446655440000-extra', // Demasiado largo
        '550e8400-e29b-31d4-a716-446655440000', // Versión 3, no 4
        '', // Vacío
      ];

      for (final invalidUUID in invalidUUIDs) {
        expect(
          service.isValidUUID(invalidUUID),
          isFalse,
          reason: 'UUID "$invalidUUID" debería ser inválido',
        );
      }
    });

    test('debe almacenar y recuperar UUID', () async {
      const testUUID = '550e8400-e29b-41d4-a716-446655440000';
      
      await service.storeUUID(testUUID);
      final retrievedUUID = service.getStoredUUID();
      
      expect(retrievedUUID, equals(testUUID));
    });

    test('debe generar nuevo UUID si no se proporciona uno', () async {
      final uuid = await service.storeUUID();
      
      expect(uuid, isNotEmpty);
      expect(service.isValidUUID(uuid), isTrue);
      
      final retrievedUUID = service.getStoredUUID();
      expect(retrievedUUID, equals(uuid));
    });

    test('debe retornar null si no hay UUID almacenado', () {
      final uuid = service.getStoredUUID();
      
      expect(uuid, isNull);
    });

    test('debe eliminar UUID del cache', () async {
      const testUUID = '550e8400-e29b-41d4-a716-446655440000';
      
      await service.storeUUID(testUUID);
      expect(service.getStoredUUID(), equals(testUUID));
      
      await service.clearUUID();
      expect(service.getStoredUUID(), isNull);
    });

    test('debe normalizar UUID correctamente', () {
      const testCases = [
        ('550e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000'),
        ('550E8400-E29B-41D4-A716-446655440000', '550e8400-e29b-41d4-a716-446655440000'),
        (' 550e8400-e29b-41d4-a716-446655440000 ', '550e8400-e29b-41d4-a716-446655440000'),
        ('550E8400-e29b-41D4-A716-446655440000', '550e8400-e29b-41d4-a716-446655440000'),
      ];

      for (final (input, expected) in testCases) {
        final normalized = service.normalizeUUID(input);
        expect(normalized, equals(expected));
      }
    });

    test('debe comparar UUIDs ignorando mayúsculas y espacios', () {
      const uuid1 = '550e8400-e29b-41d4-a716-446655440000';
      const uuid2 = '550E8400-E29B-41D4-A716-446655440000';
      const uuid3 = ' 550e8400-e29b-41d4-a716-446655440000 ';
      const differentUUID = '660e8400-e29b-41d4-a716-446655440000';

      expect(service.compareUUIDs(uuid1, uuid2), isTrue);
      expect(service.compareUUIDs(uuid1, uuid3), isTrue);
      expect(service.compareUUIDs(uuid1, differentUUID), isFalse);
    });

    test('debe generar UUIDs únicos', () {
      final uuid1 = service.generateUUID();
      final uuid2 = service.generateUUID();
      final uuid3 = service.generateUUID();

      expect(uuid1, isNot(equals(uuid2)));
      expect(uuid2, isNot(equals(uuid3)));
      expect(uuid1, isNot(equals(uuid3)));
    });
  });
}

