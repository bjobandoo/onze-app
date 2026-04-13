# Onze Design System

Reference for the visual language used in this project. Use this whenever you need to build, review, or fix UI in the Onze app.

---

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| `OnzeColors.background` | `#000000` | Scaffold background — always black |
| `OnzeColors.surface` | `#1C1C1E` | Cards, sheets, secondary surfaces |
| `OnzeColors.surfaceHigh` | `#2C2C2E` | Elevated cards, inputs |
| `OnzeColors.border` | `#3A3A3C` | 1px borders on cards and inputs |
| `OnzeColors.primary` | `#004101` | Brand primary (rarely used alone) |
| `OnzeColors.accent` | `#008001` | Buttons, active states, links |
| `OnzeColors.highlight` | `#00BF00` | CTAs, badges, active indicators, left card bars |
| `OnzeColors.textPrimary` | `#FFFFFF` | Body text, headings |
| `OnzeColors.textSecondary` | `#EBEBF5` at 60% opacity | Subtitles, metadata, placeholders |
| `OnzeColors.error` | `#FF3B30` | Error states, red cards (sanciones) |
| `OnzeColors.warning` | `#FFCC00` | Warning states, yellow cards (sanciones) |

**Rules:**
- Dark-first. Background is always `#000000`.
- `#00BF00` sparingly — badges, active dots, bar accents, primary CTAs. Never fill a whole screen.
- Never hardcode colors — always reference `OnzeColors.*` or `Theme.of(context).colorScheme.*`.

---

## Typography

Font: **Inter** via `google_fonts` package.

| Role | Size | Weight | Letter spacing | Theme token |
|---|---|---|---|---|
| Display / wordmark | 28sp | 700 | -0.5 | `displayLarge` |
| Heading large | 22sp | 700 | -0.3 | `headlineLarge` |
| Heading medium | 18sp | 700 | — | `headlineMedium` |
| Body | 16sp | 400 | — | `bodyLarge` |
| Body medium | 14sp | 400 | — | `bodyMedium` |
| Caption / metadata | 13sp | 400 | — | `bodySmall` |
| Button label | 14sp | 700 | 1.5 | `labelLarge` |
| Section label (ALL CAPS) | 11sp | 700 | 2.0 | `labelSmall` |

Section labels (`QUÉ QUIERES HACER`, `ESTADÍSTICAS`, etc.) always use `Theme.of(context).textTheme.labelSmall` and are uppercase in content, not in code.

---

## Spacing & Sizing

- **4pt grid** — all padding/margin values are multiples of 4: `4, 8, 12, 16, 20, 24, 32, 48`.
- **Border radius:**
  - Cards: `12dp`
  - Buttons: `8dp`
  - Chips / badges: `24dp`
- **Card borders:** 1px `OnzeColors.border` — no heavy shadows.
- **Button height:** `56px` minimum (set via `minimumSize` in theme).

---

## Design System Widgets

All shared UI components live in `lib/shared/widgets/`.

### `OnzeButton`
Primary CTA button. Always `isFullWidth: true` by default (stretches to container width).

```dart
OnzeButton(
  label: 'Crear equipo',
  onPressed: onTap,
  icon: Icons.add,                        // optional
  variant: OnzeButtonVariant.filled,      // or .outline
  isLoading: false,
  isFullWidth: true,
)
```

### `OnzeTextButton`
Plain text link button, no background.

---

## Card Pattern

Home cards use a left accent bar (4px wide, `OnzeColors.highlight`) implemented with `Stack` + `Positioned` to avoid `IntrinsicHeight` layout issues with wrapping text:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Container(
    color: OnzeColors.surfaceHigh,
    child: Stack(
      children: [
        const Positioned(
          top: 0, bottom: 0, left: 0, width: 4,
          child: ColoredBox(color: OnzeColors.highlight),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
          child: Row(
            children: [
              Icon(...),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, ...),
                    Text(subtitle, ...),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, ...),
            ],
          ),
        ),
      ],
    ),
  ),
)
```

**Do NOT use `IntrinsicHeight` + `CrossAxisAlignment.stretch`** for the left bar — this causes bottom overflow when subtitle text wraps.

---

## Layout Rules

- Scaffold body always inside `SafeArea`.
- Main content areas use `ListView` or `SingleChildScrollView` with `padding: EdgeInsets.all(24)` or `fromLTRB(20, 24, 20, 24)`.
- Screen-level Column structure: `[Header, Expanded(ListView)]`.
- Empty states: `Center → Padding(32) → Column(mainAxisSize: min) → [Icon(64), Text, OnzeButton]`.

---

## Icon Usage

- Material icons via `Icons.*`, outlined variants preferred (`Icons.group_outlined`, `Icons.map_outlined`).
- Icon size in cards: `26px` body, `18px` secondary (arrow, badge).
- Active / highlight icons: `OnzeColors.highlight`.
- Secondary icons: `OnzeColors.textSecondary`.

---

## Navigation Style

- `AppBar` is dark (`backgroundColor: OnzeColors.background`), no elevation, left-aligned title.
- No bottom navigation bar (uses `go_router` with `context.push` / `context.pop`).
- Profile access from Home header via `Icons.person_outline` top-right icon.
