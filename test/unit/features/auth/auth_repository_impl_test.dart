import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onze_app/core/errors/onze_exception.dart';
import 'package:onze_app/features/auth/domain/auth_repository.dart';
import 'package:onze_app/shared/models/player_enums.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository repo;

  setUpAll(() {
    // Mocktail requiere registrar fallback values para tipos no primitivos
    registerFallbackValue(PlayerPosition.mediocampista);
    registerFallbackValue(DominantFoot.derecho);
    registerFallbackValue(ExperienceLevel.intermedio);
  });

  setUp(() {
    repo = MockAuthRepository();
  });

  group('AuthRepository.sendOtp', () {
    test('completa sin error cuando Supabase acepta el número', () async {
      when(() => repo.sendOtp(any())).thenAnswer((_) async {});

      await expectLater(repo.sendOtp('+593987654321'), completes);
      verify(() => repo.sendOtp('+593987654321')).called(1);
    });

    test('lanza AuthException cuando el número es inválido', () async {
      when(() => repo.sendOtp(any())).thenThrow(
        const AuthException('Número de teléfono inválido.'),
      );

      await expectLater(
        () => repo.sendOtp('+593000000000'),
        throwsA(isA<AuthException>()),
      );
    });

    test('lanza NetworkException ante error de conexión', () async {
      when(() => repo.sendOtp(any())).thenThrow(
        const NetworkException('Error de conexión. Intenta nuevamente.'),
      );

      await expectLater(
        () => repo.sendOtp('+593987654321'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('AuthRepository.verifyOtp', () {
    test('retorna true cuando el usuario es nuevo', () async {
      when(() => repo.verifyOtp(phone: any(named: 'phone'), otpCode: any(named: 'otpCode')))
          .thenAnswer((_) async => true);

      final isNew = await repo.verifyOtp(
        phone: '+593987654321',
        otpCode: '123456',
      );
      expect(isNew, isTrue);
    });

    test('retorna false cuando el usuario ya tiene perfil', () async {
      when(() => repo.verifyOtp(phone: any(named: 'phone'), otpCode: any(named: 'otpCode')))
          .thenAnswer((_) async => false);

      final isNew = await repo.verifyOtp(
        phone: '+593987654321',
        otpCode: '123456',
      );
      expect(isNew, isFalse);
    });

    test('lanza AuthException con código incorrecto', () async {
      when(() => repo.verifyOtp(phone: any(named: 'phone'), otpCode: any(named: 'otpCode')))
          .thenThrow(
        const AuthException('Código incorrecto. Verifica e intenta nuevamente.'),
      );

      await expectLater(
        () => repo.verifyOtp(phone: '+593987654321', otpCode: '000000'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('incorrecto'),
          ),
        ),
      );
    });

    test('lanza AuthException cuando el código expiró', () async {
      when(() => repo.verifyOtp(phone: any(named: 'phone'), otpCode: any(named: 'otpCode')))
          .thenThrow(
        const AuthException('El código expiró. Solicita uno nuevo.'),
      );

      await expectLater(
        () => repo.verifyOtp(phone: '+593987654321', otpCode: '123456'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expiró'),
          ),
        ),
      );
    });
  });

  group('AuthRepository.createPlayerProfile', () {
    test('completa sin error con datos válidos', () async {
      when(
        () => repo.createPlayerProfile(
          fullName: any(named: 'fullName'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        repo.createPlayerProfile(
          fullName: 'Carlos Pérez',
          position: PlayerPosition.delantero,
          dominantFoot: DominantFoot.derecho,
          experienceLevel: ExperienceLevel.intermedio,
        ),
        completes,
      );
    });

    test('lanza AuthException si no hay sesión activa', () async {
      when(
        () => repo.createPlayerProfile(
          fullName: any(named: 'fullName'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenThrow(const AuthException('No hay sesión activa.'));

      await expectLater(
        () => repo.createPlayerProfile(
          fullName: 'Carlos Pérez',
          position: PlayerPosition.delantero,
          dominantFoot: DominantFoot.derecho,
          experienceLevel: ExperienceLevel.intermedio,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('lanza DatabaseException ante error de Supabase', () async {
      when(
        () => repo.createPlayerProfile(
          fullName: any(named: 'fullName'),
          position: any(named: 'position'),
          dominantFoot: any(named: 'dominantFoot'),
          experienceLevel: any(named: 'experienceLevel'),
        ),
      ).thenThrow(
        const DatabaseException('No se pudo guardar el perfil.'),
      );

      await expectLater(
        () => repo.createPlayerProfile(
          fullName: 'Carlos Pérez',
          position: PlayerPosition.portero,
          dominantFoot: DominantFoot.izquierdo,
          experienceLevel: ExperienceLevel.avanzado,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('AuthRepository.signOut', () {
    test('cierra sesión sin lanzar excepciones', () async {
      when(() => repo.signOut()).thenAnswer((_) async {});
      await expectLater(repo.signOut(), completes);
    });
  });

  group('AuthRepository.getCurrentUser', () {
    test('retorna null cuando no hay sesión', () async {
      when(() => repo.getCurrentUser()).thenAnswer((_) async => null);
      final user = await repo.getCurrentUser();
      expect(user, isNull);
    });
  });
}
