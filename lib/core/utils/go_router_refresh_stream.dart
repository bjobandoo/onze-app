import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adaptador que convierte un [Stream] en un [ChangeNotifier] para go_router.
///
/// go_router acepta un [Listenable] como `refreshListenable`. Este helper
/// escucha cualquier stream (ej. el stream de auth de Supabase) y notifica
/// a go_router cada vez que llega un nuevo evento para que reevalúe los redirects.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
