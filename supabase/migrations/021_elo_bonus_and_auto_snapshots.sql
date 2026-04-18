-- Migration: 021_elo_bonus_and_auto_snapshots.sql
-- 1. Actualiza create_period_snapshot para usar stats reales del periodo
--    y aplicar bonus de volumen: elo_at_period = elo_actual + (partidos * 2).
-- 2. Funciones auxiliares para auto-snapshot quincenal y mensual.
-- 3. Cron jobs via pg_cron (se ignoran silenciosamente si no está disponible).
--
-- ROLLBACK:
--   Restaurar versión anterior de create_period_snapshot desde 018.
--   SELECT cron.unschedule('onze-biweekly-snapshot');
--   SELECT cron.unschedule('onze-monthly-snapshot');

-- ---------------------------------------------------------------------------
-- 1. create_period_snapshot actualizada con stats reales + bonus de volumen
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_period_snapshot(
  p_period_type  ranking_period_type,
  p_period_start date,
  p_period_end   date
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rank          integer := 0;
  v_row           record;
  v_matches       integer;
  v_wins          integer;
  v_elo_at_period integer;
BEGIN
  -- Borrar snapshot previo del mismo periodo si existe
  DELETE FROM public.ranking_snapshots
  WHERE period_type = p_period_type AND period_start = p_period_start;

  -- Iterar equipos ordenados por ELO_periodo (ELO actual + bonus de volumen)
  -- El bonus premia actividad sin alterar el ELO global permanente.
  FOR v_row IN
    SELECT
      t.id,
      t.elo_rating,
      -- Partidos del periodo (resueltos)
      (SELECT COUNT(*)
       FROM public.matches m
       WHERE (m.team_a_id = t.id OR m.team_b_id = t.id)
         AND m.status = 'resolved'
         AND m.match_date BETWEEN p_period_start AND p_period_end
      ) AS matches_cnt
    FROM public.teams t
    ORDER BY (
      t.elo_rating +
      (SELECT COUNT(*) * 2
       FROM public.matches m
       WHERE (m.team_a_id = t.id OR m.team_b_id = t.id)
         AND m.status = 'resolved'
         AND m.match_date BETWEEN p_period_start AND p_period_end
      )
    ) DESC
  LOOP
    v_rank := v_rank + 1;

    v_matches := v_row.matches_cnt;

    -- Victorias del equipo en el periodo
    SELECT COUNT(*) INTO v_wins
    FROM public.matches
    WHERE status = 'resolved'
      AND match_date BETWEEN p_period_start AND p_period_end
      AND (
        (team_a_id = v_row.id AND final_result = 'team_a_win')
        OR (team_b_id = v_row.id AND final_result = 'team_b_win')
      );

    -- ELO del periodo = ELO actual + bonus de actividad
    v_elo_at_period := v_row.elo_rating + (v_matches * 2);

    INSERT INTO public.ranking_snapshots (
      period_type, period_start, period_end,
      team_id, elo_at_period,
      wins_in_period, matches_in_period, rank_position
    ) VALUES (
      p_period_type, p_period_start, p_period_end,
      v_row.id, v_elo_at_period,
      v_wins, v_matches, v_rank
    );
  END LOOP;

  RETURN v_rank;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_period_snapshot(ranking_period_type, date, date)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Función auxiliar: snapshot quincenal automático
--    Se llama el día 1 y 15 de cada mes.
--    - Día 1  → cierra periodo: del 15 al último día del mes anterior.
--    - Día 15 → cierra periodo: del 1 al 14 del mes en curso.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_biweekly_snapshot()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today        date := CURRENT_DATE;
  v_period_start date;
  v_period_end   date;
BEGIN
  IF EXTRACT(DAY FROM v_today) = 1 THEN
    -- Periodo: del 15 al último día del mes anterior
    v_period_end   := v_today - interval '1 day';
    v_period_start := date_trunc('month', v_period_end) + interval '14 days';
  ELSE
    -- Día 15 — periodo: del 1 al 14 del mes en curso
    v_period_start := date_trunc('month', v_today);
    v_period_end   := v_today - interval '1 day';
  END IF;

  PERFORM public.create_period_snapshot('biweekly', v_period_start, v_period_end);
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Función auxiliar: snapshot mensual automático
--    Se llama el día 1 de cada mes. Cierra el mes anterior.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_monthly_snapshot()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today        date := CURRENT_DATE;
  v_period_start date;
  v_period_end   date;
BEGIN
  v_period_end   := v_today - interval '1 day';              -- último día del mes anterior
  v_period_start := date_trunc('month', v_period_end);        -- primer día de ese mes
  PERFORM public.create_period_snapshot('monthly', v_period_start, v_period_end);
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Registrar cron jobs con pg_cron (falla silenciosamente si no disponible)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;

  -- Quincenal: días 1 y 15 de cada mes a medianoche
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'onze-biweekly-snapshot') THEN
    PERFORM cron.schedule(
      'onze-biweekly-snapshot',
      '0 0 1,15 * *',
      'SELECT public.auto_create_biweekly_snapshot()'
    );
  END IF;

  -- Mensual: día 1 de cada mes a medianoche
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'onze-monthly-snapshot') THEN
    PERFORM cron.schedule(
      'onze-monthly-snapshot',
      '0 0 1 * *',
      'SELECT public.auto_create_monthly_snapshot()'
    );
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron no disponible o error al registrar cron: %', SQLERRM;
END;
$$;
