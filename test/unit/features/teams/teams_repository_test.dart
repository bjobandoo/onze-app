import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:onze_app/core/errors/onze_exception.dart';
import 'package:onze_app/features/teams/domain/models/team.dart';
import 'package:onze_app/features/teams/domain/models/team_join_request.dart';
import 'package:onze_app/features/teams/domain/models/team_member.dart';
import 'package:onze_app/features/teams/domain/models/team_enums.dart';
import 'package:onze_app/features/teams/domain/teams_repository.dart';
import 'package:onze_app/shared/models/app_user.dart';

class MockTeamsRepository extends Mock implements TeamsRepository {}

void main() {
  late MockTeamsRepository repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() => repo = MockTeamsRepository());

  // ---------------------------------------------------------------------------
  // getMyTeams
  // ---------------------------------------------------------------------------

  group('TeamsRepository.getMyTeams', () {
    const userId = 'user-1';

    final fakeTeam = Team(
      id: 'team-1',
      name: 'Los Cóndores',
      captainId: userId,
      createdAt: DateTime(2025),
    );

    test('retorna lista de equipos del usuario', () async {
      when(() => repo.getMyTeams(userId))
          .thenAnswer((_) async => [fakeTeam]);

      final result = await repo.getMyTeams(userId);

      expect(result, hasLength(1));
      expect(result.first.name, 'Los Cóndores');
      expect(result.first.captainId, userId);
    });

    test('retorna lista vacía cuando el usuario no tiene equipos', () async {
      when(() => repo.getMyTeams(userId)).thenAnswer((_) async => []);

      final result = await repo.getMyTeams(userId);

      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getMyTeams(userId))
          .thenThrow(const DatabaseException('No se pudieron cargar los equipos.'));

      await expectLater(
        () => repo.getMyTeams(userId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getCaptainTeamsCount
  // ---------------------------------------------------------------------------

  group('TeamsRepository.getCaptainTeamsCount', () {
    const userId = 'user-2';

    test('retorna 0 cuando el usuario no es capitán de ningún equipo',
        () async {
      when(() => repo.getCaptainTeamsCount(userId))
          .thenAnswer((_) async => 0);

      final count = await repo.getCaptainTeamsCount(userId);
      expect(count, 0);
    });

    test('retorna 2 cuando el usuario ya es capitán de 2 equipos', () async {
      when(() => repo.getCaptainTeamsCount(userId))
          .thenAnswer((_) async => 2);

      final count = await repo.getCaptainTeamsCount(userId);
      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // createTeam
  // ---------------------------------------------------------------------------

  group('TeamsRepository.createTeam', () {
    const captainId = 'user-3';

    final createdTeam = Team(
      id: 'team-new',
      name: 'Nuevo Equipo',
      captainId: captainId,
      createdAt: DateTime(2025),
    );

    test('crea el equipo y lo devuelve', () async {
      when(
        () => repo.createTeam(
          captainId: captainId,
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => createdTeam);

      final result = await repo.createTeam(
        captainId: captainId,
        name: 'Nuevo Equipo',
      );

      expect(result.id, 'team-new');
      expect(result.name, 'Nuevo Equipo');
      expect(result.captainId, captainId);
    });

    test('lanza PermissionException cuando el usuario ya tiene 2 equipos',
        () async {
      when(
        () => repo.createTeam(
          captainId: captainId,
          name: any(named: 'name'),
        ),
      ).thenThrow(
        const PermissionException(
          'Ya eres capitán de 2 equipos. No puedes crear más.',
        ),
      );

      await expectLater(
        () => repo.createTeam(captainId: captainId, name: 'Tercer Equipo'),
        throwsA(isA<PermissionException>()),
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(
        () => repo.createTeam(
          captainId: captainId,
          name: any(named: 'name'),
        ),
      ).thenThrow(const DatabaseException('No se pudo crear el equipo.'));

      await expectLater(
        () => repo.createTeam(captainId: captainId, name: 'Equipo'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getTeamMembers
  // ---------------------------------------------------------------------------

  group('TeamsRepository.getTeamMembers', () {
    const teamId = 'team-10';

    final fakeMember = TeamMember(
      teamId: teamId,
      userId: 'user-5',
      role: TeamMemberRole.member,
      joinedAt: DateTime(2025),
      userFullName: 'Juan Pérez',
    );

    final fakeCaptain = TeamMember(
      teamId: teamId,
      userId: 'user-6',
      role: TeamMemberRole.captain,
      joinedAt: DateTime(2025),
      userFullName: 'Ana García',
    );

    test('retorna miembros del equipo', () async {
      when(() => repo.getTeamMembers(teamId))
          .thenAnswer((_) async => [fakeCaptain, fakeMember]);

      final members = await repo.getTeamMembers(teamId);

      expect(members, hasLength(2));
      expect(members.first.isCaptain, isTrue);
      expect(members.last.isCaptain, isFalse);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getTeamMembers(teamId))
          .thenThrow(const DatabaseException('No se pudieron cargar los miembros.'));

      await expectLater(
        () => repo.getTeamMembers(teamId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // inviteMember / requestToJoin
  // ---------------------------------------------------------------------------

  group('TeamsRepository.inviteMember', () {
    test('completa sin error', () async {
      when(
        () => repo.inviteMember(
          teamId: any(named: 'teamId'),
          invitedUserId: any(named: 'invitedUserId'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.inviteMember(teamId: 'team-1', invitedUserId: 'user-99'),
        completes,
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(
        () => repo.inviteMember(
          teamId: any(named: 'teamId'),
          invitedUserId: any(named: 'invitedUserId'),
        ),
      ).thenThrow(const DatabaseException('No se pudo enviar la invitación.'));

      await expectLater(
        () => repo.inviteMember(teamId: 'team-1', invitedUserId: 'user-99'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('TeamsRepository.requestToJoin', () {
    test('completa sin error', () async {
      when(
        () => repo.requestToJoin(
          teamId: any(named: 'teamId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.requestToJoin(teamId: 'team-1', userId: 'user-77'),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // acceptJoinRequest / rejectJoinRequest
  // ---------------------------------------------------------------------------

  group('TeamsRepository.acceptJoinRequest', () {
    const requestId = 'req-1';

    test('completa sin error al aceptar', () async {
      when(() => repo.acceptJoinRequest(requestId))
          .thenAnswer((_) async {});

      await expectLater(repo.acceptJoinRequest(requestId), completes);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.acceptJoinRequest(requestId))
          .thenThrow(const DatabaseException('No se pudo aceptar la solicitud.'));

      await expectLater(
        () => repo.acceptJoinRequest(requestId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('TeamsRepository.rejectJoinRequest', () {
    const requestId = 'req-2';

    test('completa sin error al rechazar', () async {
      when(() => repo.rejectJoinRequest(requestId))
          .thenAnswer((_) async {});

      await expectLater(repo.rejectJoinRequest(requestId), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // getMyPendingInvitations
  // ---------------------------------------------------------------------------

  group('TeamsRepository.getMyPendingInvitations', () {
    const userId = 'user-inv';

    final fakeInvitation = TeamJoinRequest(
      id: 'req-inv-1',
      teamId: 'team-A',
      userId: userId,
      type: JoinRequestType.invitation,
      status: JoinRequestStatus.pending,
      createdAt: DateTime(2025),
      teamName: 'Los Halcones',
    );

    test('retorna invitaciones pendientes del usuario', () async {
      when(() => repo.getMyPendingInvitations(userId))
          .thenAnswer((_) async => [fakeInvitation]);

      final result = await repo.getMyPendingInvitations(userId);

      expect(result, hasLength(1));
      expect(result.first.type, JoinRequestType.invitation);
      expect(result.first.status, JoinRequestStatus.pending);
      expect(result.first.teamName, 'Los Halcones');
    });

    test('retorna lista vacía cuando no hay invitaciones', () async {
      when(() => repo.getMyPendingInvitations(userId))
          .thenAnswer((_) async => []);

      final result = await repo.getMyPendingInvitations(userId);
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getPendingRequestsForTeam
  // ---------------------------------------------------------------------------

  group('TeamsRepository.getPendingRequestsForTeam', () {
    const teamId = 'team-B';

    final fakeRequest = TeamJoinRequest(
      id: 'req-join-1',
      teamId: teamId,
      userId: 'user-candidate',
      type: JoinRequestType.request,
      status: JoinRequestStatus.pending,
      createdAt: DateTime(2025),
      userFullName: 'Carlos Ruiz',
    );

    test('retorna solicitudes pendientes del equipo', () async {
      when(() => repo.getPendingRequestsForTeam(teamId))
          .thenAnswer((_) async => [fakeRequest]);

      final result = await repo.getPendingRequestsForTeam(teamId);

      expect(result, hasLength(1));
      expect(result.first.type, JoinRequestType.request);
      expect(result.first.userFullName, 'Carlos Ruiz');
    });
  });

  // ---------------------------------------------------------------------------
  // removeMember / leaveTeam
  // ---------------------------------------------------------------------------

  group('TeamsRepository.removeMember', () {
    test('completa sin error', () async {
      when(
        () => repo.removeMember(
          teamId: any(named: 'teamId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.removeMember(teamId: 'team-1', userId: 'user-remove'),
        completes,
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(
        () => repo.removeMember(
          teamId: any(named: 'teamId'),
          userId: any(named: 'userId'),
        ),
      ).thenThrow(const DatabaseException('No se pudo expulsar al miembro.'));

      await expectLater(
        () => repo.removeMember(teamId: 'team-1', userId: 'user-remove'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('TeamsRepository.leaveTeam', () {
    test('completa sin error', () async {
      when(
        () => repo.leaveTeam(
          teamId: any(named: 'teamId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.leaveTeam(teamId: 'team-1', userId: 'user-leave'),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // uploadTeamShield
  // ---------------------------------------------------------------------------

  group('TeamsRepository.uploadTeamShield', () {
    const teamId = 'team-shield';
    final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

    test('retorna URL pública tras subir el escudo', () async {
      const expectedUrl =
          'https://supabase.co/storage/team-shields/team-shield.jpg';
      when(() => repo.uploadTeamShield(
            teamId: teamId,
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async => expectedUrl);

      final url =
          await repo.uploadTeamShield(teamId: teamId, bytes: fakeBytes);

      expect(url, expectedUrl);
    });

    test('lanza DatabaseException ante error de Storage', () async {
      when(() => repo.uploadTeamShield(
            teamId: teamId,
            bytes: any(named: 'bytes'),
          )).thenThrow(const DatabaseException('No se pudo subir el escudo.'));

      await expectLater(
        () => repo.uploadTeamShield(teamId: teamId, bytes: fakeBytes),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // searchUsers
  // ---------------------------------------------------------------------------

  group('TeamsRepository.searchUsers', () {
    const excludeId = 'current-user';

    const fakeUser = AppUser(
      id: 'user-found',
      phone: '+593987654321',
      fullName: 'Pedro Almeida',
      roles: ['player'],
      isSuspended: false,
    );

    test('retorna lista de usuarios que coinciden con la query', () async {
      when(() => repo.searchUsers(
            any(),
            excludeUserId: any(named: 'excludeUserId'),
          )).thenAnswer((_) async => [fakeUser]);

      final result = await repo.searchUsers(
        'Pedro',
        excludeUserId: excludeId,
      );

      expect(result, hasLength(1));
      expect(result.first.fullName, 'Pedro Almeida');
      expect(result.first.id, 'user-found');
    });

    test('retorna lista vacía cuando no hay coincidencias', () async {
      when(() => repo.searchUsers(
            any(),
            excludeUserId: any(named: 'excludeUserId'),
          )).thenAnswer((_) async => []);

      final result = await repo.searchUsers(
        'XYZDesconocido',
        excludeUserId: excludeId,
      );

      expect(result, isEmpty);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.searchUsers(
            any(),
            excludeUserId: any(named: 'excludeUserId'),
          )).thenThrow(
        const DatabaseException('No se pudo realizar la búsqueda.'),
      );

      await expectLater(
        () => repo.searchUsers('Pedro', excludeUserId: excludeId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Team — modelo
  // ---------------------------------------------------------------------------

  group('Team', () {
    test('fromMap construye correctamente', () {
      final map = {
        'id': 'team-map',
        'name': 'Los Toros',
        'captain_id': 'cap-1',
        'created_at': '2025-01-01T00:00:00.000Z',
        'shield_url': null,
        'is_active': true,
      };
      final team = Team.fromMap(map);
      expect(team.id, 'team-map');
      expect(team.name, 'Los Toros');
      expect(team.captainId, 'cap-1');
      expect(team.isActive, isTrue);
      expect(team.shieldUrl, isNull);
    });

    test('copyWith sobreescribe solo campos indicados', () {
      final original = Team(
        id: 't-1',
        name: 'Original',
        captainId: 'cap',
        createdAt: DateTime(2025),
      );
      final updated = original.copyWith(name: 'Actualizado');
      expect(updated.name, 'Actualizado');
      expect(updated.id, 't-1');
      expect(updated.captainId, 'cap');
    });
  });

  // ---------------------------------------------------------------------------
  // TeamMember — modelo
  // ---------------------------------------------------------------------------

  group('TeamMember', () {
    test('isCaptain es true solo para role captain', () {
      final captain = TeamMember(
        teamId: 't-1',
        userId: 'u-1',
        role: TeamMemberRole.captain,
        joinedAt: DateTime(2025),
        userFullName: 'Ana',
      );
      final member = TeamMember(
        teamId: 't-1',
        userId: 'u-2',
        role: TeamMemberRole.member,
        joinedAt: DateTime(2025),
        userFullName: 'Luis',
      );
      expect(captain.isCaptain, isTrue);
      expect(member.isCaptain, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TeamMemberRole — enums
  // ---------------------------------------------------------------------------

  group('TeamMemberRole', () {
    test('label correcto para cada valor', () {
      expect(TeamMemberRole.captain.label, 'Capitán');
      expect(TeamMemberRole.member.label, 'Miembro');
    });

    test('dbValue coincide con name', () {
      expect(TeamMemberRole.captain.dbValue, 'captain');
      expect(TeamMemberRole.member.dbValue, 'member');
    });

    test('fromDb parsea correctamente', () {
      expect(TeamMemberRole.fromDb('captain'), TeamMemberRole.captain);
      expect(TeamMemberRole.fromDb('member'), TeamMemberRole.member);
    });
  });

  group('JoinRequestStatus', () {
    test('fromDb parsea todos los valores', () {
      expect(JoinRequestStatus.fromDb('pending'), JoinRequestStatus.pending);
      expect(JoinRequestStatus.fromDb('accepted'), JoinRequestStatus.accepted);
      expect(JoinRequestStatus.fromDb('rejected'), JoinRequestStatus.rejected);
    });
  });
}
