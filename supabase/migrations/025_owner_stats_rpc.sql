-- Migration: 025_owner_stats_rpc.sql
-- Función get_owner_stats(p_owner_id) — retorna estadísticas de reservas,
-- ocupación e ingresos estimados para todas las canchas del dueño.
-- Resultados: totales históricos + ventanas de 7 y 30 días.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.get_owner_stats(uuid);

CREATE OR REPLACE FUNCTION public.get_owner_stats(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff_7d  date := (CURRENT_DATE - interval '7 days')::date;
  v_cutoff_30d date := (CURRENT_DATE - interval '30 days')::date;
  v_result     jsonb;
BEGIN
  -- Solo el propio dueño puede consultar sus estadísticas
  IF p_owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  WITH field_stats AS (
    SELECT
      f.id                                                      AS field_id,
      f.name                                                    AS field_name,
      f.average_rating,
      -- Reseñas
      (SELECT COUNT(*)
       FROM   public.field_reviews r
       WHERE  r.field_id = f.id)                               AS reviews_count,
      -- Reservas totales (excluye canceladas)
      COUNT(m.id)                                              AS total_matches,
      -- Reservas últimos 7 días
      COUNT(CASE WHEN m.match_date >= v_cutoff_7d  THEN 1 END) AS matches_7d,
      -- Reservas últimos 30 días
      COUNT(CASE WHEN m.match_date >= v_cutoff_30d THEN 1 END) AS matches_30d,
      -- Partidos completados (estado = resolved)
      COUNT(CASE WHEN m.status = 'resolved' THEN 1 END)        AS completed_matches,
      -- Ingresos estimados: precio del match_request asociado
      COALESCE(SUM(mr.price), 0)                               AS total_revenue,
      COALESCE(SUM(CASE WHEN m.match_date >= v_cutoff_7d
                        THEN mr.price ELSE 0 END), 0)          AS revenue_7d,
      COALESCE(SUM(CASE WHEN m.match_date >= v_cutoff_30d
                        THEN mr.price ELSE 0 END), 0)          AS revenue_30d
    FROM  public.fields f
    -- Partidos no cancelados de esta cancha
    LEFT JOIN public.matches m
      ON  m.field_id = f.id
      AND m.status  != 'cancelled'
    LEFT JOIN public.match_requests mr
      ON  mr.id = m.match_request_id
    WHERE f.owner_id = p_owner_id
    GROUP BY f.id, f.name, f.average_rating
  )
  SELECT jsonb_build_object(
    -- Resumen global
    'global', jsonb_build_object(
      'total_fields',      COUNT(*),
      'total_matches',     COALESCE(SUM(total_matches), 0),
      'matches_7d',        COALESCE(SUM(matches_7d), 0),
      'matches_30d',       COALESCE(SUM(matches_30d), 0),
      'completed_matches', COALESCE(SUM(completed_matches), 0),
      'total_revenue',     COALESCE(SUM(total_revenue), 0),
      'revenue_7d',        COALESCE(SUM(revenue_7d), 0),
      'revenue_30d',       COALESCE(SUM(revenue_30d), 0),
      'avg_rating',        ROUND(
        COALESCE(AVG(NULLIF(average_rating, 0)), 0)::numeric, 2
      )
    ),
    -- Detalle por cancha (ordenado por ingresos desc)
    'fields', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'field_id',          field_id,
          'field_name',        field_name,
          'average_rating',    average_rating,
          'reviews_count',     reviews_count,
          'total_matches',     total_matches,
          'matches_7d',        matches_7d,
          'matches_30d',       matches_30d,
          'completed_matches', completed_matches,
          'total_revenue',     total_revenue,
          'revenue_7d',        revenue_7d,
          'revenue_30d',       revenue_30d
        )
        ORDER BY total_revenue DESC
      ),
      '[]'::jsonb
    )
  )
  INTO v_result
  FROM field_stats;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_owner_stats(uuid) TO authenticated;
