// Widget de tarjeta de cancha con badge de estado de verificación.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/field.dart';

/// Tarjeta compacta que muestra una [Field] con su estado de verificación.
class FieldStatusCard extends StatelessWidget {
  const FieldStatusCard({
    super.key,
    required this.field,
    required this.onTap,
  });

  final Field field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OnzeColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhoto(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          field.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _VerificationBadge(verified: field.verified),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    field.fieldType.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    field.address,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.textSecondary,
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
    );
  }

  Widget _buildPhoto() {
    final url = field.firstPhotoUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _PhotoPlaceholder(),
              )
            : _PhotoPlaceholder(),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: OnzeColors.surface,
      child: const Center(
        child: Icon(
          Icons.sports_soccer,
          size: 40,
          color: OnzeColors.textSecondary,
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? OnzeColors.highlight : OnzeColors.warning;
    final label = verified ? 'Verificada' : 'Pendiente';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
