/// Estados del flujo de autenticación por teléfono.
///
/// Máquina de estados:
///   idle → sendingOtp → otpSent → verifying → success | error
sealed class PhoneAuthState {
  const PhoneAuthState();
}

/// Estado inicial, sin ninguna operación en curso.
class PhoneAuthIdle extends PhoneAuthState {
  const PhoneAuthIdle();
}

/// Enviando el OTP al número de WhatsApp.
class PhoneAuthSendingOtp extends PhoneAuthState {
  const PhoneAuthSendingOtp();
}

/// OTP enviado correctamente. El usuario debe ingresar el código.
class PhoneAuthOtpSent extends PhoneAuthState {
  const PhoneAuthOtpSent(this.phone);
  final String phone;
}

/// Verificando el código OTP ingresado.
class PhoneAuthVerifying extends PhoneAuthState {
  const PhoneAuthVerifying();
}

/// Autenticación exitosa.
/// [isNewUser] indica si el usuario aún no tiene perfil creado.
class PhoneAuthSuccess extends PhoneAuthState {
  const PhoneAuthSuccess({required this.isNewUser});
  final bool isNewUser;
}

/// Error en cualquier paso del flujo.
class PhoneAuthError extends PhoneAuthState {
  const PhoneAuthError(this.message);
  final String message;
}
