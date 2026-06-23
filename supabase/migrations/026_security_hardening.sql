-- Migration: 026_security_hardening.sql
-- Endurecimiento de seguridad detectado en auditoría (2026-06-10):
--   1. Revoca EXECUTE de funciones privilegiadas que estaban expuestas a
--      cualquier usuario autenticado (sancionar, recalcular ELO, snapshots).
--   2. Redefine append_role de forma segura (solo el propio usuario, solo 'owner').
--   3. Corrige el guard de idempotencia de calculate_and_apply_elo
--      (un empate entre equipos del mismo ELO daba deltas 0/0 y permitía
--      inflar estadísticas con llamadas repetidas). Nuevo: matches.elo_applied_at.
--   4. confirm_match ahora valida solapamiento con partidos confirmados,
--      bloqueos manuales del dueño y suspensiones de equipos.
--   5. Las transiciones de match_requests pasan a RPCs con validación de
--      estado/permisos (accept/reject/cancel/reject_by_owner) y se elimina
--      la política UPDATE permisiva que dejaba al cliente cambiar cualquier columna.
--   6. Las suspensiones ahora se hacen cumplir: crear/aceptar desafíos y
--      confirmar reservas falla si el usuario o el equipo están suspendidos.
--   7. Expiración automática de desafíos viejos (fecha pasada o bloqueo vencido).
--   8. Privacidad: phone, email y fcm_token de public.users dejan de ser
--      legibles por otros usuarios (grants por columna).
--
-- ROLLBACK:
--   -- Grants (restaurar comportamiento previo, NO recomendado):
--   GRANT EXECUTE ON FUNCTION public.issue_yellow_card(yellow_card_target, uuid, yellow_card_reason, uuid) TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.create_period_snapshot(ranking_period_type, date, date) TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.expire_unreported_matches() TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.lift_expired_suspensions() TO authenticated;
--   GRANT SELECT ON public.users TO authenticated;
--   -- Funciones nuevas:
--   DROP FUNCTION IF EXISTS public.accept_challenge(uuid);
--   DROP FUNCTION IF EXISTS public.reject_challenge(uuid);
--   DROP FUNCTION IF EXISTS public.cancel_challenge(uuid);
--   DROP FUNCTION IF EXISTS public.reject_match_by_owner(uuid);
--   ALTER TABLE public.matches DROP COLUMN IF EXISTS elo_applied_at;
--   -- Restaurar políticas y funciones desde 004/007/020/023.

-- ---------------------------------------------------------------------------
-- 1. Revocar EXECUTE de funciones privilegiadas
--    (el GRANT por defecto de Postgres incluye PUBLIC; se revoca todo y se
--    concede solo a service_role. Las llamadas internas vía PERFORM desde
--    funciones SECURITY DEFINER siguen funcionando porque se evalúan con los
--    privilegios del dueño de la función.)
-- ---------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.issue_yellow_card(yellow_card_target, uuid, yellow_card_reason, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.issue_yellow_card(yellow_card_target, uuid, yellow_card_reason, uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.create_period_snapshot(ranking_period_type, date, date) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.create_period_snapshot(ranking_period_type, date, date) TO service_role;

REVOKE EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.expire_unreported_matches() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.expire_unreported_matches() TO service_role;

REVOKE EXECUTE ON FUNCTION public.lift_expired_suspensions() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.lift_expired_suspensions() TO service_role;

REVOKE EXECUTE ON FUNCTION public.check_and_award_elo_medals(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.check_and_award_elo_medals(uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.check_and_award_team_achievements(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.check_and_award_team_achievements(uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.check_and_award_user_achievements(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.check_and_award_user_achievements(uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.auto_create_biweekly_snapshot() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.auto_create_monthly_snapshot()  FROM PUBLIC, anon, authenticated;

-- El tick de arranque de la app sigue disponible para usuarios autenticados
-- (es idempotente y solo avanza estados según el reloj), pero no para anon.
REVOKE EXECUTE ON FUNCTION public.mark_matches_awaiting_report() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. append_role seguro
--    La versión original se creó manualmente en el dashboard (no estaba en
--    migraciones) y no validaba caller ni rol. Esta versión solo permite que
--    el propio usuario se agregue el rol 'owner'.
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.append_role(uuid, text);
DROP FUNCTION IF EXISTS public.append_role(uuid, user_role);

CREATE OR REPLACE FUNCTION public.append_role(uid uuid, new_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF uid IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Solo puedes modificar tus propios roles';
  END IF;

  -- El único rol auto-asignable es 'owner' (al registrar una cancha).
  -- 'admin' solo se asigna manualmente con service_role.
  IF new_role <> 'owner' THEN
    RAISE EXCEPTION 'Rol no permitido: %', new_role;
  END IF;

  UPDATE public.users
  SET roles = array_append(roles, 'owner'::user_role)
  WHERE id = uid
    AND NOT ('owner'::user_role = ANY (roles));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.append_role(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.append_role(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Guard de idempotencia robusto para el cálculo de ELO
-- ---------------------------------------------------------------------------

ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS elo_applied_at timestamptz;

COMMENT ON COLUMN public.matches.elo_applied_at IS
  'Momento en que se aplicó el ELO/stats. Guard de idempotencia (los deltas 0/0 de un empate parejo no sirven como guard).';

-- Backfill: marcar como aplicados todos los partidos ya resueltos para que
-- una llamada posterior no duplique estadísticas históricas.
UPDATE public.matches
SET elo_applied_at = COALESCE(resolved_at, now())
WHERE status = 'resolved'
  AND elo_applied_at IS NULL;

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
  -- Lock de la fila para evitar doble aplicación concurrente
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;

  IF NOT FOUND THEN RETURN; END IF;
  IF v_match.status != 'resolved' THEN RETURN; END IF;
  IF v_match.final_result IS NULL THEN RETURN; END IF;

  -- Guard de idempotencia: si ya se aplicó, no recalcular
  IF v_match.elo_applied_at IS NOT NULL THEN RETURN; END IF;

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
      team_b_elo_change = v_delta_b,
      elo_applied_at    = now()
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

  -- Medallas ELO (022) y logros (023)
  PERFORM public.check_and_award_elo_medals(v_match.team_a_id);
  PERFORM public.check_and_award_elo_medals(v_match.team_b_id);
  PERFORM public.check_and_award_team_achievements(v_match.team_a_id);
  PERFORM public.check_and_award_team_achievements(v_match.team_b_id);
END;
$$;

-- (sin GRANT a authenticated: solo se invoca internamente desde
--  report_match_result / resolve_match_dispute, o con service_role)
REVOKE EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.calculate_and_apply_elo(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 4. confirm_match con validación de solapamientos y suspensiones
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

  -- Equipos suspendidos no pueden jugar partidos oficiales
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
    match_date, start_time, end_time, status
  ) VALUES (
    v_req.id, v_req.challenger_team_id, v_req.challenged_team_id, v_req.field_id,
    v_req.requested_date, v_req.requested_start_time, v_req.requested_end_time,
    'scheduled'
  )
  RETURNING id INTO v_match_id;

  RETURN v_match_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_match(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.confirm_match(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Transiciones de match_requests vía RPC (reemplaza UPDATEs directos)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.accept_challenge(p_match_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.match_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req FROM public.match_requests
  WHERE id = p_match_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  IF v_req.status <> 'pending_opponent' THEN
    RAISE EXCEPTION 'El desafío ya no está pendiente de respuesta (estado: %).', v_req.status;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = v_req.challenged_team_id AND captain_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el capitán del equipo desafiado puede aceptar.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_suspended) THEN
    RAISE EXCEPTION 'Tu cuenta está suspendida.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE id IN (v_req.challenger_team_id, v_req.challenged_team_id)
      AND is_suspended
  ) THEN
    RAISE EXCEPTION 'Uno de los equipos está suspendido.';
  END IF;

  -- El horario no debe estar tomado por otra reserva activa
  IF EXISTS (
    SELECT 1 FROM public.match_requests r
    WHERE r.field_id       = v_req.field_id
      AND r.requested_date = v_req.requested_date
      AND r.id            <> v_req.id
      AND (
        r.status = 'confirmed'
        OR (r.status = 'pending_owner' AND r.blocked_until > now())
      )
      AND r.requested_start_time < v_req.requested_end_time
      AND r.requested_end_time   > v_req.requested_start_time
  ) THEN
    RAISE EXCEPTION 'El horario ya está reservado o bloqueado temporalmente.';
  END IF;

  UPDATE public.match_requests
  SET status                = 'pending_owner',
      blocked_until         = now() + interval '45 minutes',
      opponent_responded_at = now()
  WHERE id = p_match_request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_challenge(p_match_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.match_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req FROM public.match_requests
  WHERE id = p_match_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  IF v_req.status <> 'pending_opponent' THEN
    RAISE EXCEPTION 'El desafío ya no está pendiente de respuesta (estado: %).', v_req.status;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = v_req.challenged_team_id AND captain_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el capitán del equipo desafiado puede rechazar.';
  END IF;

  UPDATE public.match_requests
  SET status                = 'rejected',
      opponent_responded_at = now()
  WHERE id = p_match_request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_challenge(p_match_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.match_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req FROM public.match_requests
  WHERE id = p_match_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  IF v_req.status NOT IN ('pending_opponent', 'pending_owner') THEN
    RAISE EXCEPTION 'El desafío ya no se puede cancelar (estado: %).', v_req.status;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = v_req.challenger_team_id AND captain_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el capitán que envió el desafío puede cancelarlo.';
  END IF;

  UPDATE public.match_requests
  SET status                  = 'cancelled',
      challenger_responded_at = now()
  WHERE id = p_match_request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_match_by_owner(p_match_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.match_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req FROM public.match_requests
  WHERE id = p_match_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  IF v_req.status <> 'pending_owner' THEN
    RAISE EXCEPTION 'La solicitud no está pendiente del dueño (estado: %).', v_req.status;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.fields
    WHERE id = v_req.field_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Solo el dueño de la cancha puede rechazar la reserva.';
  END IF;

  UPDATE public.match_requests
  SET status             = 'rejected',
      owner_responded_at = now()
  WHERE id = p_match_request_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_challenge(uuid)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reject_challenge(uuid)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cancel_challenge(uuid)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reject_match_by_owner(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.accept_challenge(uuid)      TO authenticated;
GRANT  EXECUTE ON FUNCTION public.reject_challenge(uuid)      TO authenticated;
GRANT  EXECUTE ON FUNCTION public.cancel_challenge(uuid)      TO authenticated;
GRANT  EXECUTE ON FUNCTION public.reject_match_by_owner(uuid) TO authenticated;

-- El cliente ya no necesita (ni debe) actualizar match_requests directamente
DROP POLICY IF EXISTS "involucrados_actualizan_desafio" ON public.match_requests;

-- ---------------------------------------------------------------------------
-- 6. Crear desafíos: bloquear a usuarios/equipos suspendidos
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "capitan_crea_desafio" ON public.match_requests;
CREATE POLICY "capitan_crea_desafio"
  ON public.match_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_team_captain(challenger_team_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.is_suspended
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.teams t
      WHERE t.id = challenger_team_id AND t.is_suspended
    )
  );

-- ---------------------------------------------------------------------------
-- 7. Expiración de desafíos viejos en el tick de arranque
--    (un desafío pending_opponent que nunca se responde bloqueaba el slot
--    en la UI indefinidamente)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_matches_awaiting_report()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_marked  integer;
  v_expired integer;
BEGIN
  -- Levantar suspensiones vencidas
  PERFORM public.lift_expired_suspensions();

  -- Expirar desafíos cuya fecha/hora ya pasó sin completar el flujo
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

  -- Marcar partidos cuya hora ya pasó
  UPDATE public.matches
  SET status = 'awaiting_report'
  WHERE status = 'scheduled'
    AND (match_date::timestamp + start_time)::timestamptz
        AT TIME ZONE 'America/Guayaquil' < NOW();

  GET DIAGNOSTICS v_marked = ROW_COUNT;

  -- Expirar los que superaron las 24h de ventana de reporte
  SELECT public.expire_unreported_matches() INTO v_expired;

  RETURN v_marked + v_expired;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_matches_awaiting_report() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;

-- ---------------------------------------------------------------------------
-- 8. Privacidad de public.users: ocultar phone, email y fcm_token
--    Se revoca el SELECT a nivel de tabla y se concede solo sobre columnas
--    públicas. La app obtiene el propio teléfono desde auth.currentUser.
--    (RLS sigue activo: las políticas de filas no cambian.)
-- ---------------------------------------------------------------------------

REVOKE SELECT ON public.users FROM anon;
REVOKE SELECT ON public.users FROM authenticated;

GRANT SELECT (
  id,
  full_name,
  username,
  avatar_url,
  created_at,
  is_suspended,
  suspension_until,
  suspension_level,
  yellow_cards_count,
  roles
) ON public.users TO authenticated;
