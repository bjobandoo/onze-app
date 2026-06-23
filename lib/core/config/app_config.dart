import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración global de la app cargada desde variables de entorno.
///
/// El `.env` empaquetado solo debe contener claves públicas de cliente
/// (SUPABASE_URL, SUPABASE_ANON_KEY, ENVIRONMENT). Las credenciales de
/// servidor (Twilio, Firebase service account) viven en los secrets de
/// Supabase, nunca en el binario de la app.
abstract final class AppConfig {
  static String _env(String key) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';

  static String get supabaseUrl => _env('SUPABASE_URL');
  static String get supabaseAnonKey => _env('SUPABASE_ANON_KEY');
  static String get environment {
    final value = _env('ENVIRONMENT');
    return value.isEmpty ? 'development' : value;
  }

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}
