// Pantalla donde el capitán reporta el resultado de su equipo en un partido.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/match.dart';
import '../providers/matches_providers.dart';

/// Pantalla de reporte de resultado para un capitán.
///
/// Recibe el [match] a reportar. El capitán elige Ganamos / Empatamos /
/// Perdimos. Tras confirmar, se navega atrás y se invalidan los providers.
class ReportResultScreen extends ConsumerWidget {
  const ReportResultScreen({super.key, required this.match});

  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportMatchProvider(match.id));

    // Cuando el reporte se completa, navegar atrás
    ref.listen(reportMatchProvider(match.id), (_, next) {
      if (next.isDone && context.mounted) {
        _showResultFeedback(context, ref, next.resultStatus!);
      }
    });

    // Si la ventana venció, mostrar pantalla de plazo vencido
    if (match.isReportWindowExpired) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportar resultado')),
        body: _ExpiredView(match: match),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar resultado')),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: OnzeColors.accent))
          : _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, ReportMatchState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MatchHeader(match: match),
          const SizedBox(height: 32),
          Text(
            '¿CUÁL FUE EL RESULTADO\nDE TU EQUIPO?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: OnzeColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Reporta el resultado desde la perspectiva de tu equipo.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _DeadlineBanner(match: match),
          const SizedBox(height: 24),
          _ReportButton(
            label: 'GANAMOS',
            icon: Icons.emoji_events_outlined,
            color: OnzeColors.accent,
            onTap: () => _confirm(context, ref, MatchReport.win),
          ),
          const SizedBox(height: 12),
          _ReportButton(
            label: 'EMPATAMOS',
            icon: Icons.handshake_outlined,
            color: OnzeColors.warning,
            onTap: () => _confirm(context, ref, MatchReport.draw),
          ),
          const SizedBox(height: 12),
          _ReportButton(
            label: 'PERDIMOS',
            icon: Icons.sports_score_outlined,
            color: OnzeColors.error,
            onTap: () => _confirm(context, ref, MatchReport.loss),
          ),
          if (state.hasError) ...[
            const SizedBox(height: 20),
            _ErrorBanner(message: state.errorMessage!),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, MatchReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: OnzeColors.surface,
        title: const Text('Confirmar reporte'),
        content: Text(
          '¿Seguro que quieres reportar "${report.label}" para este partido?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Confirmar',
              style: TextStyle(
                color: report == MatchReport.win
                    ? OnzeColors.accent
                    : report == MatchReport.draw
                        ? OnzeColors.warning
                        : OnzeColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(reportMatchProvider(match.id).notifier)
          .report(matchId: match.id, report: report);
    }
  }

  void _showResultFeedback(
      BuildContext context, WidgetRef ref, String newStatus) {
    String title;
    String message;
    Color color;

    switch (newStatus) {
      case 'resolved':
        title = '¡Resultado confirmado!';
        message =
            'Ambos capitanes reportaron el mismo resultado. El partido ha sido resuelto.';
        color = OnzeColors.accent;
      case 'disputed':
        title = 'Disputa registrada';
        message =
            'Los resultados no coinciden. El dueño de la cancha resolverá la disputa.';
        color = OnzeColors.warning;
      default:
        title = 'Reporte enviado';
        message =
            'Tu reporte fue guardado. Esperando el reporte del otro capitán.';
        color = OnzeColors.accent;
    }

    // Invalidar providers para actualizar la UI
    ref.invalidate(myMatchesProvider);
    ref.invalidate(pendingMyReportProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: OnzeColors.surface,
        title: Row(
          children: [
            Icon(
              newStatus == 'disputed'
                  ? Icons.warning_amber_outlined
                  : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // volver a la pantalla anterior
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TeamInfo(
                  name: match.teamAName, shieldUrl: match.teamAShieldUrl),
              Text(
                'VS',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: OnzeColors.textSecondary,
                ),
              ),
              _TeamInfo(
                  name: match.teamBName, shieldUrl: match.teamBShieldUrl),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: OnzeColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: OnzeColors.textSecondary),
              const SizedBox(width: 6),
              Text(match.dateLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 16),
              const Icon(Icons.access_time_outlined,
                  size: 14, color: OnzeColors.textSecondary),
              const SizedBox(width: 6),
              Text(match.timeRange,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stadium_outlined,
                  size: 14, color: OnzeColors.textSecondary),
              const SizedBox(width: 6),
              Text(match.fieldName,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamInfo extends StatelessWidget {
  const _TeamInfo({required this.name, this.shieldUrl});
  final String name;
  final String? shieldUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnzeAvatar(imageUrl: shieldUrl, name: name, radius: 28),
        const SizedBox(height: 6),
        SizedBox(
          width: 100,
          child: Text(
            name,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de cuenta regresiva del deadline de reporte.
class _DeadlineBanner extends StatelessWidget {
  const _DeadlineBanner({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final remaining = match.timeUntilDeadline;
    final isUrgent = remaining.inHours < 4 && !remaining.isNegative;
    final color = isUrgent ? OnzeColors.error : OnzeColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.deadlineLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'Tiempo restante: ${match.countdownLabel}',
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista cuando el plazo de reporte venció.
class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_outlined,
              size: 64, color: OnzeColors.textSecondary),
          const SizedBox(height: 20),
          Text(
            'Plazo de reporte vencido',
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'El plazo de 24 horas para reportar este partido ya venció.\n'
            'El sistema procesará el resultado automáticamente.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: OnzeColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            match.deadlineLabel.replaceFirst('Hasta el', 'Venció el'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnzeColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnzeColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OnzeColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: OnzeColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
