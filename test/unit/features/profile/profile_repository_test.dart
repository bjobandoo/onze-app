import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:onze_app/core/errors/onze_exception.dart';
import 'package:onze_app/features/profile/domain/models/player_profile.dart';
import 'package:onze_app/features/profile/domain/models/player_stats.dart';
import 'package:onze_app/features/profile/domain/profile_repository.dart';
import 'package:onze_app/shared/models/player_enums.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository repo;

  setUpAll(() {
    registerFallbackValue(PlayerPosition.mediocampista);
    registerFallbackValue(DominantFoot.derecho);
    registerFallbackValue(ExperienceLevel.intermedio);
  });

  setUp(() => repo = MockProfileRepository());

  // ---------------------------------------------------------------------------
  // getPlayerProfile
  // ---------------------------------------------------------------------------

  group('ProfileRepository.getPlayerProfile', () {
    const userId = 'user-123';

    test('retorna el perfil del jugador cuando existe', () async {
      const expected = PlayerProfile(
        userId: userId,
        position: PlayerPosition.delantero,
        dominantFoot: DominantFoot.derecho,
        experienceLevel: ExperienceLevel.avanzado,
        bio: 'Me gusta jugar al fútbol',
      );
      when(() => repo.getPlayerProfile(userId))
          .thenAnswer((_) async => expected);

      final result = await repo.getPlayerProfile(userId);

      expect(result, isNotNull);
      expect(result!.position, PlayerPosition.delantero);
      expect(result.bio, 'Me gusta jugar al fútbol');
    });

    test('retorna null cuando el usuario no tiene perfil', () async {
      when(() => repo.getPlayerProfile(userId)).thenAnswer((_) async => null);

      final result = await repo.getPlayerProfile(userId);

      expect(result, isNull);
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(() => repo.getPlayerProfile(userId))
          .thenThrow(const DatabaseException('No se pudo cargar el perfil.'));

      await expectLater(
        () => repo.getPlayerProfile(userId),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getPlayerStats
  // ---------------------------------------------------------------------------

  group('ProfileRepository.getPlayerStats', () {
    const userId = 'user-456';

    test('retorna estadísticas del jugador', () async {
      const expected = PlayerStats(
        wins: 10,
        losses: 3,
        draws: 2,
        matchesPlayed: 15,
      );
      when(() => repo.getPlayerStats(userId)).thenAnswer((_) async => expected);

      final result = await repo.getPlayerStats(userId);

      expect(result.matchesPlayed, 15);
      expect(result.wins, 10);
      expect(result.winRate, closeTo(10 / 15, 0.001));
    });

    test('retorna estadísticas vacías cuando el usuario no tiene partidos',
        () async {
      when(() => repo.getPlayerStats(userId))
          .thenAnswer((_) async => const PlayerStats());

      final result = await repo.getPlayerStats(userId);

      expect(result.matchesPlayed, 0);
      expect(result.winRate, 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // updateProfile
  // ---------------------------------------------------------------------------

  group('ProfileRepository.updateProfile', () {
    const userId = 'user-789';

    test('completa sin error cuando todos los campos son válidos', () async {
      when(
        () => repo.updateProfile(
          userId: any(named: 'userId'),
          fullName: any(named: 'fullName'),
          bio: any(named: 'bio'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.updateProfile(
          userId: userId,
          fullName: 'Carlos Pérez',
          bio: 'Delantero agresivo',
          position: PlayerPosition.delantero,
          dominantFoot: DominantFoot.derecho,
          experienceLevel: ExperienceLevel.avanzado,
        ),
        completes,
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(
        () => repo.updateProfile(
          userId: any(named: 'userId'),
          fullName: any(named: 'fullName'),
          bio: any(named: 'bio'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenThrow(
        const DatabaseException('No se pudo guardar los cambios.'),
      );

      await expectLater(
        () => repo.updateProfile(
          userId: userId,
          fullName: 'Carlos Pérez',
          position: PlayerPosition.portero,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('lanza NetworkException ante error de conexión', () async {
      when(
        () => repo.updateProfile(
          userId: any(named: 'userId'),
          fullName: any(named: 'fullName'),
          bio: any(named: 'bio'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenThrow(
        const NetworkException('Error de conexión. Intenta nuevamente.'),
      );

      await expectLater(
        () => repo.updateProfile(userId: userId),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PlayerStats — cálculos internos
  // ---------------------------------------------------------------------------

  group('PlayerStats', () {
    test('winRate es 0 cuando no hay partidos jugados', () {
      const stats = PlayerStats();
      expect(stats.winRate, 0.0);
    });

    test('winRate es 1.0 cuando se ganaron todos los partidos', () {
      const stats = PlayerStats(wins: 5, matchesPlayed: 5);
      expect(stats.winRate, 1.0);
    });

    test('winRate calcula correctamente con mezcla de resultados', () {
      const stats = PlayerStats(
        wins: 3,
        losses: 1,
        draws: 1,
        matchesPlayed: 5,
      );
      expect(stats.winRate, closeTo(0.6, 0.001));
    });

    test('fromMap construye correctamente desde mapa de Supabase', () {
      final map = {
        'wins': 7,
        'losses': 2,
        'draws': 1,
        'matches_played': 10,
      };
      final stats = PlayerStats.fromMap(map);
      expect(stats.wins, 7);
      expect(stats.matchesPlayed, 10);
      expect(stats.winRate, closeTo(0.7, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // PlayerProfile — fromMap y copyWith
  // ---------------------------------------------------------------------------

  group('PlayerProfile', () {
    test('fromMap construye correctamente desde mapa de Supabase', () {
      final map = {
        'user_id': 'u-1',
        'position': 'portero',
        'dominant_foot': 'izquierdo',
        'experience_level': 'avanzado',
        'bio': 'Arquero experimentado',
      };
      final profile = PlayerProfile.fromMap(map);
      expect(profile.position, PlayerPosition.portero);
      expect(profile.dominantFoot, DominantFoot.izquierdo);
      expect(profile.experienceLevel, ExperienceLevel.avanzado);
      expect(profile.bio, 'Arquero experimentado');
    });

    test('fromMap maneja campos nulos correctamente', () {
      final map = {'user_id': 'u-2'};
      final profile = PlayerProfile.fromMap(map);
      expect(profile.position, isNull);
      expect(profile.dominantFoot, isNull);
      expect(profile.bio, isNull);
    });

    test('copyWith sobreescribe solo los campos indicados', () {
      const original = PlayerProfile(
        userId: 'u-3',
        position: PlayerPosition.defensa,
        bio: 'Original',
      );
      final updated = original.copyWith(bio: 'Actualizado');
      expect(updated.bio, 'Actualizado');
      expect(updated.position, PlayerPosition.defensa);
      expect(updated.userId, 'u-3');
    });
  });
}
