// Providers de Riverpod para el estado del onboarding y coachmarks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/logger.dart';
import '../../../../shared/services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Claves de metadata
// ---------------------------------------------------------------------------

/// Walkthrough inicial completado.
const kObDone = 'ob_done';

/// Tip de ELO descartado en la pantalla de ranking.
const kObElo = 'ob_elo';

/// Tip de sanciones descartado en la pantalla de sanciones.
const kObSanctions = 'ob_sanctions';

/// Tip de logros descartado en la pantalla de logros.
const kObAchievements = 'ob_achievements';

const _kAllKeys = [kObDone, kObElo, kObSanctions, kObAchievements];

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Maneja el estado del onboarding y los coachmarks contextuales.
///
/// El estado es el conjunto de claves ya descartadas por el usuario.
/// Se persiste en el metadata del usuario autenticado de Supabase.
class OnboardingNotifier extends StateNotifier<Set<String>> {
  OnboardingNotifier() : super(_fromMetadata());

  static Set<String> _fromMetadata() {
    final meta = supabase.auth.currentUser?.userMetadata ?? {};
    return _kAllKeys.where((k) => meta[k] == true).toSet();
  }

  /// Devuelve true si la clave [key] ya fue descartada (onboarding/tip visto).
  bool isDismissed(String key) => state.contains(key);

  /// Marca [key] como descartado localmente y persiste en los metadatos de auth.
  Future<void> dismiss(String key) async {
    if (state.contains(key)) return;
    state = {...state, key};
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {key: true}),
      );
    } catch (e, st) {
      // No bloqueamos la UX si la persistencia falla — el estado local es suficiente.
      log.w('No se pudo persistir onboarding flag "$key"',
          error: e, stackTrace: st);
    }
  }
}

/// Provider global del estado de onboarding.
///
/// No se usa autoDispose porque debe sobrevivir durante toda la sesión.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, Set<String>>(
  (_) => OnboardingNotifier(),
);
