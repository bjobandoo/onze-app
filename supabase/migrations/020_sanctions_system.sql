-- Migration: 020_sanctions_system.sql
-- Sistema de sanciones: tarjetas amarillas → rojas → suspensiones.
--
-- Lógica de escalada:
--   3 amarillas → tarjeta roja → suspensión
--   Nivel 1 (1ª roja):  2 semanas
--   Nivel 2 (2ª roja):  2 meses
--   Nivel 3 (3ª roja):  permanente (suspension_until = NULL)
--   yellow_cards_count se reinicia a 0 tras cada roja.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.issue_yellow_card(yellow_card_target,uuid,yellow_card_reason,uuid);
--   DROP FUNCTION IF EXISTS public.lift_expired_suspensions();

-- ---------------------------------------------------------------------------
-- 1. Emitir tarjeta amarilla con auto-escalada a suspensión
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_yellow_card(
  p_target_type yellow_card_target,
  p_target_id   uuid,
  p_reason      yellow_card_reason,
  p_match_id    uuid DEFAULT NULL
)
RETURNS uuid   -- ID de la tarjeta creada
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card_id      uuid;
  v_current_cnt  integer;
  v_next_level   integer;
  v_suspend_until timestamptz;
BEGIN
  -- Insertar tarjeta
  INSERT INTO public.yellow_cards (target_type, target_id, reason, match_id)
  VALUES (p_target_type, p_target_id, p_reason, p_match_id)
  RETURNING id INTO v_card_id;

  IF p_target_type = 'user' THEN
    SELECT yellow_cards_count INTO v_current_cnt
    FROM public.users WHERE id = p_target_id;

    IF v_current_cnt + 1 >= 3 THEN
      -- Tarjeta roja → suspensión
      SELECT LEAST(suspension_level + 1, 3) INTO v_next_level
      FROM public.users WHERE id = p_target_id;

      v_suspend_until := CASE v_next_level
        WHEN 1 THEN NOW() + interval '14 days'
        WHEN 2 THEN NOW() + interval '60 days'
        ELSE NULL   -- nivel 3 = permanente
      END;

      UPDATE public.users SET
        yellow_cards_count = 0,
        is_suspended       = true,
        suspension_until   = v_suspend_until,
        suspension_level   = v_next_level
      WHERE id = p_target_id;
    ELSE
      UPDATE public.users SET yellow_cards_count = yellow_cards_count + 1
      WHERE id = p_target_id;
    END IF;

  ELSE  -- 'team'
    SELECT yellow_cards_count INTO v_current_cnt
    FROM public.teams WHERE id = p_target_id;

    IF v_current_cnt + 1 >= 3 THEN
      SELECT LEAST(suspension_level + 1, 3) INTO v_next_level
      FROM public.teams WHERE id = p_target_id;

      v_suspend_until := CASE v_next_level
        WHEN 1 THEN NOW() + interval '14 days'
        WHEN 2 THEN NOW() + interval '60 days'
        ELSE NULL
      END;

      UPDATE public.teams SET
        yellow_cards_count = 0,
        is_suspended       = true,
        suspension_until   = v_suspend_until,
        suspension_level   = v_next_level
      WHERE id = p_target_id;
    ELSE
      UPDATE public.teams SET yellow_cards_count = yellow_cards_count + 1
      WHERE id = p_target_id;
    END IF;
  END IF;

  RETURN v_card_id;
END;
$$;

GRANT EXECUTE ON FUNCTION
  public.issue_yellow_card(yellow_card_target, uuid, yellow_card_reason, uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Levantar suspensiones temporales expiradas
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lift_expired_suspensions()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.users
  SET is_suspended = false
  WHERE is_suspended = true
    AND suspension_until IS NOT NULL
    AND suspension_until < NOW();

  UPDATE public.teams
  SET is_suspended = false
  WHERE is_suspended = true
    AND suspension_until IS NOT NULL
    AND suspension_until < NOW();
$$;

GRANT EXECUTE ON FUNCTION public.lift_expired_suspensions() TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Actualizar expire_unreported_matches para emitir tarjetas no_report
--    Solo cuando NINGÚN capitán reportó (ambos son negligentes).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_unreported_matches()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match   public.matches%ROWTYPE;
  v_count   integer := 0;
  v_deadline timestamptz;
  v_cap_a   uuid;
  v_cap_b   uuid;
BEGIN
  FOR v_match IN
    SELECT * FROM public.matches
    WHERE status = 'awaiting_report'
    FOR UPDATE SKIP LOCKED
  LOOP
    v_deadline :=
      (v_match.match_date::timestamp + v_match.end_time)::timestamptz
      AT TIME ZONE 'America/Guayaquil'
      + interval '24 hours';

    IF NOW() > v_deadline THEN
      IF v_match.team_a_report IS NOT NULL AND v_match.team_b_report IS NULL THEN
        -- Solo A reportó → disputa; tarjeta al capitán de B por no reportar
        UPDATE public.matches SET status = 'disputed' WHERE id = v_match.id;

        SELECT captain_id INTO v_cap_b FROM public.teams WHERE id = v_match.team_b_id;
        IF v_cap_b IS NOT NULL THEN
          PERFORM public.issue_yellow_card('user', v_cap_b, 'no_report', v_match.id);
          PERFORM public.issue_yellow_card('team', v_match.team_b_id, 'no_report', v_match.id);
        END IF;

      ELSIF v_match.team_a_report IS NULL AND v_match.team_b_report IS NOT NULL THEN
        -- Solo B reportó → disputa; tarjeta al capitán de A
        UPDATE public.matches SET status = 'disputed' WHERE id = v_match.id;

        SELECT captain_id INTO v_cap_a FROM public.teams WHERE id = v_match.team_a_id;
        IF v_cap_a IS NOT NULL THEN
          PERFORM public.issue_yellow_card('user', v_cap_a, 'no_report', v_match.id);
          PERFORM public.issue_yellow_card('team', v_match.team_a_id, 'no_report', v_match.id);
        END IF;

      ELSE
        -- Ninguno reportó → cancelado; tarjeta a ambos capitanes y equipos
        UPDATE public.matches SET status = 'cancelled' WHERE id = v_match.id;

        SELECT captain_id INTO v_cap_a FROM public.teams WHERE id = v_match.team_a_id;
        SELECT captain_id INTO v_cap_b FROM public.teams WHERE id = v_match.team_b_id;

        IF v_cap_a IS NOT NULL THEN
          PERFORM public.issue_yellow_card('user', v_cap_a, 'no_report', v_match.id);
          PERFORM public.issue_yellow_card('team', v_match.team_a_id, 'no_report', v_match.id);
        END IF;
        IF v_cap_b IS NOT NULL THEN
          PERFORM public.issue_yellow_card('user', v_cap_b, 'no_report', v_match.id);
          PERFORM public.issue_yellow_card('team', v_match.team_b_id, 'no_report', v_match.id);
        END IF;
      END IF;

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expire_unreported_matches() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Integrar lift_expired_suspensions en el tick de arranque de la app
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

  -- Marcar partidos cuya hora ya pasó
  UPDATE public.matches
  SET status = 'awaiting_report'
  WHERE status = 'scheduled'
    AND (match_date::timestamp + start_time)::timestamptz
        AT TIME ZONE 'America/Guayaquil' < NOW();

  GET DIAGNOSTICS v_marked = ROW_COUNT;

  -- Expirar los que superaron las 24h
  SELECT public.expire_unreported_matches() INTO v_expired;

  RETURN v_marked + v_expired;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. RLS adicional: permitir a SECURITY DEFINER functions escribir en yellow_cards
--    (ya son SECURITY DEFINER, así que no necesitan política de INSERT propia)
-- ---------------------------------------------------------------------------
-- La tabla yellow_cards no tiene política INSERT para 'authenticated' en 005.
-- Las funciones SECURITY DEFINER omiten RLS, por lo que ya funciona.
-- No se necesita cambio.
