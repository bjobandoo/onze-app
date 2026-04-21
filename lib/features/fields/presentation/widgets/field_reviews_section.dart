// Sección de reseñas de cancha: resumen de calificación, reseña propia y lista.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_review.dart';
import '../providers/fields_providers.dart';

/// Sección de reseñas embebida en el panel inferior de la cancha.
class FieldReviewsSection extends ConsumerWidget {
  const FieldReviewsSection({super.key, required this.field});

  final Field field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync  = ref.watch(fieldReviewsProvider(field.id));
    final myReviewAsync = ref.watch(myFieldReviewProvider(field.id));
    final currentUser   = ref.watch(currentUserProvider).valueOrNull;

    final reviews  = reviewsAsync.valueOrNull ?? [];
    final myReview = myReviewAsync.valueOrNull;

    // Reseñas de otros usuarios (excluye la propia para no duplicarla)
    final otherReviews = reviews
        .where((r) => r.userId != currentUser?.id)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewsSummary(
          averageRating: field.averageRating,
          totalCount: reviews.length,
        ),
        const SizedBox(height: 12),
        // Reseña del usuario actual
        if (myReview != null) ...[
          _MyReviewCard(
            review: myReview,
            fieldId: field.id,
          ),
          const SizedBox(height: 10),
        ] else ...[
          _WriteReviewButton(fieldId: field.id),
          const SizedBox(height: 10),
        ],
        // Reseñas de otros
        if (otherReviews.isNotEmpty) ...[
          ...otherReviews.map((r) => _ReviewCard(review: r)),
        ] else if (myReview == null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Sé el primero en reseñar esta cancha.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resumen de calificación (barra superior)
// ---------------------------------------------------------------------------

class _ReviewsSummary extends StatelessWidget {
  const _ReviewsSummary({
    required this.averageRating,
    required this.totalCount,
  });

  final double averageRating;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Reseñas',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (totalCount > 0) ...[
          _StarRow(rating: averageRating, size: 14),
          const SizedBox(width: 6),
          Text(
            averageRating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OnzeColors.warning,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($totalCount)',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
          ),
        ] else ...[
          Text(
            'Sin reseñas aún',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Botón para escribir reseña
// ---------------------------------------------------------------------------

class _WriteReviewButton extends StatelessWidget {
  const _WriteReviewButton({required this.fieldId});
  final String fieldId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openForm(context, fieldId: fieldId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: OnzeColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: OnzeColors.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_outline, color: OnzeColors.warning, size: 16),
            const SizedBox(width: 6),
            Text(
              'Escribe una reseña',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.highlight,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de la reseña propia (con editar / eliminar)
// ---------------------------------------------------------------------------

class _MyReviewCard extends ConsumerWidget {
  const _MyReviewCard({required this.review, required this.fieldId});

  final FieldReview review;
  final String fieldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(submitReviewProvider(fieldId));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnzeColors.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: OnzeColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: review.rating.toDouble(), size: 14),
              const Spacer(),
              Text(
                'Tu reseña',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.highlight,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              // Editar
              GestureDetector(
                onTap: () =>
                    _openForm(context, fieldId: fieldId, existing: review),
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: OnzeColors.textSecondary),
              ),
              const SizedBox(width: 8),
              // Eliminar
              GestureDetector(
                onTap: submitState.isLoading
                    ? null
                    : () => _confirmDelete(context, ref),
                child: submitState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: OnzeColors.error),
                      )
                    : const Icon(Icons.close,
                        size: 16, color: OnzeColors.error),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: OnzeColors.surfaceHigh,
        title: const Text('Eliminar reseña'),
        content:
            const Text('¿Seguro que quieres eliminar tu reseña?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: OnzeColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(submitReviewProvider(fieldId).notifier).delete();
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de reseña de otro usuario
// ---------------------------------------------------------------------------

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final FieldReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnzeAvatar(
            imageUrl: review.userAvatarUrl,
            name: review.userName ?? '?',
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.userName ?? 'Jugador',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StarRow(
                        rating: review.rating.toDouble(), size: 11),
                    const SizedBox(width: 6),
                    Text(
                      _relativeDate(review.createdAt),
                      style: const TextStyle(
                          fontSize: 10,
                          color: OnzeColors.textSecondary),
                    ),
                  ],
                ),
                if (review.comment != null &&
                    review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    review.comment!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: OnzeColors.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 30) return 'hace ${(diff.inDays / 30).floor()} mes(es)';
    if (diff.inDays >= 7)  return 'hace ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays >= 1)  return 'hace ${diff.inDays} día(s)';
    if (diff.inHours >= 1) return 'hace ${diff.inHours}h';
    return 'hace un momento';
  }
}

// ---------------------------------------------------------------------------
// Fila de estrellas (solo lectura)
// ---------------------------------------------------------------------------

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half   = !filled && i < rating;
        return Icon(
          half
              ? Icons.star_half
              : filled
                  ? Icons.star
                  : Icons.star_outline,
          size: size,
          color: OnzeColors.warning,
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulario de reseña (bottom sheet)
// ---------------------------------------------------------------------------

void _openForm(
  BuildContext context, {
  required String fieldId,
  FieldReview? existing,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OnzeColors.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ReviewFormSheet(
      fieldId: fieldId,
      existing: existing,
    ),
  );
}

class _ReviewFormSheet extends ConsumerStatefulWidget {
  const _ReviewFormSheet({required this.fieldId, this.existing});

  final String fieldId;
  final FieldReview? existing;

  @override
  ConsumerState<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<_ReviewFormSheet> {
  int _rating = 0;
  late final TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _rating      = widget.existing?.rating ?? 0;
    _commentCtrl = TextEditingController(text: widget.existing?.comment ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitReviewProvider(widget.fieldId));
    final isEdit      = widget.existing != null;

    // Cierra el sheet automáticamente al guardar
    ref.listen(submitReviewProvider(widget.fieldId), (_, next) {
      if (next.success && context.mounted) Navigator.pop(context);
    });

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: OnzeColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            isEdit ? 'Editar reseña' : 'Califica esta cancha',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          // Star picker
          _StarPicker(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 20),
          // Comment field
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Comentario (opcional)',
              hintStyle: const TextStyle(color: OnzeColors.textSecondary),
              filled: true,
              fillColor: OnzeColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: OnzeColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: OnzeColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: OnzeColors.accent, width: 1.5),
              ),
              counterStyle:
                  const TextStyle(color: OnzeColors.textSecondary, fontSize: 11),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (submitState.hasError) ...[
            const SizedBox(height: 8),
            Text(
              submitState.errorMessage!,
              style: const TextStyle(
                  color: OnzeColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OnzeColors.border),
                    foregroundColor: OnzeColors.textSecondary,
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _rating == 0 || submitState.isLoading
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnzeColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        OnzeColors.accent.withValues(alpha: 0.4),
                  ),
                  child: submitState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Guardar cambios' : 'Publicar reseña'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    await ref.read(submitReviewProvider(widget.fieldId).notifier).submit(
          rating:  _rating,
          comment: _commentCtrl.text,
        );
  }
}

// ---------------------------------------------------------------------------
// Star picker interactivo
// ---------------------------------------------------------------------------

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: filled ? OnzeColors.warning : OnzeColors.border,
            ),
          ),
        );
      }),
    );
  }
}
