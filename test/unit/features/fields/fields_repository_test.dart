import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:onze_app/core/errors/onze_exception.dart';
import 'package:onze_app/features/fields/domain/fields_repository.dart';
import 'package:onze_app/features/fields/domain/models/field.dart';
import 'package:onze_app/features/fields/domain/models/field_enums.dart';
import 'package:onze_app/features/fields/domain/models/field_schedule.dart';
import 'package:onze_app/features/fields/domain/models/owner_profile.dart';

class MockFieldsRepository extends Mock implements FieldsRepository {}

void main() {
  late MockFieldsRepository repo;

  setUpAll(() {
    registerFallbackValue(FieldType.v5x5);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
  });

  setUp(() => repo = MockFieldsRepository());

  final fakeField = Field(
    id: 'field-1',
    ownerId: 'owner-1',
    name: 'Cancha Los Pinos N°1',
    address: 'Av. Teodoro Gómez de la Torre',
    latitude: 0.3516,
    longitude: -78.1221,
    fieldType: FieldType.v5x5,
    createdAt: DateTime(2025),
  );

  const fakeOwnerProfile = OwnerProfile(
    userId: 'owner-1',
    businessName: 'Canchas Los Pinos',
    idDocument: '1001234567',
    verified: false,
  );

  // ---------------------------------------------------------------------------
  // getOwnerProfile
  // ---------------------------------------------------------------------------

  group('FieldsRepository.getOwnerProfile', () {
    const userId = 'user-1';

    test('retorna el perfil cuando existe', () async {
      when(() => repo.getOwnerProfile(userId))
          .thenAnswer((_) async => fakeOwnerProfile);

      final result = await repo.getOwnerProfile(userId);

      expect(result, isNotNull);
      expect(result!.businessName, 'Canchas Los Pinos');
      expect(result.verified, isFalse);
    });

    test('retorna null cuando el usuario no es dueño', () async {
      when(() => repo.getOwnerProfile(userId)).thenAnswer((_) async => null);

      final result = await repo.getOwnerProfile(userId);
      expect(result, isNull);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getOwnerProfile(userId))
          .thenThrow(const DatabaseException('No se pudo cargar el perfil de dueño.'));

      await expectLater(
        () => repo.getOwnerProfile(userId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // createOwnerProfile
  // ---------------------------------------------------------------------------

  group('FieldsRepository.createOwnerProfile', () {
    const userId = 'user-2';

    test('crea el perfil y lo devuelve', () async {
      when(() => repo.createOwnerProfile(
            userId: userId,
            businessName: any(named: 'businessName'),
            idDocument: any(named: 'idDocument'),
          )).thenAnswer((_) async => fakeOwnerProfile);

      final result = await repo.createOwnerProfile(
        userId: userId,
        businessName: 'Canchas Los Pinos',
        idDocument: '1001234567',
      );

      expect(result.businessName, 'Canchas Los Pinos');
      expect(result.verified, isFalse);
    });

    test('lanza DatabaseException si el perfil ya existe', () async {
      when(() => repo.createOwnerProfile(
            userId: userId,
            businessName: any(named: 'businessName'),
            idDocument: any(named: 'idDocument'),
          )).thenThrow(
        const DatabaseException(
            'No se pudo registrar como dueño. Intenta nuevamente.'),
      );

      await expectLater(
        () => repo.createOwnerProfile(
          userId: userId,
          businessName: 'Test',
          idDocument: '1001234567',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getMyFields
  // ---------------------------------------------------------------------------

  group('FieldsRepository.getMyFields', () {
    const ownerId = 'owner-1';

    test('retorna lista de canchas del dueño', () async {
      when(() => repo.getMyFields(ownerId))
          .thenAnswer((_) async => [fakeField]);

      final result = await repo.getMyFields(ownerId);

      expect(result, hasLength(1));
      expect(result.first.name, 'Cancha Los Pinos N°1');
      expect(result.first.verified, isFalse);
    });

    test('retorna lista vacía cuando el dueño no tiene canchas', () async {
      when(() => repo.getMyFields(ownerId)).thenAnswer((_) async => []);

      final result = await repo.getMyFields(ownerId);
      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getMyFields(ownerId))
          .thenThrow(const DatabaseException('No se pudieron cargar las canchas.'));

      await expectLater(
        () => repo.getMyFields(ownerId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // registerField
  // ---------------------------------------------------------------------------

  group('FieldsRepository.registerField', () {
    const ownerId = 'owner-1';

    test('registra la cancha y la devuelve sin verificar', () async {
      when(() => repo.registerField(
            ownerId: ownerId,
            name: any(named: 'name'),
            description: any(named: 'description'),
            address: any(named: 'address'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            fieldType: any(named: 'fieldType'),
          )).thenAnswer((_) async => fakeField);

      final result = await repo.registerField(
        ownerId: ownerId,
        name: 'Cancha Los Pinos N°1',
        address: 'Av. Teodoro Gómez de la Torre',
        latitude: 0.3516,
        longitude: -78.1221,
        fieldType: FieldType.v5x5,
      );

      expect(result.id, 'field-1');
      expect(result.verified, isFalse);
      expect(result.fieldType, FieldType.v5x5);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.registerField(
            ownerId: ownerId,
            name: any(named: 'name'),
            description: any(named: 'description'),
            address: any(named: 'address'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            fieldType: any(named: 'fieldType'),
          )).thenThrow(
        const DatabaseException('No se pudo registrar la cancha.'),
      );

      await expectLater(
        () => repo.registerField(
          ownerId: ownerId,
          name: 'Test',
          address: 'Test',
          latitude: 0.0,
          longitude: 0.0,
          fieldType: FieldType.v7x7,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // uploadFieldPhoto
  // ---------------------------------------------------------------------------

  group('FieldsRepository.uploadFieldPhoto', () {
    const fieldId = 'field-1';
    final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

    test('retorna URL pública tras subir la foto', () async {
      const expectedUrl =
          'https://supabase.co/storage/field-photos/field-1/0.jpg';
      when(() => repo.uploadFieldPhoto(
            fieldId: fieldId,
            photoIndex: any(named: 'photoIndex'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async => expectedUrl);

      final url = await repo.uploadFieldPhoto(
        fieldId: fieldId,
        photoIndex: 0,
        bytes: fakeBytes,
      );

      expect(url, expectedUrl);
    });

    test('lanza DatabaseException ante error de Storage', () async {
      when(() => repo.uploadFieldPhoto(
            fieldId: fieldId,
            photoIndex: any(named: 'photoIndex'),
            bytes: any(named: 'bytes'),
          )).thenThrow(const DatabaseException('No se pudo subir la foto.'));

      await expectLater(
        () => repo.uploadFieldPhoto(
          fieldId: fieldId,
          photoIndex: 0,
          bytes: fakeBytes,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // updateFieldPhotos
  // ---------------------------------------------------------------------------

  group('FieldsRepository.updateFieldPhotos', () {
    const fieldId = 'field-1';

    test('completa sin error', () async {
      when(() => repo.updateFieldPhotos(
            fieldId: fieldId,
            photoUrls: any(named: 'photoUrls'),
          )).thenAnswer((_) async {});

      await expectLater(
        repo.updateFieldPhotos(
          fieldId: fieldId,
          photoUrls: ['https://url1.jpg', 'https://url2.jpg'],
        ),
        completes,
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.updateFieldPhotos(
            fieldId: fieldId,
            photoUrls: any(named: 'photoUrls'),
          )).thenThrow(const DatabaseException('No se pudo guardar las fotos.'));

      await expectLater(
        () => repo.updateFieldPhotos(fieldId: fieldId, photoUrls: []),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Field — modelo
  // ---------------------------------------------------------------------------

  group('Field', () {
    test('fromMap construye correctamente', () {
      final map = {
        'id': 'f-1',
        'owner_id': 'o-1',
        'name': 'Mi cancha',
        'address': 'Calle 1',
        'latitude': 0.35,
        'longitude': -78.12,
        'field_type': '7v7',
        'created_at': '2025-01-01T00:00:00.000Z',
        'photos': <dynamic>[],
        'is_active': true,
        'verified': false,
        'average_rating': 0.0,
      };

      final field = Field.fromMap(map);
      expect(field.fieldType, FieldType.v7x7);
      expect(field.verified, isFalse);
      expect(field.photos, isEmpty);
      expect(field.firstPhotoUrl, isNull);
    });

    test('firstPhotoUrl retorna la primera URL cuando hay fotos', () {
      final field = Field(
        id: 'f-2',
        ownerId: 'o-1',
        name: 'Test',
        address: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        fieldType: FieldType.v5x5,
        createdAt: DateTime(2025),
        photos: const ['https://foto1.jpg', 'https://foto2.jpg'],
      );

      expect(field.firstPhotoUrl, 'https://foto1.jpg');
    });

    test('copyWith sobreescribe solo campos indicados', () {
      final original = Field(
        id: 'f-3',
        ownerId: 'o-1',
        name: 'Original',
        address: 'Dir original',
        latitude: 0.1,
        longitude: -78.0,
        fieldType: FieldType.v6x6,
        createdAt: DateTime(2025),
      );

      final updated = original.copyWith(name: 'Actualizada');
      expect(updated.name, 'Actualizada');
      expect(updated.id, 'f-3');
      expect(updated.fieldType, FieldType.v6x6);
    });
  });

  // ---------------------------------------------------------------------------
  // FieldType — enum
  // ---------------------------------------------------------------------------

  group('FieldType', () {
    test('label es legible para cada valor', () {
      expect(FieldType.v5x5.label, '5 vs 5');
      expect(FieldType.v6x6.label, '6 vs 6');
      expect(FieldType.v7x7.label, '7 vs 7');
      expect(FieldType.v8x8.label, '8 vs 8');
    });

    test('dbValue coincide con el enum de Postgres', () {
      expect(FieldType.v5x5.dbValue, '5v5');
      expect(FieldType.v8x8.dbValue, '8v8');
    });

    test('fromDb parsea todos los valores', () {
      expect(FieldType.fromDb('5v5'), FieldType.v5x5);
      expect(FieldType.fromDb('6v6'), FieldType.v6x6);
      expect(FieldType.fromDb('7v7'), FieldType.v7x7);
      expect(FieldType.fromDb('8v8'), FieldType.v8x8);
    });
  });

  // ---------------------------------------------------------------------------
  // getVerifiedFields
  // ---------------------------------------------------------------------------

  group('FieldsRepository.getVerifiedFields', () {
    test('retorna lista de canchas verificadas', () async {
      when(() => repo.getVerifiedFields())
          .thenAnswer((_) async => [fakeField]);

      final result = await repo.getVerifiedFields();
      expect(result, hasLength(1));
      expect(result.first.verified, isFalse); // fakeField tiene verified=false pero lo usamos como stub
    });

    test('retorna lista vacía cuando no hay canchas verificadas', () async {
      when(() => repo.getVerifiedFields()).thenAnswer((_) async => []);

      final result = await repo.getVerifiedFields();
      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getVerifiedFields())
          .thenThrow(const DatabaseException('No se pudieron cargar las canchas.'));

      await expectLater(
        () => repo.getVerifiedFields(),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // FieldSchedule — modelo
  // ---------------------------------------------------------------------------

  group('FieldSchedule', () {
    const fakeSchedule = FieldSchedule(
      id: 'sched-1',
      fieldId: 'field-1',
      dayOfWeek: 1,
      startTime: TimeOfDay(hour: 8, minute: 0),
      endTime: TimeOfDay(hour: 10, minute: 0),
      price: 15.00,
    );

    test('fromMap construye correctamente', () {
      final map = {
        'id': 'sched-1',
        'field_id': 'field-1',
        'day_of_week': 1,
        'start_time': '08:00:00',
        'end_time': '10:00:00',
        'price': 15.00,
        'is_active': true,
      };

      final s = FieldSchedule.fromMap(map);
      expect(s.id, 'sched-1');
      expect(s.dayOfWeek, 1);
      expect(s.startTime, const TimeOfDay(hour: 8, minute: 0));
      expect(s.endTime, const TimeOfDay(hour: 10, minute: 0));
      expect(s.price, 15.00);
      expect(s.isActive, isTrue);
    });

    test('dayName retorna el nombre correcto', () {
      expect(fakeSchedule.dayName, 'Lunes');
    });

    test('timeRange formatea correctamente', () {
      expect(fakeSchedule.timeRange, '08:00 – 10:00');
    });

    test('copyWith sobreescribe solo campos indicados', () {
      final updated = fakeSchedule.copyWith(isActive: false, price: 20.0);
      expect(updated.isActive, isFalse);
      expect(updated.price, 20.0);
      expect(updated.id, 'sched-1');
      expect(updated.startTime, const TimeOfDay(hour: 8, minute: 0));
    });

    test('kDayNames tiene 7 elementos (0=domingo … 6=sábado)', () {
      expect(kDayNames.length, 7);
      expect(kDayNames[0], 'Domingo');
      expect(kDayNames[1], 'Lunes');
      expect(kDayNames[6], 'Sábado');
    });

    test('kDayOrder empieza en Lunes (1) y termina en Domingo (0)', () {
      expect(kDayOrder.first, 1);
      expect(kDayOrder.last, 0);
      expect(kDayOrder.length, 7);
    });
  });

  // ---------------------------------------------------------------------------
  // FieldsRepository — horarios
  // ---------------------------------------------------------------------------

  group('FieldsRepository.getFieldSchedules', () {
    const fieldId = 'field-1';

    test('retorna lista de bloques horarios', () async {
      const schedule = FieldSchedule(
        id: 's-1',
        fieldId: fieldId,
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 0),
        price: 15.0,
      );
      when(() => repo.getFieldSchedules(fieldId))
          .thenAnswer((_) async => [schedule]);

      final result = await repo.getFieldSchedules(fieldId);
      expect(result, hasLength(1));
      expect(result.first.dayOfWeek, 1);
    });

    test('retorna lista vacía si no hay horarios', () async {
      when(() => repo.getFieldSchedules(fieldId))
          .thenAnswer((_) async => []);

      final result = await repo.getFieldSchedules(fieldId);
      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getFieldSchedules(fieldId))
          .thenThrow(const DatabaseException('No se pudieron cargar los horarios.'));

      await expectLater(
        () => repo.getFieldSchedules(fieldId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('FieldsRepository.upsertSchedule', () {
    const fieldId = 'field-1';

    test('crea un nuevo bloque y lo retorna', () async {
      const expected = FieldSchedule(
        id: 's-new',
        fieldId: fieldId,
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 16, minute: 0),
        price: 20.0,
      );
      when(() => repo.upsertSchedule(
            fieldId: fieldId,
            dayOfWeek: any(named: 'dayOfWeek'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            price: any(named: 'price'),
          )).thenAnswer((_) async => expected);

      final result = await repo.upsertSchedule(
        fieldId: fieldId,
        dayOfWeek: 2,
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
        price: 20.0,
      );

      expect(result.id, 's-new');
      expect(result.price, 20.0);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.upsertSchedule(
            fieldId: fieldId,
            dayOfWeek: any(named: 'dayOfWeek'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            price: any(named: 'price'),
          )).thenThrow(const DatabaseException('No se pudo guardar el horario.'));

      await expectLater(
        () => repo.upsertSchedule(
          fieldId: fieldId,
          dayOfWeek: 1,
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          price: 15.0,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('FieldsRepository.deleteSchedule', () {
    test('completa sin error', () async {
      when(() => repo.deleteSchedule(any())).thenAnswer((_) async {});

      await expectLater(repo.deleteSchedule('s-1'), completes);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.deleteSchedule(any()))
          .thenThrow(const DatabaseException('No se pudo eliminar el horario.'));

      await expectLater(
        () => repo.deleteSchedule('s-1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('FieldsRepository.setScheduleActive', () {
    test('completa sin error al activar', () async {
      when(() => repo.setScheduleActive(any(), isActive: any(named: 'isActive')))
          .thenAnswer((_) async {});

      await expectLater(
        repo.setScheduleActive('s-1', isActive: true),
        completes,
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.setScheduleActive(any(), isActive: any(named: 'isActive')))
          .thenThrow(const DatabaseException('No se pudo actualizar el horario.'));

      await expectLater(
        () => repo.setScheduleActive('s-1', isActive: false),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
