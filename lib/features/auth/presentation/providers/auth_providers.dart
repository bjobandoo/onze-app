import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../shared/models/app_user.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import '../../domain/models/phone_auth_state.dart';

// ---------------------------------------------------------------------------
// Repositorio
// ---------------------------------------------------------------------------

/// Proveedor del repositorio de autenticación.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// ---------------------------------------------------------------------------
// Sesión de Supabase (stream reactivo)
// ---------------------------------------------------------------------------

/// Stream de cambios de estado de autenticación de Supabase.
///
/// Usado por el router para redirigir al login o a home según la sesión.
final authStateChangesProvider = StreamProvider<sb.AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// ---------------------------------------------------------------------------
// Usuario actual
// ---------------------------------------------------------------------------

/// Usuario actualmente autenticado desde public.users.
///
/// Se recalcula cuando cambia la sesión de Supabase.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  // Refresca cada vez que la sesión cambia
  ref.watch(authStateChangesProvider);
  return ref.read(authRepositoryProvider).getCurrentUser();
});

// ---------------------------------------------------------------------------
// Notifier del flujo de login por teléfono
// ---------------------------------------------------------------------------

/// Notifier que maneja el flujo de autenticación por teléfono/OTP.
class PhoneAuthNotifier extends StateNotifier<PhoneAuthState> {
  PhoneAuthNotifier(this._repo) : super(const PhoneAuthIdle());

  final AuthRepository _repo;

  /// Envía el OTP al número de teléfono en formato E.164.
  Future<void> sendOtp(String phone) async {
    state = const PhoneAuthSendingOtp();
    try {
      await _repo.sendOtp(phone);
      state = PhoneAuthOtpSent(phone);
    } catch (e) {
      state = PhoneAuthError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Verifica el código OTP ingresado por el usuario.
  Future<void> verifyOtp({required String phone, required String code}) async {
    state = const PhoneAuthVerifying();
    try {
      final isNewUser = await _repo.verifyOtp(phone: phone, otpCode: code);
      state = PhoneAuthSuccess(isNewUser: isNewUser);
    } catch (e) {
      state = PhoneAuthError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Reinicia al estado inicial (para "atrás" o "reenviar").
  void reset() => state = const PhoneAuthIdle();

  /// Vuelve al estado de OTP enviado (para reenviar sin perder el teléfono).
  void backToOtpSent(String phone) => state = PhoneAuthOtpSent(phone);
}

/// Provider del notifier del flujo de login por teléfono.
final phoneAuthProvider =
    StateNotifierProvider<PhoneAuthNotifier, PhoneAuthState>((ref) {
  return PhoneAuthNotifier(ref.watch(authRepositoryProvider));
});
