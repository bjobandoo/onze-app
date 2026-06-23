# Onze Design System — "Stadium Night"

Reference for the visual language used in this project. Use this whenever you need to build, review, or fix UI in the Onze app.

Direction chosen from the Claude Design handoff (June 2026): grass green over greenish charcoal, soft surfaces, generous radii, pill-shaped actions, floating navigation dock. Display type is Barlow Condensed, body is Barlow.

---

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| `OnzeColors.background` | `#000000` | Scaffold background — pure black |
| `OnzeColors.surface` | `#151B14` | Cards, sheets, secondary surfaces |
| `OnzeColors.surfaceHigh` | `#1B221A` | Elevated cards, inputs |
| `OnzeColors.border` | white @ 7% | 1px borders on cards and inputs |
| `OnzeColors.primary` | `#1A3615` | Tinted fills: banners, map markers, highlighted rows |
| `OnzeColors.accent` / `highlight` | `#3BDC1E` | Grass green: CTAs, active states, links, section labels |
| `OnzeColors.onAccent` | `#0A0F09` | Text/icons on top of green fills — never white on green |
| `OnzeColors.textPrimary` | `#EDF3EC` | Body text, headings |
| `OnzeColors.textSecondary` | `#EDF3EC` @ 55% | Subtitles, metadata, placeholders |
| `OnzeColors.textDim` | `#EDF3EC` @ 32% | Tertiary text, chevrons |
| `OnzeColors.greenGlow` | `#3BDC1E` @ 14% | Icon tiles, active tints, glows |
| `OnzeColors.error` | `#FF3B30` | Error states, red cards (sanciones) |
| `OnzeColors.warning` | `#FFCC00` | Warning states, yellow cards (sanciones) |

**Rules:**
- Dark-first. Background is always pure black `#000000`; surfaces keep the greenish charcoal tint (`#151B14`/`#1B221A`) — never gray surfaces.
- `#3BDC1E` sparingly — badges, active pills, section labels, primary CTAs. Never fill a whole screen.
- On any solid green fill, text and icons use `OnzeColors.onAccent` — white on green is forbidden.
- Never hardcode colors — always reference `OnzeColors.*` or `Theme.of(context).colorScheme.*`.

---

## Typography

Fonts: **Barlow Condensed** (display) + **Barlow** (body) via `google_fonts`.

| Role | Font | Size | Weight | Letter spacing | Theme token |
|---|---|---|---|---|---|
| Display / greeting | Barlow Condensed | 30sp | 700 | 0.5 | `displayLarge` |
| Heading large | Barlow Condensed | 24sp | 700 | 0.5 | `headlineLarge` |
| Heading medium | Barlow Condensed | 19sp | 600 | 0.6 | `headlineMedium` |
| Body | Barlow | 16sp | 400 | — | `bodyLarge` |
| Body medium | Barlow | 14sp | 400 | — | `bodyMedium` |
| Caption / metadata | Barlow | 13sp | 400 | — | `bodySmall` |
| Button label (UPPERCASE) | Barlow Condensed | 16sp | 700 | 0.8 | `labelLarge` |
| Section label (ALL CAPS, green) | Barlow Condensed | 13sp | 600 | 2.2 | `labelSmall` |

- Big numbers (ELO, scores, rank positions, stats) always use `GoogleFonts.barlowCondensed` bold.
- Never use negative letter spacing with condensed type.
- Section labels (`QUÉ QUIERES HACER`, `ESTADÍSTICAS`, etc.) use `labelSmall` (green) and are uppercase in content, not in code. Button labels are uppercased by `OnzeButton` automatically.

---

## Spacing & Sizing

- **4pt grid** — all padding/margin values are multiples of 4: `4, 8, 12, 16, 20, 24, 32, 48`.
- **Border radius** (constants on `OnzeTheme`):
  - Cards: `22dp` (`OnzeTheme.radiusCard`)
  - List rows: `18dp` (`OnzeTheme.radiusRow`)
  - Inputs: `16dp` (`OnzeTheme.radiusInput`)
  - Dialogs: `24dp` (`OnzeTheme.radiusDialog`)
  - Bottom sheets: `28dp` top corners (`OnzeTheme.radiusSheet`)
  - Buttons / chips / dock: full pill (`StadiumBorder` / `OnzeTheme.radiusPill`)
- **Card borders:** 1px `OnzeColors.border` — no heavy shadows (only the dock casts a soft shadow).
- **Button height:** `54px` minimum (set via `minimumSize` in theme).

---

## Motion

Tokens live in `lib/core/theme/onze_motion.dart` (`OnzeMotion`).

| Token | Value | Usage |
|---|---|---|
| `OnzeMotion.fast` | 140ms | Press feedback, icon swaps |
| `OnzeMotion.medium` | 240ms | Chips, dock tabs, content switches (`AnimatedSwitcher`) |
| `OnzeMotion.slow` | 340ms | Banners, page transitions |
| `OnzeMotion.enter` | `easeOutCubic` | Elements entering |
| `OnzeMotion.exit` | `easeInCubic` | Elements leaving |
| `OnzeMotion.emphasized` | `easeInOutCubic` | Size/position changes |

**Rules:**
- Page transitions are global (`OnzePageTransitionsBuilder` in `PageTransitionsTheme`) — never add per-route transitions.
- Tappable surfaces get press-scale feedback by wrapping with `OnzePressable` (`lib/shared/widgets/onze_pressable.dart`). `OnzeButton`, `OnzeCard`, `OnzeSelectChip` and the dock tabs already include it.
- Elements that appear/disappear inside a layout must animate their size (`SizeTransition` / `AnimatedSize`) so siblings reflow smoothly — see `OnzeTipBanner` for the pattern.
- Never use raw `Duration(...)`/`Curves.*` in widgets — always reference `OnzeMotion.*` tokens.

---

## Design System Widgets

All shared UI components live in `lib/shared/widgets/`.

### `OnzeButton`
Primary CTA: green pill, dark label, uppercase Barlow Condensed. Always `isFullWidth: true` by default.

```dart
OnzeButton(
  label: 'Crear equipo',                  // rendered as CREAR EQUIPO
  onPressed: onTap,
  icon: Icons.add,                        // optional
  variant: OnzeButtonVariant.filled,      // or .outline (green border pill)
  isLoading: false,
  isFullWidth: true,
)
```

### `OnzeSelectChip`
Pill chip. Selected: green fill + `onAccent` text. Unselected: surface fill + border.

### `OnzeDock` / `OnzeShell`
Floating pill navigation dock (5 tabs: Inicio, Canchas, Equipo, Ranking, Perfil), mounted by `OnzeShell` over a `StatefulShellRoute` in `app_router.dart`. The active tab expands into a green pill with its label.

- Tab screens need bottom content padding ≥ `120` so lists scroll clear of the dock.
- Detail screens live OUTSIDE the shell and cover the dock when pushed.
- Navigate BETWEEN tabs with `context.go(...)`; push detail screens with `context.push(...)`.

---

## Card Pattern

Stadium Night cards are soft rounded containers — surface fill, 1px border, radius 22. No left accent bars. Icons sit on a `greenGlow` rounded tile:

```dart
Container(
  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
  decoration: BoxDecoration(
    color: OnzeColors.surface,
    borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
    border: Border.all(color: OnzeColors.border),
  ),
  child: Row(
    children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: OnzeColors.greenGlow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: OnzeColors.highlight, size: 23),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.barlowCondensed(
              fontSize: 18, fontWeight: FontWeight.w600,
              letterSpacing: 0.5, color: OnzeColors.textPrimary)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      const Icon(Icons.chevron_right, color: OnzeColors.textDim, size: 20),
    ],
  ),
)
```

Tappable cards wrap in `OnzePressable` + `GestureDetector` (or use `OnzeCard` with `onTap`).

---

## Layout Rules

- Scaffold body always inside `SafeArea`.
- Main content areas use `ListView` or `SingleChildScrollView` with `padding: EdgeInsets.all(24)` or `fromLTRB(20, 24, 20, 24)` — bottom `120` on dock tab screens.
- Screen-level Column structure: `[Header, Expanded(ListView)]`.
- Empty states: `Center → Padding(32) → Column(mainAxisSize: min) → [Icon(64), Text, OnzeButton]`.

---

## Icon Usage

- Material icons via `Icons.*`, outlined variants preferred (`Icons.group_outlined`, `Icons.map_outlined`).
- Icon size in cards: `23px` on green-glow tiles, `20px` secondary (chevron, badge).
- Active / highlight icons: `OnzeColors.highlight`; on green fills: `OnzeColors.onAccent`.
- Secondary icons: `OnzeColors.textSecondary`.

---

## Navigation Style

- `AppBar` is dark (`backgroundColor: OnzeColors.background`), no elevation, left-aligned title in Barlow Condensed 22/700 with wide tracking.
- Main navigation is the floating `OnzeDock` (see above) — detail flows use `go_router` with `context.push` / `context.pop` and cover the dock.
- Circular 1px-border icon buttons (38–40px) for header actions (profile, notifications).
