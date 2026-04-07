import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso global al cliente de Supabase.
///
/// Usar [supabase] en repositorios y data sources.
/// Nunca usar [Supabase.instance.client] directamente en la UI.
SupabaseClient get supabase => Supabase.instance.client;
