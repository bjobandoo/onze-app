-- Migration: 017_match_expiry.sql
-- Vence la ventana de 24h para reporte de resultados.
-- Lógica:
--   - Solo un capitán reportó → el partido pasa a 'disputed' para que el dueño resuelva
--   - Ningún capitán reportó  → el partido se cancela (sin cambio de ELO)
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.expire_unreported_matches();

CREATE OR REPLACE FUNCTION public.expire_unreported_matches()
RETURNS integer   -- nro de partidos procesados
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match   public.matches%ROWTYPE;
  v_count   integer := 0;
  v_deadline timestamptz;
BEGIN
  FOR v_match IN
    SELECT * FROM public.matches
    WHERE status = 'awaiting_report'
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Deadline = fin del partido + 24 h (timezone Ecuador UTC-5)
    v_deadline :=
      (v_match.match_date::timestamp + v_match.end_time)::timestamptz
      AT TIME ZONE 'America/Guayaquil'
      + interval '24 hours';

    IF NOW() > v_deadline THEN
      IF v_match.team_a_report IS NOT NULL AND v_match.team_b_report IS NULL THEN
        -- Solo team A reportó → disputa para que el dueño decida
        UPDATE public.matches SET status = 'disputed' WHERE id = v_match.id;

      ELSIF v_match.team_a_report IS NULL AND v_match.team_b_report IS NOT NULL THEN
        -- Solo team B reportó → disputa para que el dueño decida
        UPDATE public.matches SET status = 'disputed' WHERE id = v_match.id;

      ELSE
        -- Ninguno reportó → cancelado (sin ELO)
        UPDATE public.matches SET status = 'cancelled' WHERE id = v_match.id;
      END IF;

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expire_unreported_matches() TO authenticated;

-- ---------------------------------------------------------------------------
-- Actualizar mark_matches_awaiting_report para que también llame la expiración
-- (una sola llamada hace las dos cosas al abrir la app)
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
  -- 1. Marcar como awaiting_report los partidos cuya hora ya pasó
  UPDATE public.matches
  SET status = 'awaiting_report'
  WHERE status = 'scheduled'
    AND (match_date::timestamp + start_time)::timestamptz
        AT TIME ZONE 'America/Guayaquil' < NOW();

  GET DIAGNOSTICS v_marked = ROW_COUNT;

  -- 2. Expirar los que ya pasaron las 24h
  SELECT public.expire_unreported_matches() INTO v_expired;

  RETURN v_marked + v_expired;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_matches_awaiting_report() TO authenticated;
