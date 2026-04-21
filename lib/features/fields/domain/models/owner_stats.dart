// Modelos de estadísticas del panel de dueño de canchas.

/// Periodo de tiempo seleccionado en el panel.
enum StatPeriod {
  week,
  month,
  total;

  String get label => switch (this) {
        StatPeriod.week  => 'Semana',
        StatPeriod.month => 'Mes',
        StatPeriod.total => 'Total',
      };
}

/// Estadísticas de una cancha individual para el panel del dueño.
class OwnerFieldStats {
  const OwnerFieldStats({
    required this.fieldId,
    required this.fieldName,
    required this.averageRating,
    required this.reviewsCount,
    required this.totalMatches,
    required this.matchesLast7d,
    required this.matchesLast30d,
    required this.completedMatches,
    required this.totalRevenue,
    required this.revenueLast7d,
    required this.revenueLast30d,
  });

  final String fieldId;
  final String fieldName;
  final double averageRating;
  final int reviewsCount;
  final int totalMatches;
  final int matchesLast7d;
  final int matchesLast30d;
  final int completedMatches;
  final double totalRevenue;
  final double revenueLast7d;
  final double revenueLast30d;

  /// Porcentaje de partidos completados sobre el total de reservas.
  double get completionRate =>
      totalMatches > 0 ? completedMatches / totalMatches : 0.0;

  int matchesForPeriod(StatPeriod p) => switch (p) {
        StatPeriod.week  => matchesLast7d,
        StatPeriod.month => matchesLast30d,
        StatPeriod.total => totalMatches,
      };

  double revenueForPeriod(StatPeriod p) => switch (p) {
        StatPeriod.week  => revenueLast7d,
        StatPeriod.month => revenueLast30d,
        StatPeriod.total => totalRevenue,
      };

  factory OwnerFieldStats.fromMap(Map<String, dynamic> m) => OwnerFieldStats(
        fieldId:          m['field_id'] as String,
        fieldName:        m['field_name'] as String,
        averageRating:    (m['average_rating'] as num?)?.toDouble() ?? 0.0,
        reviewsCount:     (m['reviews_count'] as num?)?.toInt() ?? 0,
        totalMatches:     (m['total_matches'] as num?)?.toInt() ?? 0,
        matchesLast7d:    (m['matches_7d'] as num?)?.toInt() ?? 0,
        matchesLast30d:   (m['matches_30d'] as num?)?.toInt() ?? 0,
        completedMatches: (m['completed_matches'] as num?)?.toInt() ?? 0,
        totalRevenue:     (m['total_revenue'] as num?)?.toDouble() ?? 0.0,
        revenueLast7d:    (m['revenue_7d'] as num?)?.toDouble() ?? 0.0,
        revenueLast30d:   (m['revenue_30d'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Estadísticas globales + desglose por cancha para el panel del dueño.
class OwnerStats {
  const OwnerStats({
    required this.totalFields,
    required this.totalMatches,
    required this.matchesLast7d,
    required this.matchesLast30d,
    required this.completedMatches,
    required this.totalRevenue,
    required this.revenueLast7d,
    required this.revenueLast30d,
    required this.avgRating,
    required this.fields,
  });

  final int totalFields;
  final int totalMatches;
  final int matchesLast7d;
  final int matchesLast30d;
  final int completedMatches;
  final double totalRevenue;
  final double revenueLast7d;
  final double revenueLast30d;
  final double avgRating;
  final List<OwnerFieldStats> fields;

  double get completionRate =>
      totalMatches > 0 ? completedMatches / totalMatches : 0.0;

  int matchesForPeriod(StatPeriod p) => switch (p) {
        StatPeriod.week  => matchesLast7d,
        StatPeriod.month => matchesLast30d,
        StatPeriod.total => totalMatches,
      };

  double revenueForPeriod(StatPeriod p) => switch (p) {
        StatPeriod.week  => revenueLast7d,
        StatPeriod.month => revenueLast30d,
        StatPeriod.total => totalRevenue,
      };

  factory OwnerStats.fromJson(Map<String, dynamic> json) {
    final global = json['global'] as Map<String, dynamic>;
    final rawFields = json['fields'] as List<dynamic>? ?? [];
    return OwnerStats(
      totalFields:      (global['total_fields'] as num?)?.toInt() ?? 0,
      totalMatches:     (global['total_matches'] as num?)?.toInt() ?? 0,
      matchesLast7d:    (global['matches_7d'] as num?)?.toInt() ?? 0,
      matchesLast30d:   (global['matches_30d'] as num?)?.toInt() ?? 0,
      completedMatches: (global['completed_matches'] as num?)?.toInt() ?? 0,
      totalRevenue:     (global['total_revenue'] as num?)?.toDouble() ?? 0.0,
      revenueLast7d:    (global['revenue_7d'] as num?)?.toDouble() ?? 0.0,
      revenueLast30d:   (global['revenue_30d'] as num?)?.toDouble() ?? 0.0,
      avgRating:        (global['avg_rating'] as num?)?.toDouble() ?? 0.0,
      fields: rawFields
          .map((f) => OwnerFieldStats.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
