import 'package:flutter/material.dart';

import '../../core/theme/onze_colors.dart';

/// Avatar circular reutilizable del design system.
///
/// Muestra la foto del usuario si [imageUrl] no es null,
/// de lo contrario muestra las iniciales de [name].
class OnzeAvatar extends StatelessWidget {
  const OnzeAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
  });

  final String? imageUrl;

  /// Se usa para extraer las iniciales cuando no hay foto.
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: OnzeColors.surface,
      );
    }

    final initials = _initials(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: OnzeColors.surface,
      child: Text(
        initials,
        style: TextStyle(
          color: OnzeColors.textPrimary,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
