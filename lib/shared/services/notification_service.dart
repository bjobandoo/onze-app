// Servicio de notificaciones push (Firebase Cloud Messaging).
//
// Requiere setup nativo antes de funcionar:
//   Android: colocar google-services.json en android/app/
//   iOS:     colocar GoogleService-Info.plist en ios/Runner/

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/logger.dart';
import 'supabase_service.dart';

// ---------------------------------------------------------------------------
// Canal Android
// ---------------------------------------------------------------------------

const _androidChannel = AndroidNotificationChannel(
  'onze_default',
  'Onze',
  description: 'Notificaciones de Onze',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

// ---------------------------------------------------------------------------
// Background handler (top-level, requerido por FCM)
// ---------------------------------------------------------------------------

/// Handler de mensajes en background. Debe ser top-level (no método de clase).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log.d('FCM background: ${message.notification?.title}');
}

// ---------------------------------------------------------------------------
// Servicio principal
// ---------------------------------------------------------------------------

/// Singleton que gestiona el ciclo de vida de FCM y notificaciones locales.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _ready = false;

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------

  /// Inicializa Firebase, FCM y flutter_local_notifications.
  /// Seguro de llamar aunque Firebase no esté configurado (falla silenciosamente).
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;

      await _initLocalNotifications();

      // Background handler (registrado a nivel global)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground: mostrar notificación local
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Usuario toca una notificación mientras la app estaba en background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // App abierta desde notificación con la app cerrada
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onNotificationTap(initial);

      // Renovaciones de token → actualizar BD
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        log.d('FCM token renovado — guardando en BD');
        _saveTokenIfAuthenticated(newToken);
      });

      // iOS: mostrar notificaciones aunque la app esté en foreground
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      log.i('Firebase / FCM inicializado correctamente');
    } catch (e) {
      log.w(
        'Firebase no disponible — notificaciones push desactivadas. '
        'Configura google-services.json (Android) y GoogleService-Info.plist (iOS).',
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    // Crear el canal Android (necesario desde Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIos = DarwinInitializationSettings(
      requestAlertPermission: false, // ya lo pedimos vía FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: initAndroid, iOS: initIos),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
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
    if (token == null) {
      log.w('FCM token null — Firebase no listo o sin permiso');
      return;
    }
    log.d('FCM token obtenido: ${token.substring(0, 20)}...');
    await _persistToken(userId, token);
  }

  // ---------------------------------------------------------------------------
  // Handlers internos
  // ---------------------------------------------------------------------------

  /// Muestra una notificación local cuando llega un mensaje en foreground.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    final screen = message.data['screen'] as String?;

    log.d('FCM foreground — título: $title');

    _localNotifications.show(
      // ID único basado en el hashCode del messageId para evitar duplicados
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: screen,
    );
  }

  /// Maneja el tap en una notificación FCM recibida en background/terminated.
  void _onNotificationTap(RemoteMessage message) {
    final screen = message.data['screen'] as String?;
    log.i('FCM tap (background) — pantalla destino: $screen');
    // TODO Fase 2: navegar con go_router usando el screen destino
  }

  /// Maneja el tap en una notificación local (foreground).
  void _onLocalNotificationTap(NotificationResponse response) {
    final screen = response.payload;
    log.i('FCM tap (foreground) — pantalla destino: $screen');
    // TODO Fase 2: navegar con go_router usando el screen destino
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  Future<void> _persistToken(String userId, String token) async {
    try {
      await supabase
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      log.i('FCM token guardado en BD para usuario $userId');
    } catch (e) {
      log.w('Error al guardar FCM token en DB: $e');
    }
  }

  void _saveTokenIfAuthenticated(String token) {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) _persistToken(userId, token);
  }
}
