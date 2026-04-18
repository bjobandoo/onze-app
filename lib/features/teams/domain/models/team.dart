// Modelo de dominio de un equipo.

import 'package:flutter/material.dart';

/// Tier ELO del equipo según su puntuación.
enum EloTier {
  bronce,
  plata,
  oro,
  platino,
  diamante;

  static EloTier fromRating(int rating) {
    if (rating >= 1600) return EloTier.diamante;
    if (rating >= 1400) return EloTier.platino;
    if (rating >= 1200) return EloTier.oro;
    if (rating >= 1000) return EloTier.plata;
    return EloTier.bronce;
  }

  String get label => switch (this) {
        EloTier.bronce   => 'Bronce',
        EloTier.plata    => 'Plata',
        EloTier.oro      => 'Oro',
        EloTier.platino  => 'Platino',
        EloTier.diamante => 'Diamante',
      };

  Color get color => switch (this) {
        EloTier.bronce   => const Color(0xFFCD7F32),
        EloTier.plata    => const Color(0xFFC0C0C0),
        EloTier.oro      => const Color(0xFFFFD700),
        EloTier.platino  => const Color(0xFF00CED1),
        EloTier.diamante => const Color(0xFFB44FCA),
      };

  String get emoji => switch (this) {
        EloTier.bronce   => '🥉',
        EloTier.plata    => '🥈',
        EloTier.oro      => '🥇',
        EloTier.platino  => '💎',
        EloTier.diamante => '👑',
      };
}

/// Representa un equipo de fútbol dentro de la aplicación.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.captainId,
    required this.createdAt,
    this.shieldUrl,
    this.description,
    this.isActive = true,
    this.eloRating = 1000,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.matchesPlayed = 0,
    this.isSuspended = false,
    this.suspensionUntil,
    this.yellowCardsCount = 0,
  });

  final String id;
  final String name;
  final String captainId;
  final DateTime createdAt;
  final String? shieldUrl;
  final String? description;
  final bool isActive;

  // Estadísticas globales
  final int eloRating;
  final int wins;
  final int losses;
  final int draws;
  final int matchesPlayed;

  // Sanciones
  final bool isSuspended;
  final DateTime? suspensionUntil;
  final int yellowCardsCount;

  /// True si la suspensión sigue vigente (comprueba fecha en cliente).
  bool get isActivelySuspended {
    if (!isSuspended) return false;
    if (suspensionUntil == null) return true; // permanente
    return DateTime.now().isBefore(suspensionUntil!);
  }

  EloTier get eloTier => EloTier.fromRating(eloRating);

  double get winRate =>
      matchesPlayed > 0 ? wins / matchesPlayed : 0.0;

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        id: map['id'] as String,
        name: map['name'] as String,
        captainId: map['captain_id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        shieldUrl: map['shield_url'] as String?,
        description: map['description'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        eloRating: map['elo_rating'] as int? ?? 1000,
        wins: map['wins'] as int? ?? 0,
        losses: map['losses'] as int? ?? 0,
        draws: map['draws'] as int? ?? 0,
        matchesPlayed: map['matches_played'] as int? ?? 0,
        isSuspended: map['is_suspended'] as bool? ?? false,
        suspensionUntil: map['suspension_until'] != null
            ? DateTime.parse(map['suspension_until'] as String)
            : null,
        yellowCardsCount: map['yellow_cards_count'] as int? ?? 0,
      );

  Team copyWith({
    String? shieldUrl,
    String? description,
    bool? isActive,
    int? eloRating,
    int? wins,
    int? losses,
    int? draws,
    int? matchesPlayed,
  }) =>
      Team(
        id: id,
        name: name,
        captainId: captainId,
        createdAt: createdAt,
        shieldUrl: shieldUrl ?? this.shieldUrl,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        eloRating: eloRating ?? this.eloRating,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
        matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      );
}
