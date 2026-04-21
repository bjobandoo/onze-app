// Pantalla de onboarding — guía de bienvenida para nuevos usuarios.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../providers/onboarding_providers.dart';

// ---------------------------------------------------------------------------
// Modelo de diapositiva
// ---------------------------------------------------------------------------

class _Slide {
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.sports_soccer,
    color: OnzeColors.highlight,
    title: 'Bienvenido a Onze',
    body:
        'La app para jugar fútbol amateur en Ibarra. Encuentra canchas, '
        'forma tu equipo y compite por el ranking con tus amigos.',
  ),
  _Slide(
    icon: Icons.group_outlined,
    color: OnzeColors.accent,
    title: 'Equipos y desafíos',
    body:
        'El capitán crea el equipo, reserva canchas y envía desafíos. '
        'Ganar partidos oficiales mejora el rating ELO de tu equipo.',
  ),
  _Slide(
    icon: Icons.leaderboard_outlined,
    color: OnzeColors.highlight,
    title: 'Sistema ELO',
    body:
        'Tu equipo tiene un rating ELO que sube o baja con cada resultado. '
        'Vencer a rivales más fuertes suma más puntos. El top del ranking '
        'se lleva las recompensas.',
  ),
  _Slide(
    icon: Icons.warning_amber_rounded,
    color: OnzeColors.warning,
    title: 'Tarjetas y sanciones',
    body:
        '3 tarjetas amarillas equivalen a 1 tarjeta roja: suspensión '
        'temporal. Las tarjetas se emiten por conducta antideportiva. '
        'Juega limpio.',
  ),
  _Slide(
    icon: Icons.emoji_events_outlined,
    color: OnzeColors.warning,
    title: 'Logros y medallas',
    body:
        'Desbloquea medallas ELO al superar umbrales de rating (Bronce → '
        'Diamante) y logros especiales por primera victoria, rachas de '
        'triunfos y más hitos.',
  ),
];

// ---------------------------------------------------------------------------
// Pantalla principal
// ---------------------------------------------------------------------------

/// Walkthrough de bienvenida mostrado una sola vez al nuevo usuario.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _current = 0;

  bool get _isLast => _current == _slides.length - 1;

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).dismiss(kObDone);
    if (mounted) context.go(AppRoutes.home);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnzeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior con Skip
            _TopBar(onSkip: _finish),
            // Slides
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),
            // Dots + botón
            _BottomBar(
              total: _slides.length,
              current: _current,
              isLast: _isLast,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra superior
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            'ONZE',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: OnzeColors.highlight,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: OnzeColors.textSecondary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 36),
            ),
            child: const Text('Saltar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Página individual del slide
// ---------------------------------------------------------------------------

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono en círculo degradado
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  slide.color.withValues(alpha: 0.25),
                  slide.color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: slide.color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(slide.icon, color: slide.color, size: 52),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: OnzeColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OnzeColors.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra inferior con indicadores y botón
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.current,
    required this.isLast,
    required this.onNext,
  });

  final int total;
  final int current;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DotIndicators(total: total, current: current),
          _NextButton(isLast: isLast, onPressed: onNext),
        ],
      ),
    );
  }
}

class _DotIndicators extends StatelessWidget {
  const _DotIndicators({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: active ? 20 : 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: active
                ? OnzeColors.highlight
                : OnzeColors.textSecondary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onPressed});
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: OnzeColors.highlight,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          isLast ? 'Empezar' : 'Siguiente',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: OnzeColors.background,
          ),
        ),
      ),
    );
  }
}
