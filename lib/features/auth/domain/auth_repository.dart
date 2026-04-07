import '../../../shared/models/app_user.dart';
import '../../../shared/models/player_enums.dart';

/// Contrato del repositorio de autenticación.
///
/// La implementación concreta vive en [AuthRepositoryImpl] y depende
/// de Supabase Auth + la tabla public.users.
abstract class AuthRepository {
  /// Envía un OTP al [phone] vía WhatsApp (Twilio configurado en Supabase).
  ///
  /// [phone] debe estar en formato E.164, ej: `+593987654321`.
  Future<void> sendOtp(String phone);

  /// Verifica el [otpCode] para el [phone] dado.
  ///
  /// Retorna `true` si el usuario es nuevo y aún no tiene perfil.
  /// Lanza [AuthException] si el código es incorrecto o expiró.
  Future<bool> verifyOtp({required String phone, required String otpCode});

  /// Crea o actualiza el perfil del jugador recién registrado.
  Future<void> createPlayerProfile({
    required String fullName,
    required PlayerPosition position,
    required DominantFoot dominantFoot,
    required ExperienceLevel experienceLevel,
  });

  /// Cierra la sesión activa.
  Future<void> signOut();

  /// Retorna el usuario actual desde public.users, o null si no hay sesión.
  Future<AppUser?> getCurrentUser();
}
