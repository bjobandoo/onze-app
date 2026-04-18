-- Migration: 016_match_report_system.sql
-- Sistema de reporte de resultados de partidos.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.mark_matches_awaiting_report();
--   DROP FUNCTION IF EXISTS public.report_match_result(uuid, match_report);
--   DROP FUNCTION IF EXISTS public.resolve_match_dispute(uuid, owner_resolution_type);

-- ---------------------------------------------------------------------------
-- 1. Marca como awaiting_report los partidos cuya hora ya pasó
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_matches_awaiting_report()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.matches
  SET status = 'awaiting_report'
  WHERE status = 'scheduled'
    AND (match_date + start_time) < (NOW() AT TIME ZONE 'America/Guayaquil')::date + (NOW() AT TIME ZONE 'America/Guayaquil')::time;
  SELECT count(*)::integer FROM public.matches
  WHERE status = 'awaiting_report';
$$;

GRANT EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Capitán reporta el resultado de su equipo
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.report_match_result(
  p_match_id  uuid,
  p_report    match_report   -- 'win' | 'loss' | 'draw'
)
RETURNS text   -- devuelve el nuevo status: 'awaiting_report' | 'resolved' | 'disputed'
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match    public.matches%ROWTYPE;
  v_is_a     boolean;
  v_new_status text;
BEGIN
  -- Obtener partido con lock
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partido no encontrado';
  END IF;

  IF v_match.status NOT IN ('scheduled', 'awaiting_report') THEN
    RAISE EXCEPTION 'El partido no está disponible para reportar (estado: %)', v_match.status;
  END IF;

  -- Verificar que el usuario es capitán de alguno de los equipos
  SELECT EXISTS(
    SELECT 1 FROM public.teams
    WHERE id = v_match.team_a_id AND captain_id = auth.uid()
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
    -- Verificar que es capitán de team_b
    IF NOT EXISTS(
      SELECT 1 FROM public.teams
      WHERE id = v_match.team_b_id AND captain_id = auth.uid()
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

  -- Recargar para verificar si ambos reportaron
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id;

  IF v_match.team_a_report IS NOT NULL AND v_match.team_b_report IS NOT NULL THEN
    -- Determinar acuerdo/disputa
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
      -- Los capitanes no se ponen de acuerdo → disputa
      UPDATE public.matches SET status = 'disputed' WHERE id = p_match_id;
      v_new_status := 'disputed';
    END IF;
  ELSE
    v_new_status := 'awaiting_report';
  END IF;

  RETURN v_new_status;
END;
$$;

GRANT EXECUTE ON FUNCTION public.report_match_result(uuid, match_report) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Dueño de cancha resuelve una disputa
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_match_dispute(
  p_match_id   uuid,
  p_resolution owner_resolution_type   -- 'team_a_win' | 'team_b_win' | 'draw'
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
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partido no encontrado';
  END IF;

  IF v_match.status <> 'disputed' THEN
    RAISE EXCEPTION 'El partido no está en estado de disputa';
  END IF;

  -- Verificar que quien llama es dueño de la cancha
  IF NOT EXISTS(
    SELECT 1 FROM public.fields
    WHERE id = v_match.field_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el dueño de la cancha puede resolver la disputa';
  END IF;

  -- Mapear resolución → final_result
  v_final := CASE p_resolution
    WHEN 'team_a_win' THEN 'team_a_win'::public.match_final_result
    WHEN 'team_b_win' THEN 'team_b_win'::public.match_final_result
    ELSE                    'draw'::public.match_final_result
  END;

  UPDATE public.matches
  SET status           = 'resolved',
      owner_resolution = p_resolution,
      final_result     = v_final,
      resolved_at      = NOW()
  WHERE id = p_match_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_match_dispute(uuid, owner_resolution_type) TO authenticated;
