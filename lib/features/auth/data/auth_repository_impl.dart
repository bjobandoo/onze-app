import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
      log.e('Error al enviar OTP', error: e);
      throw AuthException(_mapAuthMessage(e.message), code: e.statusCode);
    } catch (e, st) {
      log.e('Error inesperado al enviar OTP', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<bool> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
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

      // Determinar si el usuario es nuevo consultando public.users
      final profile = await supabase
          .from('users')
          .select('full_name')
          .eq('id', response.user!.id)
          .maybeSingle();

      final fullName = profile?['full_name'] as String? ?? '';
      final isNewUser = fullName.isEmpty;
      log.d('¿Usuario nuevo? $isNewUser');
      return isNewUser;
    } on sb.AuthException catch (e) {
      log.e('Error al verificar OTP', error: e);
      throw AuthException(_mapAuthMessage(e.message), code: e.statusCode);
    } on AuthException {
      rethrow;
    } catch (e, st) {
      log.e('Error inesperado al verificar OTP', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<void> createPlayerProfile({
    required String fullName,
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

      // 1. Actualizar full_name en public.users
      await supabase
          .from('users')
          .update({'full_name': fullName.trim()})
          .eq('id', userId);

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
      final data = await supabase
          .from('users')
          .select()
          .eq('id', sbUser.id)
          .maybeSingle();

      if (data == null) return null;
      return AppUser.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener usuario actual', error: e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
