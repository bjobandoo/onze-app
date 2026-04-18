// Contrato del repositorio de sanciones.

import 'models/yellow_card.dart';

abstract class SanctionsRepository {
  /// Tarjetas del usuario autenticado.
  Future<List<YellowCard>> getMyYellowCards();

  /// Tarjetas de un equipo específico.
  Future<List<YellowCard>> getTeamYellowCards(String teamId);

  /// El usuario presenta una apelación para una tarjeta.
  Future<void> submitAppeal({
    required String cardId,
    required String reason,
  });
}
