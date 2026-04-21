-- Migration: 022_elo_medals.sql
-- 1. Inserta el catálogo de medallas ELO en la tabla achievements.
-- 2. Crea check_and_award_elo_medals(team_id) — otorga todas las medallas
--    correspondientes al ELO actual (y acumuladas). Idempotente gracias a
--    ON CONFLICT DO NOTHING.
-- 3. Actualiza calculate_and_apply_elo para llamar la función tras cada partido.
--
-- ROLLBACK:
--   DELETE FROM public.achievements WHERE code LIKE 'elo_%';
--   DROP FUNCTION IF EXISTS public.check_and_award_elo_medals(uuid);
--   (Restaurar calculate_and_apply_elo desde migración 018 sin las llamadas)

-- ---------------------------------------------------------------------------
-- 1. Catálogo de medallas ELO
-- ---------------------------------------------------------------------------

INSERT INTO public.achievements (code, name, description, target_type) VALUES
  ('elo_bronce',
   'Bronce',
   'Has entrado al ranking competitivo de Onze.',
   'team'),
  ('elo_plata',
   'Plata',
   'Tu equipo alcanzó 1000 puntos ELO.',
   'team'),
  ('elo_oro',
   'Oro',
   'Tu equipo alcanzó 1200 puntos ELO.',
   'team'),
  ('elo_platino',
   'Platino',
   'Tu equipo alcanzó 1400 puntos ELO.',
   'team'),
  ('elo_diamante',
   'Diamante',
   'Tu equipo alcanzó 1600 puntos ELO — la élite de Onze.',
   'team')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Función: check_and_award_elo_medals
--    Otorga todas las medallas cuyo umbral <= elo_rating actual del equipo.
--    Las medallas son coleccionables: una vez ganada, nunca se pierde aunque
--    el ELO baje.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_and_award_elo_medals(p_team_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_elo integer;
BEGIN
  SELECT elo_rating INTO v_elo FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN RETURN; END IF;

  -- Bronce: siempre (umbral ELO = 0, todos los equipos lo reciben)
  INSERT INTO public.team_achievements (team_id, achievement_id)
  SELECT p_team_id, id
  FROM   public.achievements
  WHERE  code = 'elo_bronce'
  ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;

  -- Plata: ELO >= 1000
  IF v_elo >= 1000 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id
    FROM   public.achievements
    WHERE  code = 'elo_plata'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- Oro: ELO >= 1200
  IF v_elo >= 1200 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id
    FROM   public.achievements
    WHERE  code = 'elo_oro'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- Platino: ELO >= 1400
  IF v_elo >= 1400 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id
    FROM   public.achievements
    WHERE  code = 'elo_platino'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- Diamante: ELO >= 1600
  IF v_elo >= 1600 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id
    FROM   public.achievements
    WHERE  code = 'elo_diamante'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_award_elo_medals(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Actualizar calculate_and_apply_elo para llamar check_and_award_elo_medals
--    tras actualizar el ELO de cada equipo.
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
  v_s_a      float;
  v_s_b      float;
  v_delta_a  integer;
  v_delta_b  integer;
  v_k        integer := 32;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id;

  IF NOT FOUND THEN RETURN; END IF;
  IF v_match.status != 'resolved' THEN RETURN; END IF;
  IF v_match.final_result IS NULL THEN RETURN; END IF;

  -- Evitar aplicar dos veces
  IF v_match.team_a_elo_change != 0 OR v_match.team_b_elo_change != 0 THEN
    RETURN;
  END IF;

  SELECT elo_rating INTO v_elo_a FROM public.teams WHERE id = v_match.team_a_id;
  SELECT elo_rating INTO v_elo_b FROM public.teams WHERE id = v_match.team_b_id;

  v_e_a := 1.0 / (1.0 + power(10.0, (v_elo_b - v_elo_a) / 400.0));

  CASE v_match.final_result
    WHEN 'team_a_win' THEN v_s_a := 1.0; v_s_b := 0.0;
    WHEN 'team_b_win' THEN v_s_a := 0.0; v_s_b := 1.0;
    ELSE                   v_s_a := 0.5; v_s_b := 0.5;
  END CASE;

  v_delta_a := round(v_k * (v_s_a - v_e_a));
  v_delta_b := round(v_k * (v_s_b - (1.0 - v_e_a)));

  UPDATE public.matches
  SET team_a_elo_change = v_delta_a,
      team_b_elo_change = v_delta_b
  WHERE id = p_match_id;

  UPDATE public.teams
  SET elo_rating     = GREATEST(0, elo_rating + v_delta_a),
      matches_played = matches_played + 1,
      wins           = wins   + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
      draws          = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses         = losses + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_a_id;

  UPDATE public.teams
  SET elo_rating     = GREATEST(0, elo_rating + v_delta_b),
      matches_played = matches_played + 1,
      wins           = wins   + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
      draws          = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses         = losses + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_b_id;

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

  -- Otorgar medallas ELO a ambos equipos según nuevo ELO
  PERFORM public.check_and_award_elo_medals(v_match.team_a_id);
  PERFORM public.check_and_award_elo_medals(v_match.team_b_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Función auxiliar para otorgar medallas a equipos ya existentes
--    (backfill manual desde el panel admin o al crear un equipo nuevo).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.backfill_elo_medals()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team record;
  v_count integer := 0;
BEGIN
  FOR v_team IN SELECT id FROM public.teams LOOP
    PERFORM public.check_and_award_elo_medals(v_team.id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.backfill_elo_medals() TO service_role;
