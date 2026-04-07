/// Clase base de todas las excepciones custom de Onze.
///
/// Los repositorios lanzan subclases de [OnzeException] en lugar de
/// excepciones genéricas, para que la UI pueda mostrar mensajes adecuados.
abstract class OnzeException implements Exception {
  const OnzeException(this.message, {this.code});

  final String message;

  /// Código opcional para identificar el tipo de error (ej. 'auth/user-not-found').
  final String? code;

  @override
  String toString() => 'OnzeException($code): $message';
}

/// Error de autenticación (login, registro, sesión expirada).
class AuthException extends OnzeException {
  const AuthException(super.message, {super.code});
}

/// Error al interactuar con la base de datos o Supabase.
class DatabaseException extends OnzeException {
  const DatabaseException(super.message, {super.code});
}

/// Error de red o de conectividad.
class NetworkException extends OnzeException {
  const NetworkException(super.message, {super.code});
}

/// Error de permisos: el usuario intenta hacer algo que no le corresponde.
class PermissionException extends OnzeException {
  const PermissionException(super.message, {super.code});
}

/// Error de validación de datos de entrada.
class ValidationException extends OnzeException {
  const ValidationException(super.message, {super.code});
}
