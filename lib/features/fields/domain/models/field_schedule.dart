// Modelo de bloque horario de una cancha.

import 'package:flutter/material.dart';

/// Nombres de días de la semana (1=lunes … 6=sábado, 0=domingo).
const List<String> kDayNames = [
  'Domingo',   // 0
  'Lunes',     // 1
  'Martes',    // 2
  'Miércoles', // 3
  'Jueves',    // 4
  'Viernes',   // 5
  'Sábado',    // 6
];

/// Orden de visualización: Lunes a Domingo.
const List<int> kDayOrder = [1, 2, 3, 4, 5, 6, 0];

/// Bloque horario disponible en una cancha para un día de la semana.
class FieldSchedule {
  const FieldSchedule({
    required this.id,
    required this.fieldId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.isActive = true,
  });

  final String id;
  final String fieldId;

  /// 0 = domingo, 1 = lunes, …, 6 = sábado.
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double price;
  final bool isActive;

  String get dayName => kDayNames[dayOfWeek];

  /// Muestra el rango horario: "08:00 – 10:00".
  String get timeRange =>
      '${_fmt(startTime)} – ${_fmt(endTime)}';

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  factory FieldSchedule.fromMap(Map<String, dynamic> map) {
    return FieldSchedule(
      id: map['id'] as String,
      fieldId: map['field_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: _parseTime(map['start_time'] as String),
      endTime: _parseTime(map['end_time'] as String),
      price: (map['price'] as num).toDouble(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'field_id': fieldId,
        'day_of_week': dayOfWeek,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'price': price,
        'is_active': isActive,
      };

  FieldSchedule copyWith({
    bool? isActive,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    double? price,
  }) =>
      FieldSchedule(
        id: id,
        fieldId: fieldId,
        dayOfWeek: dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        price: price ?? this.price,
        isActive: isActive ?? this.isActive,
      );

  static TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
