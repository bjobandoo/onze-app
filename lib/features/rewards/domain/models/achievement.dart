// Modelos de dominio para logros coleccionables de Onze.

import 'package:flutter/material.dart';

enum AchievementTargetType {
  user,
  team;

  static AchievementTargetType fromDb(String v) =>
      v == 'team' ? AchievementTargetType.team : AchievementTargetType.user;
}

/// Entrada del catálogo de logros.
class Achievement {
  const Achievement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.targetType,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final AchievementTargetType targetType;

  /// Emoji representativo del logro derivado del código.
  String get emoji => _emojiForCode(code);

  /// Color de acento del logro derivado del código.
  Color get accentColor => _colorForCode(code);

  static String _emojiForCode(String code) => switch (code) {
        'first_team'   => '👕',
        'captain'      => '⭐',
        'first_match'  => '⚽',
        'first_win'    => '🏆',
        'win_streak_3' => '🔥',
        'win_streak_5' => '⚡',
        'matches_10'   => '📅',
        'matches_25'   => '🎖️',
        'elo_bronce'   => '🥉',
        'elo_plata'    => '🥈',
        'elo_oro'      => '🥇',
        'elo_platino'  => '💎',
        'elo_diamante' => '👑',
        _              => '🏅',
      };

  static Color _colorForCode(String code) {
    if (code.startsWith('elo_')) {
      return switch (code) {
        'elo_plata'    => const Color(0xFFC0C0C0),
        'elo_oro'      => const Color(0xFFFFD700),
        'elo_platino'  => const Color(0xFF00CED1),
        'elo_diamante' => const Color(0xFFB44FCA),
        _              => const Color(0xFFCD7F32),
      };
    }
    return switch (code) {
      'first_win'    => const Color(0xFFFFD700),
      'win_streak_3' => const Color(0xFFFF6B35),
      'win_streak_5' => const Color(0xFFFF3B30),
      'captain'      => const Color(0xFF3BDC1E),
      _              => const Color(0xFF2FA818),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id:         map['id'] as String,
        code:       map['code'] as String,
        name:       map['name'] as String,
        description: map['description'] as String,
        targetType: AchievementTargetType.fromDb(map['target_type'] as String),
      );
}

/// Logro obtenido por un usuario o equipo, con fecha de desbloqueo.
class EarnedAchievement {
  const EarnedAchievement({
    required this.achievement,
    required this.unlockedAt,
  });

  final Achievement achievement;
  final DateTime unlockedAt;

  factory EarnedAchievement.fromMap(Map<String, dynamic> map) {
    final raw = map['achievement'] as Map<String, dynamic>;
    return EarnedAchievement(
      achievement: Achievement.fromMap(raw),
      unlockedAt:  DateTime.parse(map['unlocked_at'] as String),
    );
  }
}
