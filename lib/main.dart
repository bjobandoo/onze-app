import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/utils/logger.dart';
import 'shared/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Inicializa Firebase y FCM (silencioso si google-services.json no existe)
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermission();

  log.i('Onze iniciada — entorno: ${AppConfig.environment}');

  // Crear el ProviderContainer antes del runApp para pasarlo al router
  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: OnzeApp(container: container),
    ),
  );
}
