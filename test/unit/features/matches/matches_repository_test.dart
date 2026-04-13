import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:onze_app/core/errors/onze_exception.dart';
import 'package:onze_app/features/fields/domain/models/field_schedule.dart';
import 'package:onze_app/features/matches/domain/matches_repository.dart';
import 'package:onze_app/features/matches/domain/models/match_request.dart';
import 'package:onze_app/features/teams/domain/models/team.dart';

class MockMatchesRepository extends Mock implements MatchesRepository {}

void main() {
  late MockMatchesRepository repo;

  setUpAll(() {
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
    registerFallbackValue(DateTime(2025));
  });

  setUp(() => repo = MockMatchesRepository());

  // ---------------------------------------------------------------------------
  // MatchRequestStatus
  // ---------------------------------------------------------------------------

  group('MatchRequestStatus', () {
    test('fromDb parsea todos los valores', () {
      expect(MatchRequestStatus.fromDb('pending_opponent'),
          MatchRequestStatus.pendingOpponent);
      expect(MatchRequestStatus.fromDb('pending_owner'),
          MatchRequestStatus.pendingOwner);
      expect(MatchRequestStatus.fromDb('confirmed'),
          MatchRequestStatus.confirmed);
      expect(MatchRequestStatus.fromDb('rejected'),
          MatchRequestStatus.rejected);
      expect(MatchRequestStatus.fromDb('expired'), MatchRequestStatus.expired);
      expect(
          MatchRequestStatus.fromDb('cancelled'), MatchRequestStatus.cancelled);
    });

    test('dbValue coincide con el valor de la DB', () {
      expect(MatchRequestStatus.pendingOpponent.dbValue, 'pending_opponent');
      expect(MatchRequestStatus.pendingOwner.dbValue, 'pending_owner');
      expect(MatchRequestStatus.confirmed.dbValue, 'confirmed');
    });

    test('fromDb lanza ArgumentError para valor desconocido', () {
      expect(() => MatchRequestStatus.fromDb('unknown'),
          throwsA(isA<ArgumentError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // MatchRequest — modelo
  // ---------------------------------------------------------------------------

  group('MatchRequest', () {
    final fakeRequest = MatchRequest(
      id: 'req-1',
      challengerTeamId: 'team-1',
      challengedTeamId: 'team-2',
      fieldId: 'field-1',
      requestedDate: DateTime(2025, 6, 14),
      requestedStartTime: const TimeOfDay(hour: 8, minute: 0),
      requestedEndTime: const TimeOfDay(hour: 10, minute: 0),
      price: 30.0,
      status: MatchRequestStatus.pendingOpponent,
      createdAt: DateTime(2025, 6, 1),
      challengerTeamName: 'Los Pumas',
      challengedTeamName: 'Los Tigres',
      fieldName: 'Cancha Norte',
    );

    test('fromMap construye correctamente', () {
      final map = {
        'id': 'req-1',
        'challenger_team_id': 'team-1',
        'challenged_team_id': 'team-2',
        'field_id': 'field-1',
        'requested_date': '2025-06-14',
        'requested_start_time': '08:00:00',
        'requested_end_time': '10:00:00',
        'price': 30.0,
        'status': 'pending_opponent',
        'blocked_until': null,
        'created_at': '2025-06-01T00:00:00.000Z',
        'challenger_team': {'id': 'team-1', 'name': 'Los Pumas'},
        'challenged_team': {'id': 'team-2', 'name': 'Los Tigres'},
        'field': {'id': 'field-1', 'name': 'Cancha Norte', 'address': 'Av. X'},
      };

      final req = MatchRequest.fromMap(map);
      expect(req.id, 'req-1');
      expect(req.status, MatchRequestStatus.pendingOpponent);
      expect(req.requestedStartTime, const TimeOfDay(hour: 8, minute: 0));
      expect(req.price, 30.0);
      expect(req.challengerTeamName, 'Los Pumas');
      expect(req.fieldName, 'Cancha Norte');
    });

    test('timeRange formatea correctamente', () {
      expect(fakeRequest.timeRange, '08:00 – 10:00');
    });

    test('isExpired es falso cuando status no es pending_owner', () {
      expect(fakeRequest.isExpired, isFalse);
    });

    test('isExpired es verdadero cuando blockedUntil ya pasó', () {
      final req = MatchRequest(
        id: 'req-2',
        challengerTeamId: 'team-1',
        challengedTeamId: 'team-2',
        fieldId: 'field-1',
        requestedDate: DateTime(2025, 6, 14),
        requestedStartTime: const TimeOfDay(hour: 8, minute: 0),
        requestedEndTime: const TimeOfDay(hour: 10, minute: 0),
        price: 30.0,
        status: MatchRequestStatus.pendingOwner,
        blockedUntil: DateTime.now().subtract(const Duration(minutes: 1)),
        createdAt: DateTime(2025, 6, 1),
      );
      expect(req.isExpired, isTrue);
    });

    test('isExpired es falso cuando blockedUntil es futuro', () {
      final req = MatchRequest(
        id: 'req-3',
        challengerTeamId: 'team-1',
        challengedTeamId: 'team-2',
        fieldId: 'field-1',
        requestedDate: DateTime(2025, 6, 14),
        requestedStartTime: const TimeOfDay(hour: 8, minute: 0),
        requestedEndTime: const TimeOfDay(hour: 10, minute: 0),
        price: 30.0,
        status: MatchRequestStatus.pendingOwner,
        blockedUntil: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime(2025, 6, 1),
      );
      expect(req.isExpired, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // sendChallenge
  // ---------------------------------------------------------------------------

  group('MatchesRepository.sendChallenge', () {
    final fakeResult = MatchRequest(
      id: 'req-new',
      challengerTeamId: 'team-1',
      challengedTeamId: 'team-2',
      fieldId: 'field-1',
      requestedDate: DateTime(2025, 6, 14),
      requestedStartTime: const TimeOfDay(hour: 8, minute: 0),
      requestedEndTime: const TimeOfDay(hour: 10, minute: 0),
      price: 30.0,
      status: MatchRequestStatus.pendingOpponent,
      createdAt: DateTime(2025, 6, 1),
    );

    test('retorna el desafío creado', () async {
      when(() => repo.sendChallenge(
            challengerTeamId: any(named: 'challengerTeamId'),
            challengedTeamId: any(named: 'challengedTeamId'),
            fieldId: any(named: 'fieldId'),
            date: any(named: 'date'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            price: any(named: 'price'),
          )).thenAnswer((_) async => fakeResult);

      final result = await repo.sendChallenge(
        challengerTeamId: 'team-1',
        challengedTeamId: 'team-2',
        fieldId: 'field-1',
        date: DateTime(2025, 6, 14),
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        price: 30.0,
      );

      expect(result.id, 'req-new');
      expect(result.status, MatchRequestStatus.pendingOpponent);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.sendChallenge(
            challengerTeamId: any(named: 'challengerTeamId'),
            challengedTeamId: any(named: 'challengedTeamId'),
            fieldId: any(named: 'fieldId'),
            date: any(named: 'date'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            price: any(named: 'price'),
          )).thenThrow(const DatabaseException('No se pudo enviar el desafío.'));

      await expectLater(
        () => repo.sendChallenge(
          challengerTeamId: 'team-1',
          challengedTeamId: 'team-2',
          fieldId: 'field-1',
          date: DateTime(2025, 6, 14),
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          price: 30.0,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Listas de solicitudes
  // ---------------------------------------------------------------------------

  group('MatchesRepository.getChallengesAsChallenger', () {
    test('retorna lista para los teamIds dados', () async {
      when(() => repo.getChallengesAsChallenger(any()))
          .thenAnswer((_) async => []);

      final result = await repo.getChallengesAsChallenger(['team-1']);
      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error', () async {
      when(() => repo.getChallengesAsChallenger(any()))
          .thenThrow(const DatabaseException('Error.'));

      await expectLater(
        () => repo.getChallengesAsChallenger(['team-1']),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MatchesRepository.getChallengesAsChallenged', () {
    test('retorna lista vacía para teamIds vacíos', () async {
      when(() => repo.getChallengesAsChallenged(any()))
          .thenAnswer((_) async => []);

      expect(await repo.getChallengesAsChallenged([]), isEmpty);
    });
  });

  group('MatchesRepository.getPendingOwnerRequests', () {
    test('retorna solicitudes en pending_owner', () async {
      when(() => repo.getPendingOwnerRequests(any()))
          .thenAnswer((_) async => []);

      expect(await repo.getPendingOwnerRequests('owner-1'), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  group('MatchesRepository.acceptChallenge', () {
    test('completa sin error', () async {
      when(() => repo.acceptChallenge(any())).thenAnswer((_) async {});
      await expectLater(repo.acceptChallenge('req-1'), completes);
    });

    test('lanza DatabaseException ante error', () async {
      when(() => repo.acceptChallenge(any()))
          .thenThrow(const DatabaseException('No se pudo aceptar.'));

      await expectLater(
        () => repo.acceptChallenge('req-1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MatchesRepository.rejectChallenge', () {
    test('completa sin error', () async {
      when(() => repo.rejectChallenge(any())).thenAnswer((_) async {});
      await expectLater(repo.rejectChallenge('req-1'), completes);
    });
  });

  group('MatchesRepository.cancelChallenge', () {
    test('completa sin error', () async {
      when(() => repo.cancelChallenge(any())).thenAnswer((_) async {});
      await expectLater(repo.cancelChallenge('req-1'), completes);
    });
  });

  group('MatchesRepository.confirmMatch', () {
    test('completa sin error', () async {
      when(() => repo.confirmMatch(any())).thenAnswer((_) async {});
      await expectLater(repo.confirmMatch('req-1'), completes);
    });

    test('lanza DatabaseException con mensaje de expirado', () async {
      when(() => repo.confirmMatch(any())).thenThrow(
          const DatabaseException('El bloqueo expiró.'));

      await expectLater(
        () => repo.confirmMatch('req-1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MatchesRepository.rejectMatchByOwner', () {
    test('completa sin error', () async {
      when(() => repo.rejectMatchByOwner(any())).thenAnswer((_) async {});
      await expectLater(repo.rejectMatchByOwner('req-1'), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // getAvailableSlotsForDate
  // ---------------------------------------------------------------------------

  group('MatchesRepository.getAvailableSlotsForDate', () {
    test('retorna lista de slots disponibles', () async {
      const slot = FieldSchedule(
        id: 's-1',
        fieldId: 'field-1',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 0),
        price: 15.0,
      );
      when(() => repo.getAvailableSlotsForDate(
            fieldId: any(named: 'fieldId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => [slot]);

      final result = await repo.getAvailableSlotsForDate(
        fieldId: 'field-1',
        date: DateTime(2025, 6, 14),
      );

      expect(result, hasLength(1));
      expect(result.first.startTime, const TimeOfDay(hour: 8, minute: 0));
    });

    test('retorna lista vacía cuando no hay slots', () async {
      when(() => repo.getAvailableSlotsForDate(
            fieldId: any(named: 'fieldId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => []);

      expect(
        await repo.getAvailableSlotsForDate(
            fieldId: 'field-1', date: DateTime(2025, 6, 14)),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // searchTeams
  // ---------------------------------------------------------------------------

  group('MatchesRepository.searchTeams', () {
    final fakeTeam = Team(
      id: 'team-99',
      name: 'Los Cóndores',
      captainId: 'user-1',
      createdAt: DateTime(2025),
    );

    test('retorna equipos que coinciden', () async {
      when(() => repo.searchTeams(any(),
              excludeTeamId: any(named: 'excludeTeamId')))
          .thenAnswer((_) async => [fakeTeam]);

      final result =
          await repo.searchTeams('cóndor', excludeTeamId: 'team-1');

      expect(result, hasLength(1));
      expect(result.first.name, 'Los Cóndores');
    });

    test('retorna vacío si la consulta tiene menos de 2 caracteres', () async {
      when(() => repo.searchTeams(any(),
              excludeTeamId: any(named: 'excludeTeamId')))
          .thenAnswer((_) async => []);

      expect(
          await repo.searchTeams('a', excludeTeamId: 'team-1'), isEmpty);
    });
  });
}
