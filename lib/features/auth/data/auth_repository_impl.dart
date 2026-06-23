import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/player_enums.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/auth_repository.dart';

/// Implementación de [AuthRepository] usando Supabase Auth y public.users.
///
/// El OTP se envía vía Supabase Phone Auth, que internamente usa Twilio.
/// Para WhatsApp, configura el proveedor en:
/// Supabase Dashboard → Authentication → Providers → Phone → Twilio WhatsApp.
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<void> sendOtp(String phone) async {
    try {
      log.d('Enviando OTP a $phone');
      await supabase.auth.signInWithOtp(phone: phone);
      log.i('OTP enviado correctamente a $phone');
    } on sb.AuthException catch (e) {
      // DEV BYPASS (solo ENVIRONMENT=development): Twilio no disponible —
      // se ignora el error para poder continuar al flujo OTP en desarrollo.
      // TODO: Eliminar el bypass cuando Twilio esté funcionando.
      if (AppConfig.isDevelopment) {
        log.w('DEV BYPASS sendOtp: Twilio falló (${e.message}), continuando');
        return;
      }
      log.e('Error al enviar OTP', error: e);
      throw AuthException(_mapAuthMessage(e.message), code: e.statusCode);
    } catch (e, st) {
      if (AppConfig.isDevelopment) {
        log.w('DEV BYPASS sendOtp: error inesperado, continuando',
            error: e, stackTrace: st);
        return;
      }
      log.e('Error inesperado al enviar OTP', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<bool> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    // DEV BYPASS (solo ENVIRONMENT=development): si la verificación falla
    // (Twilio no disponible), se crea una sesión anónima para poder navegar.
    // Requiere "Anonymous Sign In" activado en Supabase Dashboard →
    // Authentication → Providers. En staging/producción ese proveedor debe
    // estar DESACTIVADO y este bypass nunca se ejecuta.
    // TODO: Eliminar el bypass cuando Twilio esté funcionando.
    try {
      log.d('Verificando OTP para $phone');
      final response = await supabase.auth.verifyOTP(
        phone: phone,
        token: otpCode,
        type: sb.OtpType.sms,
      );

      if (response.session == null || response.user == null) {
        throw const AuthException('No se pudo verificar el código.');
      }

      log.i('OTP verificado — userId: ${response.user!.id}');
      return await _isNewUser(response.user!.id);
    } on sb.AuthException catch (e) {
      if (AppConfig.isDevelopment) {
        log.w('DEV BYPASS verifyOtp: OTP falló (${e.message}), sesión anónima');
        return await _signInAnonymouslyAndCheckProfile();
      }
      log.e('Error al verificar OTP', error: e);
      throw AuthException(_mapAuthMessage(e.message), code: e.statusCode);
    } on OnzeException {
      rethrow;
    } catch (e, st) {
      if (AppConfig.isDevelopment) {
        log.w('DEV BYPASS verifyOtp: error inesperado ($e), sesión anónima');
        return await _signInAnonymouslyAndCheckProfile();
      }
      log.e('Error inesperado al verificar OTP', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  /// Crea o reutiliza una sesión anónima y devuelve si el usuario es nuevo.
  /// Solo se usa en el bypass de desarrollo.
  Future<bool> _signInAnonymouslyAndCheckProfile() async {
    try {
      final response = await supabase.auth.signInAnonymously();
      if (response.session == null || response.user == null) {
        throw const AuthException('No se pudo crear sesión de desarrollo.');
      }
      log.i('DEV BYPASS: sesión anónima — userId: ${response.user!.id}');
      return await _isNewUser(response.user!.id);
    } on sb.AuthException catch (e) {
      log.e('Error en sesión anónima (¿activaste Anonymous Sign In?)', error: e);
      throw AuthException(_mapAuthMessage(e.message), code: e.statusCode);
    } catch (e, st) {
      log.e('Error inesperado en bypass anónimo', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  /// Consulta public.users para determinar si el usuario necesita crear perfil.
  Future<bool> _isNewUser(String userId) async {
    final profile = await supabase
        .from('users')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();

    final fullName = profile?['full_name'] as String? ?? '';
    final isNewUser = fullName.isEmpty;
    log.d('¿Usuario nuevo? $isNewUser');
    return isNewUser;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final rows = await supabase
        .from('users')
        .select('id')
        .eq('username', username.trim().toLowerCase())
        .limit(1);
    return (rows as List).isEmpty;
  }

  @override
  Future<void> createPlayerProfile({
    required String fullName,
    required String username,
    required PlayerPosition position,
    required DominantFoot dominantFoot,
    required ExperienceLevel experienceLevel,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No hay sesión activa.');
    }

    try {
      log.d('Creando perfil para userId: $userId');

      // 1. Actualizar full_name y username en public.users
      await supabase.from('users').update({
        'full_name': fullName.trim(),
        'username': username.trim().toLowerCase(),
      }).eq('id', userId);

      // 2. Insertar o actualizar player_profiles
      await supabase.from('player_profiles').upsert({
        'user_id': userId,
        'position': position.dbValue,
        'dominant_foot': dominantFoot.dbValue,
        'experience_level': experienceLevel.dbValue,
      });

      log.i('Perfil creado correctamente para $userId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al crear perfil', error: e);
      // Código 23505 = unique_violation (username duplicado)
      if (e.code == '23505') {
        throw const DatabaseException(
          'Ese nombre de usuario ya está en uso. Elige otro.',
          code: '23505',
        );
      }
      throw DatabaseException(
        'No se pudo guardar el perfil. Intenta nuevamente.',
        code: e.code,
      );
    } catch (e, st) {
      log.e('Error inesperado al crear perfil', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      log.i('Sesión cerrada');
    } catch (e, st) {
      log.e('Error al cerrar sesión', error: e, stackTrace: st);
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final sbUser = supabase.auth.currentUser;
    if (sbUser == null) return null;

    try {
      // Columnas explícitas: phone/email/fcm_token ya no son legibles desde
      // el cliente (grants por columna, migración 026). El teléfono propio
      // se obtiene de la sesión de auth.
      final data = await supabase
          .from('users')
          .select('id, full_name, username, avatar_url, created_at, '
              'is_suspended, suspension_until, suspension_level, '
              'yellow_cards_count, roles')
          .eq('id', sbUser.id)
          .maybeSingle();

      if (data == null) return null;
      data['phone'] = _normalizePhone(sbUser.phone);
      return AppUser.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener usuario actual', error: e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Supabase Auth guarda el teléfono sin el prefijo '+'.
  String _normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    return phone.startsWith('+') ? phone : '+$phone';
  }

  String _mapAuthMessage(String raw) {
    if (raw.contains('Invalid') || raw.contains('invalid')) {
      return 'Código incorrecto. Verifica e intenta nuevamente.';
    }
    if (raw.contains('expired')) {
      return 'El código expiró. Solicita uno nuevo.';
    }
    if (raw.contains('rate')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return 'Error de autenticación. Intenta nuevamente.';
  }
}
