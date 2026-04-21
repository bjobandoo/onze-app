-- Migration: 024_field_reviews_trigger.sql
-- 1. Añade columna updated_at a field_reviews.
-- 2. Función + trigger que recalcula fields.average_rating en
--    INSERT / UPDATE / DELETE de field_reviews.
--
-- ROLLBACK:
--   DROP TRIGGER  IF EXISTS trg_update_field_rating ON public.field_reviews;
--   DROP FUNCTION IF EXISTS public.update_field_average_rating();
--   ALTER TABLE public.field_reviews DROP COLUMN IF EXISTS updated_at;

-- ---------------------------------------------------------------------------
-- 1. updated_at
-- ---------------------------------------------------------------------------

ALTER TABLE public.field_reviews
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. Función que recalcula el promedio
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_field_average_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_field_id uuid;
  v_avg      numeric;
BEGIN
  -- Para DELETE OLD contiene la fila; para INSERT/UPDATE NEW
  v_field_id := COALESCE(NEW.field_id, OLD.field_id);

  SELECT COALESCE(AVG(rating), 0)
  INTO   v_avg
  FROM   public.field_reviews
  WHERE  field_id = v_field_id;

  UPDATE public.fields
  SET    average_rating = ROUND(v_avg::numeric, 2)
  WHERE  id = v_field_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Trigger (INSERT + UPDATE + DELETE)
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_update_field_rating ON public.field_reviews;
CREATE TRIGGER trg_update_field_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.field_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_field_average_rating();

-- ---------------------------------------------------------------------------
-- 4. Backfill: recalcular promedios para reseñas ya existentes
-- ---------------------------------------------------------------------------

UPDATE public.fields f
SET average_rating = COALESCE(
  (SELECT ROUND(AVG(r.rating)::numeric, 2)
   FROM   public.field_reviews r
   WHERE  r.field_id = f.id),
  0
);
