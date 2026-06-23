// Sección "Canchas cerca" del Home — estilo Stadium Night.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_theme.dart';
import '../../../../features/fields/domain/models/field.dart';
import '../../../../features/fields/presentation/providers/fields_providers.dart';
import '../../../../features/fields/presentation/widgets/field_detail_sheet.dart';
import '../../../../shared/widgets/onze_pressable.dart';

/// Muestra las dos primeras canchas verificadas como cards compactas.
/// Se oculta por completo si no hay canchas.
class NearbyFieldsSection extends ConsumerWidget {
  const NearbyFieldsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fields = ref.watch(verifiedFieldsProvider).valueOrNull ?? [];
    if (fields.isEmpty) return const SizedBox.shrink();

    final visible = fields.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Canchas cerca',
                style: Theme.of(context).textTheme.headlineMedium),
            GestureDetector(
              onTap: () => context.go(AppRoutes.fieldsMap),
              child: Text(
                'Ver todas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.highlight,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _FieldMiniCard(field: visible[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _FieldMiniCard extends StatelessWidget {
  const _FieldMiniCard({required this.field});

  final Field field;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        onTap: () => showFieldDetailSheet(context, field),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
            border: Border.all(color: OnzeColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldPhoto(url: field.firstPhotoUrl),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            field.name,
                            style: GoogleFonts.barlow(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: OnzeColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded,
                            color: OnzeColors.highlight, size: 13),
                        Text(
                          field.averageRating.toStringAsFixed(1),
                          style: GoogleFonts.barlow(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: OnzeColors.highlight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      field.fieldType.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldPhoto extends StatelessWidget {
  const _FieldPhoto({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      height: 82,
      decoration: BoxDecoration(
        color: OnzeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: OnzeColors.border),
      ),
      child: const Icon(Icons.stadium_outlined,
          color: OnzeColors.textDim, size: 28),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(
        url!,
        height: 82,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
