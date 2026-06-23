# CLAUDE.md — Onze

Este archivo contiene el contexto permanente del proyecto **Onze** para Claude Code. Se lee automáticamente al iniciar cada sesión. Mantener actualizado cuando cambien convenciones, stack o reglas.

---

## 1. Resumen del proyecto

**Onze** es una aplicación móvil multiplataforma (iOS/Android) construida en Flutter que conecta jugadores de fútbol amateur con dueños de canchas sintéticas en la ciudad de Ibarra, Ecuador. La app permite formar equipos, reservar canchas, registrar partidos oficiales con un sistema competitivo de ranking ELO, y ganar recompensas por actividad y desempeño.

El plan completo del proyecto vive en `docs/plan.md`. Ese documento es la fuente única de verdad del alcance, modelo de datos, fases y roadmap. Consultarlo siempre antes de implementar features nuevas.

---

## 2. Identidad visual — "Stadium Night"

Estilo elegido a partir de los prototipos de Claude Design (handoff junio 2026): verde césped sobre carbón verdoso, superficies suaves, radios generosos, acciones en forma de píldora y dock flotante de navegación.

### Paleta de colores oficial

| Uso | Token (`OnzeColors`) | Hex |
|---|---|---|
| Fondo principal (negro puro) | `background` | `#000000` |
| Superficies: cards, sheets | `surface` | `#151B14` |
| Superficie elevada: inputs, cards destacadas | `surfaceHigh` | `#1B221A` |
| Marca / fondos teñidos (banners, fills) | `primary` | `#1A3615` |
| Acento verde césped: CTAs, estados activos | `accent` / `highlight` | `#3BDC1E` |
| Texto/íconos sobre verde | `onAccent` | `#0A0F09` |
| Texto principal | `textPrimary` | `#EDF3EC` |
| Texto secundario | `textSecondary` | `#EDF3EC` al 55% |
| Texto apagado | `textDim` | `#EDF3EC` al 32% |
| Borde sutil (cards, inputs) | `border` | blanco al 7% |
| Tinte verde 14% (glows, fondos activos) | `greenGlow` | `#3BDC1E` al 14% |

### Reglas de uso del color

- Onze es una app con tema oscuro primero. El fondo base siempre es negro puro `#000000` con superficies en verde carbón `#151B14`/`#1B221A`.
- El verde césped `#3BDC1E` se usa con moderación: estados activos, badges, CTAs, etiquetas de sección. Nunca llenar pantallas con él.
- Sobre cualquier relleno verde, el texto y los íconos van en `onAccent` (`#0A0F09`), nunca en blanco.
- Para estados de error usar un rojo estándar (`#FF3B30`), para advertencias amarillo (`#FFCC00`). Las tarjetas amarillas del sistema de sanciones usan `#FFCC00` y las rojas `#FF3B30`.
- Nunca usar colores fuera de esta paleta sin consultar primero.

### Tipografía

- **Display:** Barlow Condensed (Google Fonts, vía `google_fonts`) — títulos, números grandes, etiquetas, botones.
- **Cuerpo:** Barlow — texto corriente, metadatos.
- **Jerarquía** (tokens en `TextTheme`):
  - Display (`displayLarge`): Barlow Condensed 30sp, weight 700
  - Heading L (`headlineLarge`): Barlow Condensed 24sp, weight 700
  - Heading M (`headlineMedium`): Barlow Condensed 19sp, weight 600
  - Body (`bodyLarge`/`bodyMedium`): Barlow 16/14sp, weight 400
  - Caption (`bodySmall`): Barlow 13sp, weight 400
  - Button (`labelLarge`): Barlow Condensed 16sp, weight 700, ls 0.8 — labels en MAYÚSCULAS (lo aplica `OnzeButton`)
  - Etiqueta de sección (`labelSmall`): Barlow Condensed 13sp, weight 600, ls 2.2, color verde acento
- Números (ELO, marcadores, posiciones) siempre en Barlow Condensed bold.

### Espaciado y bordes

- Sistema de 4pt: todos los paddings y márgenes son múltiplos de 4 (4, 8, 12, 16, 24, 32, 48).
- Border radius estándar (constantes en `OnzeTheme`): 22dp cards (`radiusCard`), 18dp filas de lista (`radiusRow`), 16dp inputs (`radiusInput`), 24dp diálogos (`radiusDialog`), 28dp top de bottom sheets (`radiusSheet`). Botones, chips y dock son píldoras completas (`StadiumBorder` / `radiusPill`).
- Cards: sin sombra fuerte, borde sutil blanco al 7% (`OnzeColors.border`) de 1px.
- Navegación principal: dock flotante (`OnzeDock`, `shared/widgets/onze_dock.dart`) con 5 pestañas (Inicio, Canchas, Equipo, Ranking, Perfil) montado por `OnzeShell` sobre un `StatefulShellRoute`. Las pantallas de pestaña necesitan padding inferior ≥ 120 para que el contenido no quede bajo el dock; las pantallas de detalle viven fuera del shell y lo cubren.
- Animaciones: tokens en `OnzeMotion` (`core/theme/onze_motion.dart`) — 140ms micro-interacciones, 240ms componentes, 340ms entradas/páginas; curvas `easeOutCubic` (entrada), `easeInCubic` (salida), `easeInOutCubic` (cambios de tamaño). Las transiciones de página son globales vía `PageTransitionsTheme`; el feedback de press se da con `OnzePressable`.

---

## 3. Stack técnico

- **Framework:** Flutter 3.x (canal stable), Dart 3.x
- **Gestión de estado:** Riverpod 2.x (`flutter_riverpod`)
- **Navegación:** go_router
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Edge Functions, Realtime)
- **Cliente Supabase:** `supabase_flutter`
- **Notificaciones push:** Firebase Cloud Messaging (`firebase_messaging`)
- **Mapas:** `flutter_map` con tiles de OpenStreetMap
- **Formularios:** `flutter_hooks` + `reactive_forms` o validación manual con Riverpod
- **HTTP extra:** `dio` (solo si es necesario fuera de Supabase)
- **Internacionalización:** `flutter_localizations` + `intl`, idioma principal español (es_EC), inglés opcional en v2
- **Testing:** `flutter_test`, `mocktail` para mocks, `integration_test` para flujos críticos
- **Linting:** `flutter_lints` + reglas custom en `analysis_options.yaml`

---

## 4. Estructura del proyecto

Arquitectura **feature-first** con capas internas. La regla: cada feature es autocontenida y expone solo lo necesario.

```
lib/
├── main.dart
├── app.dart                        # MaterialApp.router, theme, providers globales
├── core/
│   ├── config/                     # env vars, constantes, flags
│   ├── theme/                      # ColorScheme, TextTheme, tema oscuro Onze
│   ├── routing/                    # go_router config, rutas nombradas
│   ├── errors/                     # excepciones custom, manejo de errores
│   ├── utils/                      # helpers genéricos (formatters, validators)
│   └── extensions/                 # extensiones de Dart/Flutter
├── shared/
│   ├── widgets/                    # widgets reutilizables (OnzeButton, OnzeCard, OnzeAvatar)
│   ├── models/                     # modelos compartidos entre features
│   └── services/                   # servicios globales (supabase client, fcm, analytics)
├── features/
│   ├── auth/
│   │   ├── data/                   # repositorios, data sources
│   │   ├── domain/                 # entidades, casos de uso
│   │   ├── presentation/
│   │   │   ├── providers/          # riverpod providers
│   │   │   ├── screens/            # pantallas completas
│   │   │   └── widgets/            # widgets específicos del feature
│   ├── profile/
│   ├── fields/                     # canchas
│   ├── teams/                      # equipos
│   ├── matches/                    # partidos y reservas
│   ├── stats/                      # estadísticas y ranking
│   ├── sanctions/                  # tarjetas y apelaciones
│   ├── rewards/                    # logros y recompensas
│   └── notifications/
└── l10n/                           # archivos de traducción
test/
├── unit/
├── widget/
└── integration/
supabase/
├── migrations/                     # archivos SQL numerados (001_users.sql, 002_teams.sql...)
├── functions/                      # edge functions (deno)
└── seed.sql                        # datos de prueba
docs/
├── plan.md                         # plan completo del proyecto
├── architecture.md                 # decisiones técnicas importantes
└── api.md                          # documentación de edge functions
```

---

## 5. Convenciones de código

### Nombres

- **Archivos:** `snake_case.dart`
- **Clases, enums, typedefs:** `PascalCase`
- **Variables, funciones, parámetros:** `camelCase`
- **Constantes:** `lowerCamelCase` (no `SCREAMING_SNAKE_CASE`, es convención Dart)
- **Providers Riverpod:** sufijo `Provider`, ejemplo `authStateProvider`, `teamsListProvider`
- **Widgets:** nombre descriptivo sin prefijo `Widget`, ejemplo `TeamCard` no `TeamCardWidget`
- **Widgets del design system:** prefijo `Onze`, ejemplo `OnzeButton`, `OnzeTextField`
- **Pantallas:** sufijo `Screen`, ejemplo `LoginScreen`, `TeamDetailScreen`
- **Casos de uso:** verbo + sustantivo, ejemplo `CreateTeamUseCase`, `ReportMatchResultUseCase`

### Estructura de archivos Dart

```dart
// 1. Imports dart
import 'dart:async';

// 2. Imports flutter
import 'package:flutter/material.dart';

// 3. Imports de paquetes externos
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 4. Imports del proyecto (relativos)
import '../../core/theme/onze_theme.dart';
import 'widgets/team_card.dart';

// 5. Código
class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});
  // ...
}
```

### Reglas obligatorias

- **Siempre `const` donde sea posible** (constructores, listas, mapas)
- **Siempre tipos explícitos** en APIs públicas (parámetros, returns). Inferencia permitida solo en cuerpos de funciones locales
- **Prohibido `dynamic`** excepto cuando sea absolutamente necesario (respuestas no tipadas de APIs externas) y justificado con comentario
- **Prohibido `print`**, usar el `logger` del proyecto (definido en `core/utils/logger.dart`)
- **Prohibido hardcodear strings visibles al usuario**, siempre usar el sistema de l10n
- **Prohibido hardcodear colores**, usar `Theme.of(context).colorScheme` o `OnzeColors`
- **Nombres en inglés** para código, **español (es_EC)** para textos visibles al usuario
- **Documentar con `///`** todas las clases públicas, métodos públicos de servicios, providers complejos y casos de uso
- **Límite de 300 líneas por archivo**. Si se excede, refactorizar en archivos más pequeños
- **Límite de 50 líneas por función**. Si se excede, extraer en funciones privadas

### Manejo de errores

- Nunca hacer `try/catch` vacíos o con solo `print`
- Los repositorios devuelven `Result<T>` o lanzan excepciones tipadas custom
- Las excepciones custom heredan de `OnzeException` definida en `core/errors/`
- En UI, los errores se muestran con un `SnackBar` rojo o pantalla de error dedicada para errores graves
- Siempre loggear errores con contexto suficiente para debugging

### Inmutabilidad

- Preferir `final` sobre `var` siempre
- Usar `freezed` para modelos de datos complejos (ya incluido en `pubspec.yaml`)
- Nunca mutar listas o mapas recibidos como parámetros

---

## 6. Reglas de Supabase

### Migraciones SQL

- Cada cambio de esquema va en un archivo numerado: `001_create_users.sql`, `002_create_teams.sql`, etc
- Nunca editar migraciones ya aplicadas. Crear una nueva migración
- Siempre incluir el rollback correspondiente en un comentario al inicio del archivo
- Usar `snake_case` para tablas y columnas (convención Postgres)
- Siempre agregar índices en foreign keys y columnas usadas en `WHERE`

### Row Level Security (RLS)

- **RLS activado obligatoriamente en todas las tablas**, sin excepciones
- Las políticas se escriben en el mismo archivo de migración que crea la tabla
- Un usuario solo puede leer/escribir sus propios datos, excepto en tablas públicas (ranking, canchas visibles)
- El rol `service_role` se usa SOLO en edge functions y panel admin, nunca desde el cliente

### Edge Functions

- Escritas en TypeScript (Deno runtime)
- Ubicadas en `supabase/functions/<nombre>/index.ts`
- Una función por responsabilidad, sin mega-funciones
- Usadas para: cálculo de ELO post-partido, envío de notificaciones FCM, aplicación de sanciones, resolución de disputas, generación de snapshots de ranking

### Realtime

- Usar realtime solo donde agregue valor claro: notificaciones, estado de reservas en curso
- Nunca suscribirse a tablas grandes sin filtros

---

## 7. Git y flujo de trabajo

### Ramas

- `main`: código de producción, protegida, solo merge vía PR aprobado
- `develop`: rama de integración, todos los features mergean aquí primero
- `feature/<nombre>`: features nuevos, ejemplo `feature/team-creation`
- `fix/<nombre>`: bug fixes
- `refactor/<nombre>`: refactorizaciones sin cambio funcional
- `chore/<nombre>`: tareas de mantenimiento, configs

### Commits (Conventional Commits)

Formato: `<tipo>(<scope>): <descripción en imperativo>`

Tipos permitidos: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`

Ejemplos:
- `feat(teams): add team creation screen with crest upload`
- `fix(matches): prevent double booking when two captains confirm simultaneously`
- `refactor(auth): extract phone verification into use case`

Commits en inglés, siempre en imperativo ("add" no "added" ni "adds").

### Pull Requests

- Título descriptivo siguiendo el formato de commits
- Descripción con: qué cambia, por qué, cómo probarlo, screenshots si es UI
- Mínimo 1 revisión aprobada antes de merge
- Todos los tests deben pasar
- No hacer merge directo a `main` nunca

---

## 8. Testing

### Qué testear obligatoriamente

- **Lógica crítica de negocio**: cálculo de ELO, aplicación de sanciones, validación de reservas, conflictos de horarios, flujo de reporte de resultados
- **Casos de uso** completos
- **Repositorios** con mocks del cliente Supabase
- **Widgets críticos**: formularios, botones del design system

### Qué no es necesario testear

- Widgets puramente presentacionales sin lógica
- Código de configuración

### Convenciones de tests

- Un archivo de test por cada archivo de código, con sufijo `_test.dart`
- Estructura AAA: Arrange, Act, Assert
- Usar `group` para agrupar tests relacionados
- Nombres descriptivos: `test('calculates ELO correctly when underdog wins', ...)`
- Mocks con `mocktail`, nunca `mockito`

---

## 9. Reglas para Claude Code (cómo debo trabajar)

Estas son reglas de operación que debo seguir en cada sesión.

### Antes de empezar cualquier tarea

1. Leer este archivo completo si es el inicio de sesión
2. Consultar `docs/plan.md` para entender en qué fase estamos
3. Revisar los archivos relevantes antes de modificar algo
4. Si hay ambigüedad, preguntar antes de asumir

### Durante la implementación

- **Trabajar siempre en una rama feature**, nunca en `main` ni `develop` directamente
- **Nunca hacer `git push` sin aprobación explícita** del usuario
- **Nunca borrar archivos** sin confirmación explícita
- **Nunca hacer cambios masivos** (> 10 archivos) sin plan previo acordado
- **Siempre correr el linter** (`flutter analyze`) antes de dar por terminada una tarea
- **Siempre correr los tests relevantes** antes de dar por terminada una tarea
- **Si una tarea crece más de lo estimado**, detenerse y reportar en lugar de seguir inventando alcance
- **Si algo del plan no tiene sentido** durante la implementación, preguntar antes de cambiar el plan

### Sobre dependencias

- **Nunca agregar paquetes nuevos** sin discutirlo primero
- Justificar cada paquete nuevo: qué problema resuelve, por qué no se puede hacer con lo existente, tamaño del paquete, último update
- Preferir paquetes mantenidos por Flutter team o con > 500 likes en pub.dev

### Sobre el código existente

- **Respetar el estilo del código existente** aunque no sea perfecto
- Refactorizaciones grandes solo si son parte de la tarea asignada
- Si encuentro código que me parece malo pero no es parte de la tarea, reportarlo al final en lugar de arreglarlo sin permiso

### Formato de reporte al terminar una tarea

Al terminar, siempre reportar con:
- **Qué hice:** lista concreta de cambios
- **Archivos modificados:** lista con paths
- **Tests:** qué se agregó, qué pasa, qué falla
- **Pendientes:** qué quedó sin hacer y por qué
- **Notas:** cualquier observación relevante (code smells encontrados, dudas, decisiones tomadas)

---

## 10. Comandos frecuentes

Agregar aquí los comandos que se usan seguido durante el desarrollo.

```bash
# Instalar dependencias
flutter pub get

# Generar código (freezed, riverpod, json_serializable)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Ejecutar en dispositivo
flutter run
flutter run --release

# Linter
flutter analyze

# Tests
flutter test
flutter test test/unit/features/matches/elo_calculator_test.dart

# Build
flutter build apk --release
flutter build ios --release

# Supabase CLI
supabase start                      # inicia entorno local
supabase db reset                   # resetea BD local y aplica migraciones
supabase db push                    # aplica migraciones a remoto
supabase functions deploy <nombre>  # despliega edge function
```

---

## 11. Variables de entorno

**Importante:** el `.env` se empaqueta dentro del APK como asset de `flutter_dotenv`. Por eso SOLO puede contener claves públicas de cliente. Las credenciales de servidor NUNCA van en `.env`.

`.env` (cliente, nunca commiteado, se empaqueta en la app):

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
ENVIRONMENT=development  # development | staging | production
```

Credenciales de servidor (Twilio, Firebase service account, service_role key): viven como secrets en Supabase (`supabase secrets set ...` para edge functions; Twilio se configura en Dashboard → Authentication → Providers → Phone). Para referencia local del equipo existe `.env.server` (gitignored y nunca empaquetado).

Existe un `.env.example` con las keys pero sin valores, ese sí se commitea.

---

## 12. Decisiones arquitectónicas importantes

Esta sección documenta decisiones que podrían parecer raras sin contexto. Agregar nuevas cuando se tomen.

- **Por qué Supabase y no Firebase:** el modelo de datos es muy relacional (jugadores↔equipos↔partidos↔reservas). Postgres es la herramienta correcta; Firestore haría las queries de ranking y estadísticas muy dolorosas.
- **Por qué Riverpod y no Bloc:** menos boilerplate, mejor inferencia de tipos, testing más simple, adecuado para un equipo pequeño.
- **Por qué go_router:** es el router oficial recomendado por Flutter team, soporta deep links nativos para notificaciones push.
- **Por qué tema oscuro primero:** identidad visual de Onze, mejor para uso nocturno (muchos partidos son en la noche), ahorra batería en pantallas OLED.
- **Por qué el panel admin es web separado:** no meter código privilegiado en el binario de la app pública, iteración más rápida, accesible desde cualquier computadora.

---

## 13. Glosario del dominio

- **Capitán:** usuario creador de un equipo, único que puede reservar, reportar resultados, editar info y expulsar jugadores
- **Desafío (match request):** solicitud de partido enviada de un capitán a otro
- **Reserva confirmada:** cuando el dueño acepta el desafío y el horario queda reservado
- **Partido oficial:** partido que cuenta para estadísticas y ELO (solo los reservados vía la app)
- **ELO:** puntaje numérico del equipo basado en resultados y dificultad del rival
- **Periodo de ranking:** ciclo quincenal o mensual que se reinicia para premios
- **Tarjeta amarilla:** sanción menor, se acumulan
- **Tarjeta roja:** suspensión temporal tras acumular 3 amarillas
- **Host:** usuario dueño de una o varias canchas
- **Slot:** bloque horario disponible en una cancha (definido por el dueño)

---

## 14. Contacto y propiedad

Proyecto propiedad de los socios fundadores de Onze. Código privado, no distribuir.

Para dudas sobre el plan, consultar `docs/plan.md`. Para dudas sobre convenciones, este archivo es la fuente de verdad.

---

*Última actualización: al crear el proyecto. Mantener este archivo al día cuando cambien convenciones o stack.*
