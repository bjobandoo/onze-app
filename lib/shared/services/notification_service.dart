// Servicio de notificaciones push (Firebase Cloud Messaging).
//
// Requiere setup nativo antes de funcionar:
//   Android: colocar google-services.json en android/app/
//   iOS:     colocar GoogleService-Info.plist en ios/Runner/
//
// Mientras el proyecto no esté conectado a Firebase, todas las llamadas
// son silenciosas (try/catch) para no bloquear el arranque de la app.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/utils/logger.dart';
import 'supabase_service.dart';

/// Handler de mensajes en background (requiere anotación vm:entry-point).
/// Registrarlo en main.dart antes de runApp.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya inicializado por el sistema en background
  log.d('FCM background: ${message.notification?.title}');
}

/// Singleton que gestiona el ciclo de vida de FCM en la app.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _ready = false;

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------

  /// Inicializa Firebase y configura los handlers de mensajes.
  /// Seguro de llamar aunque Firebase no esté configurado (falla silenciosamente).
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;

      // Handler de mensajes en background (registrado a nivel global)
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      // Handler de mensajes en primer plano
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handler cuando el usuario toca una notificación background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // Verificar si la app fue abierta desde una notificación terminada
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onNotificationTap(initial);

      log.i('Firebase / FCM inicializado correctamente');
    } catch (e) {
      log.w(
        'Firebase no disponible — notificaciones push desactivadas. '
        'Configura google-services.json (Android) y GoogleService-Info.plist (iOS).',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Permisos y token
  // ---------------------------------------------------------------------------

  /// Solicita permiso de notificaciones (iOS / Android 13+).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      log.i('Permiso de notificaciones: ${settings.authorizationStatus.name}');
      return granted;
    } catch (e) {
      log.w('Error al solicitar permiso de notificaciones: $e');
      return false;
    }
  }

  /// Obtiene el token FCM del dispositivo actual.
  Future<String?> getToken() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      log.w('Error al obtener token FCM: $e');
      return null;
    }
  }

  /// Guarda el token FCM en la columna `fcm_token` del usuario en Supabase.
  /// Llamar después de que el usuario se autentique.
  Future<void> saveTokenToDb(String userId) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await supabase
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      log.d('FCM token guardado para usuario $userId');
    } catch (e) {
      log.w('Error al guardar FCM token en DB: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Handlers internos
  // ---------------------------------------------------------------------------

  void _onForegroundMessage(RemoteMessage message) {
    // En primer plano FCM no muestra la notificación automáticamente.
    // En Fase 2 se mostrará un banner in-app (flutter_local_notifications).
    log.d(
      'FCM primer plano — título: ${message.notification?.title} '
      'data: ${message.data}',
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    // La navegación deep-link se implementará en Fase 2 con el router.
    // Por ahora solo se loggea el dato de pantalla destino.
    final screen = message.data['screen'];
    log.i('FCM tap — navegar a: $screen');
  }
}
