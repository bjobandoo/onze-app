# Plan de Proyecto — App de Canchas Sintéticas Ibarra

## 1. Nombre provisional y resumen

Para efectos del documento usaré el nombre provisional **"CanchaYa"** (cámbialo cuando definan branding). Es una app móvil Flutter para iOS y Android que conecta jugadores con dueños de canchas sintéticas en Ibarra, permite la formación de equipos, el registro competitivo de partidos y un sistema de ranking con recompensas.

---

## 2. Alcance del MVP por fases

El MVP se divide en 3 fases. La Fase 1 es lo mínimo indispensable para lanzar; la Fase 2 agrega la capa competitiva; la Fase 3 agrega las recompensas y pulido.

### Fase 1 — Fundación (4–6 semanas)
El objetivo es tener una app funcional donde dueños registren canchas y equipos puedan reservar.

- Registro y login de usuarios (jugador y dueño), con verificación de teléfono por WhatsApp
- Perfil básico de jugador (posición, pie hábil, experiencia, teléfono verificado)
- Perfil básico de dueño y registro de cancha(s) con validación manual por admin
- Configuración de horarios y precios por cancha (diario L–D, por bloques)
- Creación de equipos (máx 2 por usuario), invitaciones/solicitudes para unirse, gestión de capitán
- Mapa de Ibarra con ubicación de canchas
- Sistema de reservas: desafío entre capitanes → aceptación → confirmación del dueño, con bloqueo temporal de 45 minutos
- Notificaciones push para invitaciones, solicitudes y confirmaciones
- Panel web admin mínimo (al inicio puede ser el dashboard de Supabase directamente)

### Fase 2 — Competencia (3–4 semanas)
El objetivo es que los partidos generen datos competitivos.

- Sistema de reporte de resultados por capitanes con bloqueo de UI del capitán hasta reportar
- Ventana de 24h para reporte, resolución de disputas por el dueño
- Estadísticas individuales (globales) y de equipo (globales + por periodo)
- Sistema ELO con bonus por volumen de partidos
- Ranking global permanente y ranking quincenal/mensual que se reinicia
- Sistema de sanciones: tarjetas amarillas, rojas, suspensiones de cuenta y de equipo
- Sistema de apelaciones resueltas desde el panel admin
- Medallas automáticas por rango de ELO (Bronce, Plata, Oro, Platino, Diamante)

### Fase 3 — Recompensas y pulido (3–4 semanas)
El objetivo es cerrar el loop emocional con premios reales y pulir la experiencia.

- Sistema de logros coleccionables (no afectan ELO)
- Panel de recompensas: descuentos, órdenes de consumo, etc
- Integración con negocios asociados (alta manual desde admin)
- Reseñas y calificaciones de canchas
- Panel web admin completo (apelaciones, validación de canchas, métricas globales)
- Panel de dueño con estadísticas simples (reservas, ocupación, ingresos estimados)
- Onboarding mejorado y tutoriales in-app
- Testing y corrección de bugs

**Tiempo total estimado para equipo de 3 desarrolladores: 10–14 semanas (2.5–3.5 meses).**

---

## 3. Modelo de datos inicial

Este es el esquema relacional en PostgreSQL (Supabase). Lo presento como tablas con sus campos principales. Los tipos son orientativos.

### users
Contiene a todos los usuarios, sean jugadores, dueños o admins. Un usuario puede tener varios roles.
- id (uuid, PK)
- phone (text, unique, verificado)
- email (text, nullable)
- full_name (text)
- avatar_url (text)
- created_at (timestamp)
- is_suspended (bool)
- suspension_until (timestamp, nullable)
- suspension_level (int: 0, 1, 2, 3 — para la progresión 2 semanas, 2 meses, permanente)
- yellow_cards_count (int, 0–3, reinicia al llegar a 3)
- roles (array: ['player', 'owner', 'admin'])

### player_profiles
- user_id (uuid, PK, FK → users)
- position (enum: portero, defensa, mediocampista, delantero)
- dominant_foot (enum: izquierdo, derecho, ambidiestro)
- experience_level (enum: principiante, intermedio, avanzado)
- bio (text)

### owner_profiles
- user_id (uuid, PK, FK → users)
- business_name (text)
- id_document (text)
- verified (bool)
- verified_at (timestamp)

### fields (canchas)
- id (uuid, PK)
- owner_id (uuid, FK → users)
- name (text)
- description (text)
- address (text)
- latitude (decimal)
- longitude (decimal)
- photos (array de urls)
- field_type (enum: 5v5, 6v6, 7v7, 8v8)
- is_active (bool)
- verified (bool)
- average_rating (decimal, calculado)
- created_at (timestamp)

### field_schedules
Define los bloques disponibles por día de la semana y precio.
- id (uuid, PK)
- field_id (uuid, FK → fields)
- day_of_week (int: 0–6)
- start_time (time)
- end_time (time)
- price (decimal)
- is_active (bool)

### field_blocked_slots
Para cuando el dueño bloquea manualmente un horario específico (reservas externas, mantenimiento).
- id (uuid, PK)
- field_id (uuid, FK)
- date (date)
- start_time (time)
- end_time (time)
- reason (text, nullable)

### teams
- id (uuid, PK)
- name (text)
- crest_url (text)
- description (text)
- captain_id (uuid, FK → users)
- created_by (uuid, FK → users)
- created_at (timestamp)
- elo_rating (int, default 1000)
- is_suspended (bool)
- suspension_until (timestamp, nullable)
- suspension_level (int)
- yellow_cards_count (int)
- wins, losses, draws, matches_played (int)

### team_members
- id (uuid, PK)
- team_id (uuid, FK)
- user_id (uuid, FK)
- joined_at (timestamp)
- role (enum: captain, member)

### team_join_requests
Para las solicitudes de unión (en ambos sentidos: invitación del capitán o solicitud del jugador).
- id (uuid, PK)
- team_id (uuid, FK)
- user_id (uuid, FK)
- type (enum: invitation, request)
- status (enum: pending, accepted, rejected)
- created_at (timestamp)

### match_requests
Desafíos entre equipos.
- id (uuid, PK)
- challenger_team_id (uuid, FK)
- challenged_team_id (uuid, FK)
- field_id (uuid, FK)
- requested_date (date)
- requested_start_time (time)
- requested_end_time (time)
- price (decimal)
- status (enum: pending_opponent, pending_owner, confirmed, rejected, expired, cancelled)
- challenger_responded_at (timestamp)
- opponent_responded_at (timestamp)
- owner_responded_at (timestamp)
- blocked_until (timestamp, se usa cuando pasa a pending_owner)
- created_at (timestamp)

### matches
Partidos confirmados y jugados.
- id (uuid, PK)
- match_request_id (uuid, FK)
- team_a_id (uuid, FK)
- team_b_id (uuid, FK)
- field_id (uuid, FK)
- match_date (date)
- start_time (time)
- end_time (time)
- status (enum: scheduled, awaiting_report, disputed, resolved, cancelled)
- team_a_report (enum: win, loss, draw, nullable)
- team_b_report (enum: win, loss, draw, nullable)
- owner_resolution (enum: team_a_win, team_b_win, draw, nullable)
- final_result (enum, calculado cuando se resuelve)
- team_a_elo_change (int)
- team_b_elo_change (int)
- reported_at (timestamp)
- resolved_at (timestamp)

### individual_stats
Estadísticas globales de cada jugador.
- user_id (uuid, PK, FK)
- wins, losses, draws, matches_played (int)

### yellow_cards
Registro de tarjetas para auditoría y apelaciones.
- id (uuid, PK)
- target_type (enum: user, team)
- target_id (uuid)
- reason (enum: false_report, late_cancellation, no_report, other)
- match_id (uuid, nullable, FK)
- issued_at (timestamp)
- appealed (bool)
- appeal_resolution (enum: pending, upheld, revoked, nullable)

### appeals
- id (uuid, PK)
- yellow_card_id (uuid, FK)
- submitted_by (uuid, FK → users)
- reason (text)
- evidence_urls (array)
- status (enum: pending, approved, rejected)
- admin_notes (text)
- resolved_by (uuid, FK, nullable)
- created_at, resolved_at (timestamps)

### achievements (logros coleccionables)
- id (uuid, PK)
- code (text, unique)
- name (text)
- description (text)
- icon_url (text)
- target_type (enum: user, team)

### user_achievements / team_achievements
- id, user_id/team_id, achievement_id, unlocked_at

### rewards (recompensas canjeables)
- id, name, description, partner_business, discount_type, points_cost, active, stock

### ranking_snapshots
Para guardar el histórico del ranking quincenal/mensual.
- id, period_type (biweekly, monthly), period_start, period_end, team_id, elo_at_period, wins_in_period, matches_in_period, rank_position

### notifications
- id, user_id, type, title, body, data (jsonb), read, created_at

### field_reviews
- id, field_id, user_id, rating (1–5), comment, created_at

---

## 4. Fórmula ELO propuesta

Cada equipo empieza con **1000 puntos**. Al jugar un partido, el cambio de puntos se calcula así:

**Paso 1 — Expectativa:** `E_A = 1 / (1 + 10^((ELO_B - ELO_A) / 400))`. Esto da la probabilidad esperada de que A gane según la diferencia de ELO.

**Paso 2 — Resultado real:** `S_A = 1` si A ganó, `0.5` si empate, `0` si perdió.

**Paso 3 — Cambio base:** `K = 32` (constante estándar, ajustable). `cambio_A = K * (S_A - E_A)`.

**Paso 4 — Bonus por actividad:** al final de cada periodo (quincena/mes), se suma `bonus = partidos_jugados_en_periodo * 2` al ELO temporal del periodo. Esto premia jugar mucho sin distorsionar el ELO global permanente, porque el bonus solo aplica al ranking del periodo.

**Ejemplo con tu caso:**
- Equipo A: 10 jugados, 10 ganados, rivales promedio ELO 1000. ELO ganado ≈ 10 × 16 = 160. Bonus periodo: 20. Total periodo: ~180.
- Equipo B: 50 jugados, 44 ganados, rivales promedio ELO 1000. ELO ganado ≈ (44 × 16) − (6 × 16) = 608. Bonus periodo: 100. Total periodo: ~708.

Equipo B queda muy por encima, que es lo que buscas. Si Equipo A jugara contra rivales mucho más fuertes (ELO 1400), cada victoria le daría ~28 puntos en vez de 16, premiando la dificultad.

**Rangos por medalla (ELO global):**
- Bronce: < 1000
- Plata: 1000–1199
- Oro: 1200–1399
- Platino: 1400–1599
- Diamante: 1600+

---

## 5. Stack técnico confirmado

- **Frontend móvil:** Flutter 3.x con Dart
- **Gestión de estado:** Riverpod (más moderno y mantenible que Provider o Bloc para este tamaño de app)
- **Backend + BD + Auth + Storage:** Supabase (PostgreSQL, Row Level Security, Realtime)
- **Notificaciones push:** Firebase Cloud Messaging
- **Mapas:** flutter_map con tiles de OpenStreetMap
- **Verificación de teléfono:** WhatsApp Business API o Twilio Verify con canal WhatsApp
- **Panel admin web:** Inicialmente Supabase Studio. Después React + Vite desplegado en Vercel
- **Control de versiones:** GitHub con repo privado
- **CI/CD:** GitHub Actions (build automático de APK para testing)
- **Diseño:** Figma
- **Gestión de tareas:** GitHub Projects o Linear (ambos gratis para equipos pequeños)

---

## 6. Roadmap semanal con distribución de tareas para 3 desarrolladores

Asumo los roles: **Dev1 (líder técnico, backend-heavy)**, **Dev2 (frontend-heavy)**, **Dev3 (full-stack, QA)**. Ajusten según fortalezas reales.

**Semana 0 — Preparación:** crear repo, configurar Supabase, crear proyectos Figma y Firebase (para FCM), definir convenciones de código, crear rama `main` y `develop`.

**Semanas 1–2:** esquema completo de BD en Supabase, RLS básico, autenticación con verificación de WhatsApp, pantallas de registro/login/onboarding, perfil de jugador.

**Semanas 3–4:** registro de canchas, configuración de horarios, mapa de Ibarra, listado y búsqueda de canchas, perfil de cancha con fotos.

**Semanas 5–6:** sistema de equipos completo, invitaciones/solicitudes, gestión de capitán, sistema de reservas con bloqueo de 45 min, notificaciones push.

**Semana 7:** testing de Fase 1, corrección de bugs, publicación de versión beta interna (APK por GitHub Actions).

**Semanas 8–9:** reporte de resultados, flujo de disputas, cálculo de ELO, actualización de estadísticas vía triggers de Postgres o Edge Functions de Supabase.

**Semana 10:** sistema de sanciones (tarjetas, suspensiones), ranking global y de periodo, medallas automáticas.

**Semana 11:** apelaciones, panel web admin básico en React.

**Semanas 12–13:** logros, recompensas, reseñas de canchas, panel del dueño, pulido visual, onboarding.

**Semana 14:** testing final, preparación de assets para tiendas, publicación en Play Store (Android primero), beta en TestFlight (iOS requiere cuenta de Apple Developer de 99 USD/año).

---

## 7. Herramientas e integraciones — paso a paso

### 7.1 Supabase
1. Crear cuenta en supabase.com con GitHub
2. Crear proyecto nuevo, elegir región más cercana (us-east-1 para Ecuador)
3. Guardar la `project URL` y el `anon key` en un archivo `.env` (nunca subirlo al repo)
4. En el SQL Editor, ejecutar los scripts de creación de tablas (yo te los genero cuando empecemos a codear)
5. Activar Row Level Security en todas las tablas y escribir políticas
6. Activar Storage y crear buckets: `avatars`, `team_crests`, `field_photos`
7. En Flutter, agregar el paquete `supabase_flutter` y inicializar en `main.dart`

### 7.2 Firebase Cloud Messaging
1. Crear proyecto en console.firebase.google.com
2. Agregar app Android e iOS, descargar `google-services.json` y `GoogleService-Info.plist`
3. Agregar paquete `firebase_messaging` a Flutter
4. Configurar permisos en Android y iOS
5. En Supabase, crear una Edge Function que envíe notificaciones usando la API HTTP v1 de FCM

### 7.3 Verificación WhatsApp
Opción A — Twilio Verify (más fácil): crear cuenta, habilitar canal WhatsApp, integrar con paquete HTTP desde Flutter o desde una Edge Function. Cuesta ~0.05 USD por verificación pero es robusto.
Opción B — WhatsApp Business API directo: más complejo, requiere aprobación de Meta, pero es más barato a escala.
**Recomendación:** empezar con Twilio Verify para el MVP.

### 7.4 Flutter Map + OpenStreetMap
1. Agregar paquetes `flutter_map` y `latlong2`
2. Usar el tile provider gratuito de OSM o Stadia Maps (tiene mejor diseño y sigue siendo gratis hasta cierto volumen)
3. Marcadores personalizados para canchas

### 7.5 GitHub + GitHub Actions
1. Crear organización privada en GitHub
2. Crear 3 repos: `canchaya-app` (Flutter), `canchaya-admin` (React), `canchaya-docs`
3. Proteger la rama `main` con revisiones obligatorias
4. Workflow de GitHub Actions que al hacer push a `develop` compile APK de debug y lo suba como artifact

### 7.6 Panel admin web (Fase 3)
1. Crear proyecto Vite + React + TypeScript
2. Usar `@supabase/supabase-js` con un service role key (¡solo en el servidor!)
3. Autenticación basada en rol `admin` en la tabla users
4. Desplegar en Vercel conectando el repo

---

## 8. Cómo trabajar conmigo a través de Claude Code

Esta es probablemente la parte más importante para ti. Claude Code es una herramienta CLI que puedes instalar y ejecutar en tu terminal; desde ahí puedo leer tu código, crear archivos, correr comandos, ejecutar tests y hacer commits. Así es como recomiendo trabajar:

### 8.1 Instalación inicial
Instala Node.js 18+, luego ejecuta `npm install -g @anthropic-ai/claude-code`. Desde la raíz del proyecto ejecutas `claude` y comienza la sesión. Te recomiendo tener siempre este plan (el documento que estás leyendo) como archivo en el repo para que pueda consultarlo en cada sesión.

### 8.2 Cómo estructurar las tareas para mí
La clave es **darme tareas autocontenidas, bien definidas y con criterios de aceptación claros**. Un buen prompt sigue este formato:

> **Contexto:** estamos en la Fase 1, Semana 3 del plan. Ya tenemos auth y perfiles listos.
> **Tarea:** implementar el flujo de registro de cancha por parte del dueño.
> **Criterios de aceptación:**
> - Pantalla de formulario con nombre, dirección, tipo de cancha, fotos (máx 5), descripción
> - Selector de ubicación en mapa con marcador arrastrable
> - Al enviar, guarda en Supabase con `verified = false`
> - Muestra mensaje "Tu cancha está en revisión"
> - Tests de widget para el formulario
> **Archivos relevantes:** `lib/features/fields/`, `supabase/migrations/003_fields.sql`
> **No toques:** nada fuera de esa carpeta sin avisarme

### 8.3 Flujo recomendado por sesión
1. **Planificación (5 min):** decides qué task vas a hacer esta sesión, me explicas contexto y criterios
2. **Exploración (5 min):** yo leo el código existente relevante y te hago preguntas si hay ambigüedad
3. **Implementación (el grueso):** yo escribo el código, tú revisas en vivo, corriges mi enfoque si algo no te gusta
4. **Pruebas:** ejecuto los tests, arreglo lo que falle
5. **Revisión humana:** tú lees el diff final antes de commitear
6. **Commit:** yo hago el commit con mensaje descriptivo, o tú lo haces después de tu revisión

### 8.4 Reglas que debes imponerme siempre
- **Nunca trabajes en `main` directamente**, siempre en una rama feature
- **Nunca hagas push sin aprobación explícita** tuya
- **Si una tarea está creciendo más de lo esperado, detente y avisa** en vez de seguir inventando
- **Siempre escribe tests** para la lógica crítica (ELO, sanciones, reservas)
- **Siempre documenta** funciones públicas con comentarios Dart doc
- **Respeta la convención de nombres** que definamos al inicio

### 8.5 Primeras 5 tareas concretas para empezar conmigo
Cuando arranquemos, estas son las primeras tareas que te recomiendo darme en orden:

1. *"Crea la estructura inicial del proyecto Flutter con arquitectura por features, configura Riverpod, crea carpetas `core/`, `features/`, `shared/`, y agrega paquetes base: supabase_flutter, riverpod, go_router, flutter_map"*
2. *"Crea las migraciones SQL de Supabase para todas las tablas del modelo de datos del plan, con índices y RLS básico"*
3. *"Implementa el flujo de auth completo: pantalla de login con teléfono, verificación WhatsApp con Twilio Verify (stub por ahora), creación de perfil"*
4. *"Implementa el perfil de jugador con edición de posición, pie hábil, experiencia y bio"*
5. *"Implementa el flujo de creación de equipo y la lógica de límite de 2 equipos por usuario como capitán, incluyendo tests"*

Cada tarea debe tomarme entre 30 minutos y 2 horas de tu tiempo supervisándome. No me des tareas de "construye toda la Fase 1" porque pierdo contexto y calidad.

### 8.6 Archivo `CLAUDE.md` en el repo
Te recomiendo crear un archivo llamado `CLAUDE.md` en la raíz del proyecto donde pongas instrucciones permanentes para mí: convenciones de código, comandos de build, comandos de test, links al plan. Claude Code lo lee automáticamente al iniciar cada sesión, así no tienes que repetirme el contexto cada vez.

---

## 9. Riesgos y mitigaciones

- **Riesgo:** dueños de cancha no adoptan la app. **Mitigación:** acercamiento presencial antes del lanzamiento, demo del MVP, gratis al inicio.
- **Riesgo:** usuarios abusan del sistema de reporte. **Mitigación:** sistema de tarjetas, apelaciones, y solo partidos con reserva confirmada cuentan.
- **Riesgo:** costos de SMS/WhatsApp se disparan. **Mitigación:** rate limit de 3 intentos de verificación por número por día, usar Twilio con pricing controlado.
- **Riesgo:** scope creep durante desarrollo. **Mitigación:** respetar estrictamente las fases, cualquier idea nueva va a un backlog para v2.
- **Riesgo:** baja adopción inicial (cold start). **Mitigación:** seeding manual con 5–10 canchas y 3–4 equipos amigos antes del lanzamiento público.

---

## 10. Siguientes pasos concretos

1. Revisar este plan con tu equipo y validar que estén de acuerdo con el stack y el roadmap
2. Definir nombre, branding y colores principales de la app
3. Crear las cuentas necesarias (GitHub, Supabase, Firebase, Vercel, Twilio)
4. Crear el repo y subir este documento como `docs/plan.md`
5. Crear el `CLAUDE.md` con convenciones iniciales
6. Agendar nuestra primera sesión de Claude Code para arrancar con la Tarea 1

Cuando estés listo para empezar a codear, abre Claude Code en el repo y dime: *"Vamos a empezar la Tarea 1 del plan"*. Yo ya tendré el contexto cargado y arrancamos.
