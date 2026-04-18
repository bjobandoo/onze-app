// Implementación del repositorio de sanciones usando Supabase.

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/yellow_card.dart';
import '../domain/sanctions_repository.dart';

class SanctionsRepositoryImpl implements SanctionsRepository {
  @override
  Future<List<YellowCard>> getMyYellowCards() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await supabase
          .from('yellow_cards')
          .select()
          .eq('target_type', 'user')
          .eq('target_id', userId)
          .order('issued_at', ascending: false);

      return (rows as List)
          .map((r) => YellowCard.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener tarjetas del usuario', error: e);
      throw DatabaseException(
          'No se pudieron cargar las sanciones.', code: e.code);
    }
  }

  @override
  Future<List<YellowCard>> getTeamYellowCards(String teamId) async {
    try {
      final rows = await supabase
          .from('yellow_cards')
          .select()
          .eq('target_type', 'team')
          .eq('target_id', teamId)
          .order('issued_at', ascending: false);

      return (rows as List)
          .map((r) => YellowCard.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener tarjetas del equipo', error: e);
      throw DatabaseException(
          'No se pudieron cargar las sanciones del equipo.', code: e.code);
    }
  }

  @override
  Future<void> submitAppeal({
    required String cardId,
    required String reason,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('No hay sesión activa.');
    try {
      await supabase.from('appeals').insert({
        'yellow_card_id': cardId,
        'submitted_by': userId,
        'reason': reason.trim(),
      });
      // Marcar la tarjeta como apelada
      await supabase
          .from('yellow_cards')
          .update({'appealed': true})
          .eq('id', cardId);

      log.i('Apelación enviada para tarjeta $cardId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al enviar apelación', error: e);
      throw DatabaseException(
          'No se pudo enviar la apelación.', code: e.code);
    }
  }
}
