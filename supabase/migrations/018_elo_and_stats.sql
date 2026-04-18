-- Migration: 018_elo_and_stats.sql
-- Cálculo de ELO y actualización de estadísticas de equipo e individuales
-- al resolverse un partido. Se integra en report_match_result y
-- resolve_match_dispute (reemplaza las versiones anteriores).
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.calculate_and_apply_elo(uuid);
--   (restaurar versiones de 016 de report_match_result y resolve_match_dispute)

-- ---------------------------------------------------------------------------
-- 1. Función principal de cálculo ELO + actualización de stats
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_and_apply_elo(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    public.matches%ROWTYPE;
  v_elo_a    integer;
  v_elo_b    integer;
  v_e_a      float;
  v_s_a      float;   -- score A: 1=win, 0.5=draw, 0=loss
  v_s_b      float;   -- score B
  v_delta_a  integer;
  v_delta_b  integer;
  v_k        integer := 32;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id;

  IF NOT FOUND THEN RETURN; END IF;
  IF v_match.status != 'resolved' THEN RETURN; END IF;
  IF v_match.final_result IS NULL THEN RETURN; END IF;

  -- Evitar aplicar dos veces (si ya tiene cambio distinto de 0 no recalcular)
  IF v_match.team_a_elo_change != 0 OR v_match.team_b_elo_change != 0 THEN
    RETURN;
  END IF;

  -- ELO actual de cada equipo
  SELECT elo_rating INTO v_elo_a FROM public.teams WHERE id = v_match.team_a_id;
  SELECT elo_rating INTO v_elo_b FROM public.teams WHERE id = v_match.team_b_id;

  -- Puntuación esperada (fórmula ELO estándar)
  v_e_a := 1.0 / (1.0 + power(10.0, (v_elo_b - v_elo_a) / 400.0));

  -- Resultado real
  CASE v_match.final_result
    WHEN 'team_a_win' THEN v_s_a := 1.0; v_s_b := 0.0;
    WHEN 'team_b_win' THEN v_s_a := 0.0; v_s_b := 1.0;
    ELSE                   v_s_a := 0.5; v_s_b := 0.5;
  END CASE;

  -- Deltas (K = 32)
  v_delta_a := round(v_k * (v_s_a - v_e_a));
  v_delta_b := round(v_k * (v_s_b - (1.0 - v_e_a)));

  -- Guardar cambios en el partido
  UPDATE public.matches
  SET team_a_elo_change = v_delta_a,
      team_b_elo_change = v_delta_b
  WHERE id = p_match_id;

  -- Actualizar ELO y stats del equipo A
  UPDATE public.teams
  SET elo_rating     = GREATEST(0, elo_rating + v_delta_a),
      matches_played = matches_played + 1,
      wins           = wins   + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
      draws          = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses         = losses + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_a_id;

  -- Actualizar ELO y stats del equipo B
  UPDATE public.teams
  SET elo_rating     = GREATEST(0, elo_rating + v_delta_b),
      matches_played = matches_played + 1,
      wins           = wins   + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
      draws          = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses         = losses + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_b_id;

  -- Actualizar individual_stats para todos los miembros del equipo A
  INSERT INTO public.individual_stats (user_id, wins, losses, draws, matches_played)
  SELECT tm.user_id,
    CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
    1
  FROM public.team_members tm
  WHERE tm.team_id = v_match.team_a_id
  ON CONFLICT (user_id) DO UPDATE SET
    wins           = individual_stats.wins           + EXCLUDED.wins,
    losses         = individual_stats.losses         + EXCLUDED.losses,
    draws          = individual_stats.draws          + EXCLUDED.draws,
    matches_played = individual_stats.matches_played + 1;

  -- Actualizar individual_stats para todos los miembros del equipo B
  INSERT INTO public.individual_stats (user_id, wins, losses, draws, matches_played)
  SELECT tm.user_id,
    CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
    1
  FROM public.team_members tm
  WHERE tm.team_id = v_match.team_b_id
  ON CONFLICT (user_id) DO UPDATE SET
    wins           = individual_stats.wins           + EXCLUDED.wins,
    losses         = individual_stats.losses         + EXCLUDED.losses,
    draws          = individual_stats.draws          + EXCLUDED.draws,
    matches_played = individual_stats.matches_played + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Actualizar report_match_result para llamar ELO al resolverse
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.report_match_result(
  p_match_id uuid,
  p_report   match_report
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match      public.matches%ROWTYPE;
  v_is_a       boolean;
  v_new_status text;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Partido no encontrado'; END IF;

  IF v_match.status NOT IN ('scheduled', 'awaiting_report') THEN
    RAISE EXCEPTION 'El partido no está disponible para reportar (estado: %)', v_match.status;
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.teams WHERE id = v_match.team_a_id AND captain_id = auth.uid()
  ) INTO v_is_a;

  IF v_is_a THEN
    IF v_match.team_a_report IS NOT NULL THEN
      RAISE EXCEPTION 'Ya reportaste el resultado de este partido';
    END IF;
    UPDATE public.matches
    SET team_a_report = p_report,
        status        = 'awaiting_report',
        reported_at   = COALESCE(reported_at, NOW())
    WHERE id = p_match_id;
  ELSE
    IF NOT EXISTS(
      SELECT 1 FROM public.teams WHERE id = v_match.team_b_id AND captain_id = auth.uid()
    ) THEN
      RAISE EXCEPTION 'No eres capitán de ninguno de los equipos participantes';
    END IF;
    IF v_match.team_b_report IS NOT NULL THEN
      RAISE EXCEPTION 'Ya reportaste el resultado de este partido';
    END IF;
    UPDATE public.matches
    SET team_b_report = p_report,
        status        = 'awaiting_report',
        reported_at   = COALESCE(reported_at, NOW())
    WHERE id = p_match_id;
  END IF;

  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id;

  IF v_match.team_a_report IS NOT NULL AND v_match.team_b_report IS NOT NULL THEN
    IF (v_match.team_a_report = 'win'  AND v_match.team_b_report = 'loss') THEN
      UPDATE public.matches
      SET status = 'resolved', final_result = 'team_a_win', resolved_at = NOW()
      WHERE id = p_match_id;
      v_new_status := 'resolved';
    ELSIF (v_match.team_a_report = 'loss' AND v_match.team_b_report = 'win') THEN
      UPDATE public.matches
      SET status = 'resolved', final_result = 'team_b_win', resolved_at = NOW()
      WHERE id = p_match_id;
      v_new_status := 'resolved';
    ELSIF (v_match.team_a_report = 'draw' AND v_match.team_b_report = 'draw') THEN
      UPDATE public.matches
      SET status = 'resolved', final_result = 'draw', resolved_at = NOW()
      WHERE id = p_match_id;
      v_new_status := 'resolved';
    ELSE
      UPDATE public.matches SET status = 'disputed' WHERE id = p_match_id;
      v_new_status := 'disputed';
    END IF;
  ELSE
    v_new_status := 'awaiting_report';
  END IF;

  -- Calcular y aplicar ELO si el partido quedó resuelto
  IF v_new_status = 'resolved' THEN
    PERFORM public.calculate_and_apply_elo(p_match_id);
  END IF;

  RETURN v_new_status;
END;
$$;

GRANT EXECUTE ON FUNCTION public.report_match_result(uuid, match_report) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Actualizar resolve_match_dispute para llamar ELO
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_match_dispute(
  p_match_id   uuid,
  p_resolution owner_resolution_type
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match public.matches%ROWTYPE;
  v_final public.match_final_result;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Partido no encontrado'; END IF;

  IF v_match.status <> 'disputed' THEN
    RAISE EXCEPTION 'El partido no está en estado de disputa';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.fields WHERE id = v_match.field_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el dueño de la cancha puede resolver la disputa';
  END IF;

  v_final := CASE p_resolution
    WHEN 'team_a_win' THEN 'team_a_win'::public.match_final_result
    WHEN 'team_b_win' THEN 'team_b_win'::public.match_final_result
    ELSE                   'draw'::public.match_final_result
  END;

  UPDATE public.matches
  SET status           = 'resolved',
      owner_resolution = p_resolution,
      final_result     = v_final,
      resolved_at      = NOW()
  WHERE id = p_match_id;

  -- Aplicar ELO
  PERFORM public.calculate_and_apply_elo(p_match_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_match_dispute(uuid, owner_resolution_type) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Snapshot del periodo actual (llamada manual o por cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_period_snapshot(
  p_period_type  ranking_period_type,
  p_period_start date,
  p_period_end   date
)
RETURNS integer   -- nro de equipos snapshotted
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rank integer := 0;
  v_row  record;
BEGIN
  -- Borrar snapshot previo del mismo periodo si existe
  DELETE FROM public.ranking_snapshots
  WHERE period_type = p_period_type AND period_start = p_period_start;

  -- Insertar snapshot ordenado por ELO actual
  FOR v_row IN
    SELECT id, elo_rating, wins, losses, draws, matches_played
    FROM public.teams
    ORDER BY elo_rating DESC
  LOOP
    v_rank := v_rank + 1;
    INSERT INTO public.ranking_snapshots (
      period_type, period_start, period_end,
      team_id, elo_at_period,
      wins_in_period, matches_in_period, rank_position
    ) VALUES (
      p_period_type, p_period_start, p_period_end,
      v_row.id, v_row.elo_rating,
      v_row.wins, v_row.matches_played, v_rank
    );
  END LOOP;

  RETURN v_rank;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_period_snapshot(ranking_period_type, date, date) TO service_role;
