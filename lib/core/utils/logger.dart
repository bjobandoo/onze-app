import 'package:logger/logger.dart';

/// Logger global del proyecto.
///
/// Usar este logger en lugar de [print] en toda la app.
///
/// Ejemplo:
/// ```dart
/// log.d('Cargando equipos...');
/// log.e('Error al guardar', error: e, stackTrace: st);
/// ```
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
