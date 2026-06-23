-- =============================================================================
-- Migración 027 — Reservas amistosas (partidos internos de un solo equipo)
-- =============================================================================
-- Una reserva amistosa la solicita el capitán de un equipo directamente al
-- dueño de la cancha (sin equipo rival). Se entiende como partido interno del
-- equipo: NO registra ELO ni estadísticas, pero sí aparece en el historial.
--
-- Flujo: capitán → create_friendly_booking (status 'pending_owner', bloqueo
-- de 45 min) → el dueño confirma con confirm_match → se crea un match con
-- is_friendly = true y team_b_id NULL. Al pasar su hora, el tick de arranque
-- lo marca directamente 'resolved' (sin final_result → sin ELO).
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.create_friendly_booking(uuid, uuid, date, time, time, numeric);
--   -- Restaurar confirm_match y mark_matches_awaiting_report desde 026.
--   ALTER TABLE public.matches        DROP COLUMN IF EXISTS is_friendly;
--   ALTER TABLE public.match_requests DROP COLUMN IF EXISTS is_friendly;
--   ALTER TABLE public.match_requests ALTER COLUMN challenged_team_id SET NOT NULL;
--   ALTER TABLE public.matches        ALTER COLUMN team_b_id          SET NOT NULL;
--   -- Restaurar constraints chk_different_teams / chk_different_match_teams (004).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Esquema: columnas is_friendly y opcionalidad del rival
-- ---------------------------------------------------------------------------

ALTER TABLE public.match_requests
  ADD COLUMN IF NOT EXISTS is_friendly boolean NOT NULL DEFAULT false;
ALTER TABLE public.match_requests
  ALTER COLUMN challenged_team_id DROP NOT NULL;

ALTER TABLE public.match_requests DROP CONSTRAINT IF EXISTS chk_different_teams;
ALTER TABLE public.match_requests
  ADD CONSTRAINT chk_different_teams
  CHECK (challenged_team_id IS NULL OR challenger_team_id <> challenged_team_id);

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS is_friendly boolean NOT NULL DEFAULT false;
ALTER TABLE public.matches
  ALTER COLUMN team_b_id DROP NOT NULL;

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS chk_different_match_teams;
ALTER TABLE public.matches
  ADD CONSTRAINT chk_different_match_teams
  CHECK (team_b_id IS NULL OR team_a_id <> team_b_id);

COMMENT ON COLUMN public.match_requests.is_friendly IS
  'Reserva amistosa: un solo equipo, sin rival. No cuenta para ELO/estadísticas.';
COMMENT ON COLUMN public.matches.is_friendly IS
  'Partido amistoso: interno de un equipo (team_b_id NULL). No cuenta para ELO/estadísticas.';

-- ---------------------------------------------------------------------------
-- 2. create_friendly_booking
--    El capitán solicita la reserva amistosa directamente al dueño. Espeja la
--    validación de accept_challenge (estado/capitán/suspensiones/solapamiento)
--    y deja la solicitud en pending_owner con bloqueo de 45 min.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_friendly_booking(
  p_team_id  uuid,
  p_field_id uuid,
  p_date     date,
  p_start    time,
  p_end      time,
  p_price    numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request_id uuid;
BEGIN
  IF p_start >= p_end THEN
    RAISE EXCEPTION 'El horario de inicio debe ser anterior al de fin.';
  END IF;

  -- Solo el capitán del equipo puede reservar
  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id AND captain_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el capitán del equipo puede reservar.';
  END IF;

  -- Usuario suspendido no puede reservar
  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_suspended) THEN
    RAISE EXCEPTION 'Tu cuenta está suspendida.';
  END IF;

  -- Equipo suspendido no puede reservar
  IF EXISTS (SELECT 1 FROM public.teams WHERE id = p_team_id AND is_suspended) THEN
    RAISE EXCEPTION 'Tu equipo está suspendido.';
  END IF;

  -- La cancha debe existir
  IF NOT EXISTS (SELECT 1 FROM public.fields WHERE id = p_field_id) THEN
    RAISE EXCEPTION 'Cancha no encontrada.';
  END IF;

  -- El horario no debe estar tomado por otra reserva activa
  IF EXISTS (
    SELECT 1 FROM public.match_requests r
    WHERE r.field_id       = p_field_id
      AND r.requested_date = p_date
      AND (
        r.status = 'confirmed'
        OR (r.status = 'pending_owner' AND r.blocked_until > now())
      )
      AND r.requested_start_time < p_end
      AND r.requested_end_time   > p_start
  ) THEN
    RAISE EXCEPTION 'El horario ya está reservado o bloqueado temporalmente.';
  END IF;

  INSERT INTO public.match_requests (
    challenger_team_id, challenged_team_id, field_id,
    requested_date, requested_start_time, requested_end_time,
    price, status, is_friendly, blocked_until, opponent_responded_at
  ) VALUES (
    p_team_id, NULL, p_field_id,
    p_date, p_start, p_end,
    p_price, 'pending_owner', true, now() + interval '45 minutes', now()
  )
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_friendly_booking(uuid, uuid, date, time, time, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.create_friendly_booking(uuid, uuid, date, time, time, numeric) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. confirm_match: propagar is_friendly y tolerar rival NULL
--    (basada en la versión de 026, añadiendo el caso amistoso)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.confirm_match(p_match_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req      public.match_requests;
  v_match_id uuid;
BEGIN
  SELECT * INTO v_req
  FROM public.match_requests
  WHERE id = p_match_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.fields
    WHERE id = v_req.field_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'No tienes permiso para confirmar esta reserva.';
  END IF;

  IF v_req.status <> 'pending_owner' THEN
    RAISE EXCEPTION 'La solicitud no está en estado pending_owner (actual: %).', v_req.status;
  END IF;

  IF v_req.blocked_until IS NOT NULL AND v_req.blocked_until < now() AT TIME ZONE 'UTC' THEN
    UPDATE public.match_requests
    SET status = 'expired'
    WHERE id = p_match_request_id;
    RAISE EXCEPTION 'El bloqueo temporal ha expirado. El horario ya no está reservado.';
  END IF;

  -- Equipos suspendidos no pueden jugar (challenged_team_id es NULL en amistosos)
  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE id IN (v_req.challenger_team_id, v_req.challenged_team_id)
      AND is_suspended
  ) THEN
    RAISE EXCEPTION 'Uno de los equipos está suspendido.';
  END IF;

  -- Sin solapamiento con partidos ya confirmados en la misma cancha
  IF EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.field_id   = v_req.field_id
      AND m.match_date = v_req.requested_date
      AND m.status    <> 'cancelled'
      AND m.start_time < v_req.requested_end_time
      AND m.end_time   > v_req.requested_start_time
  ) THEN
    RAISE EXCEPTION 'El horario se solapa con un partido ya confirmado.';
  END IF;

  -- Sin solapamiento con bloqueos manuales del dueño
  IF EXISTS (
    SELECT 1 FROM public.field_blocked_slots b
    WHERE b.field_id   = v_req.field_id
      AND b.date       = v_req.requested_date
      AND b.start_time < v_req.requested_end_time
      AND b.end_time   > v_req.requested_start_time
  ) THEN
    RAISE EXCEPTION 'El horario está bloqueado por el dueño de la cancha.';
  END IF;

  UPDATE public.match_requests
  SET status             = 'confirmed',
      owner_responded_at = now()
  WHERE id = p_match_request_id;

  INSERT INTO public.matches (
    match_request_id, team_a_id, team_b_id, field_id,
    match_date, start_time, end_time, status, is_friendly
  ) VALUES (
    v_req.id, v_req.challenger_team_id, v_req.challenged_team_id, v_req.field_id,
    v_req.requested_date, v_req.requested_start_time, v_req.requested_end_time,
    'scheduled', v_req.is_friendly
  )
  RETURNING id INTO v_match_id;

  RETURN v_match_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_match(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.confirm_match(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. mark_matches_awaiting_report: los amistosos no entran al flujo de reporte
--    (basada en la versión de 026). Un amistoso cuya hora pasó se marca
--    directamente 'resolved' (sin final_result → sin ELO) para el historial.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_matches_awaiting_report()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_marked   integer;
  v_friendly integer;
  v_expired  integer;
BEGIN
  -- Levantar suspensiones vencidas
  PERFORM public.lift_expired_suspensions();

  -- Expirar desafíos/reservas cuya fecha/hora ya pasó sin completar el flujo
  UPDATE public.match_requests
  SET status = 'expired'
  WHERE status IN ('pending_opponent', 'pending_owner')
    AND (requested_date::timestamp + requested_end_time)
        AT TIME ZONE 'America/Guayaquil' < NOW();

  -- Expirar bloqueos de 45 min vencidos sin respuesta del dueño
  UPDATE public.match_requests
  SET status = 'expired'
  WHERE status = 'pending_owner'
    AND blocked_until IS NOT NULL
    AND blocked_until < NOW();

  -- Partidos OFICIALES cuya hora ya pasó → awaiting_report
  UPDATE public.matches
  SET status = 'awaiting_report'
  WHERE status = 'scheduled'
    AND is_friendly = false
    AND (match_date::timestamp + start_time)::timestamptz
        AT TIME ZONE 'America/Guayaquil' < NOW();

  GET DIAGNOSTICS v_marked = ROW_COUNT;

  -- Partidos AMISTOSOS cuya hora ya pasó → resolved (sin ELO, solo historial)
  UPDATE public.matches
  SET status = 'resolved', resolved_at = NOW()
  WHERE status = 'scheduled'
    AND is_friendly = true
    AND (match_date::timestamp + start_time)::timestamptz
        AT TIME ZONE 'America/Guayaquil' < NOW();

  GET DIAGNOSTICS v_friendly = ROW_COUNT;

  -- Expirar los oficiales que superaron las 24h de ventana de reporte
  SELECT public.expire_unreported_matches() INTO v_expired;

  RETURN v_marked + v_friendly + v_expired;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_matches_awaiting_report() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;
