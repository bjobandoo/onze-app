-- Migration: 023_achievements_catalog.sql
-- 1. Seed catálogo de logros no-ELO (equipo + usuario).
-- 2. check_and_award_team_achievements(team_id): verifica hitos y otorga logros.
-- 3. check_and_award_user_achievements(user_id): primer equipo y capitanía.
-- 4. Trigger on team_members INSERT → llama (3).
-- 5. Actualiza calculate_and_apply_elo para llamar (2) tras cada partido.
--
-- ROLLBACK:
--   DELETE FROM public.achievements WHERE code IN
--     ('first_match','first_win','win_streak_3','win_streak_5',
--      'matches_10','matches_25','first_team','captain');
--   DROP TRIGGER  IF EXISTS trg_team_member_join ON public.team_members;
--   DROP FUNCTION IF EXISTS public.on_team_member_join();
--   DROP FUNCTION IF EXISTS public.check_and_award_user_achievements(uuid);
--   DROP FUNCTION IF EXISTS public.check_and_award_team_achievements(uuid);
--   (Restaurar calculate_and_apply_elo desde 022 sin llamada a team achievements)

-- ---------------------------------------------------------------------------
-- 1. Catálogo de logros no-ELO
-- ---------------------------------------------------------------------------

INSERT INTO public.achievements (code, name, description, target_type) VALUES
  -- Logros de equipo
  ('first_match',
   'Arranque',
   'Primer partido oficial jugado.',
   'team'),
  ('first_win',
   'Primera sangre',
   'Primera victoria del equipo.',
   'team'),
  ('win_streak_3',
   'Hat-trick de rachas',
   '3 victorias consecutivas.',
   'team'),
  ('win_streak_5',
   'Imparables',
   '5 victorias consecutivas.',
   'team'),
  ('matches_10',
   'Rodaje',
   '10 partidos jugados.',
   'team'),
  ('matches_25',
   'Veteranos',
   '25 partidos jugados.',
   'team'),
  -- Logros de usuario
  ('first_team',
   'Bienvenido',
   'Te uniste a tu primer equipo.',
   'user'),
  ('captain',
   'Líder nato',
   'Capitán de al menos un equipo.',
   'user')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. check_and_award_team_achievements
--    Verifica hitos del equipo y otorga logros. Idempotente.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_and_award_team_achievements(p_team_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team          record;
  v_has_streak_3  boolean;
  v_has_streak_5  boolean;
BEGIN
  SELECT matches_played, wins
  INTO v_team
  FROM public.teams
  WHERE id = p_team_id;

  IF NOT FOUND THEN RETURN; END IF;

  -- first_match: al menos 1 partido jugado
  IF v_team.matches_played >= 1 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'first_match'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- first_win: al menos 1 victoria
  IF v_team.wins >= 1 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'first_win'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- matches_10: 10+ partidos jugados
  IF v_team.matches_played >= 10 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'matches_10'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- matches_25: 25+ partidos jugados
  IF v_team.matches_played >= 25 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'matches_25'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- win_streak_3: últimos 3 partidos resueltos son victorias
  SELECT
    COUNT(*) = 3
    AND bool_and(
      CASE
        WHEN team_a_id = p_team_id THEN final_result = 'team_a_win'
        ELSE final_result = 'team_b_win'
      END
    )
  INTO v_has_streak_3
  FROM (
    SELECT team_a_id, team_b_id, final_result
    FROM public.matches
    WHERE (team_a_id = p_team_id OR team_b_id = p_team_id)
      AND status = 'resolved'
    ORDER BY resolved_at DESC
    LIMIT 3
  ) sub;

  IF v_has_streak_3 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'win_streak_3'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;

  -- win_streak_5: últimos 5 partidos resueltos son victorias
  SELECT
    COUNT(*) = 5
    AND bool_and(
      CASE
        WHEN team_a_id = p_team_id THEN final_result = 'team_a_win'
        ELSE final_result = 'team_b_win'
      END
    )
  INTO v_has_streak_5
  FROM (
    SELECT team_a_id, team_b_id, final_result
    FROM public.matches
    WHERE (team_a_id = p_team_id OR team_b_id = p_team_id)
      AND status = 'resolved'
    ORDER BY resolved_at DESC
    LIMIT 5
  ) sub;

  IF v_has_streak_5 THEN
    INSERT INTO public.team_achievements (team_id, achievement_id)
    SELECT p_team_id, id FROM public.achievements WHERE code = 'win_streak_5'
    ON CONFLICT ON CONSTRAINT uq_team_achievement DO NOTHING;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_award_team_achievements(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. check_and_award_user_achievements
--    Verifica primer equipo y capitanía del usuario. Idempotente.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_and_award_user_achievements(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- first_team: miembro de al menos un equipo
  IF EXISTS (
    SELECT 1 FROM public.team_members WHERE user_id = p_user_id LIMIT 1
  ) THEN
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT p_user_id, id FROM public.achievements WHERE code = 'first_team'
    ON CONFLICT ON CONSTRAINT uq_user_achievement DO NOTHING;
  END IF;

  -- captain: capitán de al menos un equipo
  IF EXISTS (
    SELECT 1 FROM public.teams WHERE captain_id = p_user_id LIMIT 1
  ) THEN
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT p_user_id, id FROM public.achievements WHERE code = 'captain'
    ON CONFLICT ON CONSTRAINT uq_user_achievement DO NOTHING;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_award_user_achievements(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Trigger: al entrar a team_members → check_and_award_user_achievements
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.on_team_member_join()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.check_and_award_user_achievements(NEW.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_team_member_join ON public.team_members;
CREATE TRIGGER trg_team_member_join
  AFTER INSERT ON public.team_members
  FOR EACH ROW
  EXECUTE FUNCTION public.on_team_member_join();

-- ---------------------------------------------------------------------------
-- 5. Actualiza calculate_and_apply_elo para llamar check_and_award_team_achievements
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
      wins   = wins   + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
      draws  = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_a_id;

  UPDATE public.teams
  SET elo_rating     = GREATEST(0, elo_rating + v_delta_b),
      matches_played = matches_played + 1,
      wins   = wins   + CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
      draws  = draws  + CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END
  WHERE id = v_match.team_b_id;

  INSERT INTO public.individual_stats (user_id, wins, losses, draws, matches_played)
  SELECT tm.user_id,
    CASE WHEN v_match.final_result = 'team_a_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'team_b_win' THEN 1 ELSE 0 END,
    CASE WHEN v_match.final_result = 'draw'       THEN 1 ELSE 0 END,
    1
  FROM public.team_members tm WHERE tm.team_id = v_match.team_a_id
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
  FROM public.team_members tm WHERE tm.team_id = v_match.team_b_id
  ON CONFLICT (user_id) DO UPDATE SET
    wins           = individual_stats.wins           + EXCLUDED.wins,
    losses         = individual_stats.losses         + EXCLUDED.losses,
    draws          = individual_stats.draws          + EXCLUDED.draws,
    matches_played = individual_stats.matches_played + 1;

  -- Medallas ELO (migración 022)
  PERFORM public.check_and_award_elo_medals(v_match.team_a_id);
  PERFORM public.check_and_award_elo_medals(v_match.team_b_id);

  -- Logros no-competitivos (migración 023)
  PERFORM public.check_and_award_team_achievements(v_match.team_a_id);
  PERFORM public.check_and_award_team_achievements(v_match.team_b_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Backfill: otorgar logros a equipos y usuarios ya existentes
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.backfill_team_achievements()
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
    PERFORM public.check_and_award_team_achievements(v_team.id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.backfill_user_achievements()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
  v_count integer := 0;
BEGIN
  FOR v_user IN SELECT DISTINCT user_id FROM public.team_members LOOP
    PERFORM public.check_and_award_user_achievements(v_user.user_id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.backfill_team_achievements() TO service_role;
GRANT EXECUTE ON FUNCTION public.backfill_user_achievements() TO service_role;
