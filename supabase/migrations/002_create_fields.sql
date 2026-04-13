-- =============================================================================
-- Migración 002 — Canchas, horarios y reseñas
-- =============================================================================
-- ROLLBACK:
--   DROP TABLE IF EXISTS public.field_reviews;
--   DROP TABLE IF EXISTS public.field_blocked_slots;
--   DROP TABLE IF EXISTS public.field_schedules;
--   DROP TABLE IF EXISTS public.fields;
--   DROP TYPE IF EXISTS field_type;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE field_type AS ENUM ('5v5', '6v6', '7v7', '8v8');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tabla: fields
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fields (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  name           text NOT NULL,
  description    text,
  address        text NOT NULL,
  latitude       decimal(9, 6) NOT NULL,
  longitude      decimal(9, 6) NOT NULL,
  photos         text[] NOT NULL DEFAULT '{}',
  field_type     field_type NOT NULL,
  is_active      boolean NOT NULL DEFAULT true,
  verified       boolean NOT NULL DEFAULT false,
  average_rating decimal(3, 2) NOT NULL DEFAULT 0.0 CHECK (average_rating BETWEEN 0 AND 5),
  created_at     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.fields IS 'Canchas sintéticas registradas en Onze. Requieren validación del admin.';

CREATE INDEX IF NOT EXISTS idx_fields_owner_id  ON public.fields (owner_id);
CREATE INDEX IF NOT EXISTS idx_fields_is_active ON public.fields (is_active);
CREATE INDEX IF NOT EXISTS idx_fields_verified  ON public.fields (verified);
CREATE INDEX IF NOT EXISTS idx_fields_location  ON public.fields (latitude, longitude);

-- ---------------------------------------------------------------------------
-- Tabla: field_schedules
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.field_schedules (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id     uuid NOT NULL REFERENCES public.fields(id) ON DELETE CASCADE,
  day_of_week  integer NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time   time NOT NULL,
  end_time     time NOT NULL,
  price        decimal(10, 2) NOT NULL CHECK (price >= 0),
  is_active    boolean NOT NULL DEFAULT true,
  CONSTRAINT chk_field_schedule_times CHECK (start_time < end_time)
);

COMMENT ON TABLE public.field_schedules IS 'Horarios recurrentes disponibles por día de la semana.';
COMMENT ON COLUMN public.field_schedules.day_of_week IS '0=domingo, 1=lunes, ..., 6=sábado';

CREATE INDEX IF NOT EXISTS idx_field_schedules_field_id ON public.field_schedules (field_id);
CREATE INDEX IF NOT EXISTS idx_field_schedules_day      ON public.field_schedules (field_id, day_of_week);

-- ---------------------------------------------------------------------------
-- Tabla: field_blocked_slots
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.field_blocked_slots (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id   uuid NOT NULL REFERENCES public.fields(id) ON DELETE CASCADE,
  date       date NOT NULL,
  start_time time NOT NULL,
  end_time   time NOT NULL,
  reason     text,
  CONSTRAINT chk_blocked_slot_times CHECK (start_time < end_time)
);

COMMENT ON TABLE public.field_blocked_slots IS 'Bloqueos manuales de horarios por el dueño de cancha.';

CREATE INDEX IF NOT EXISTS idx_blocked_slots_field_date ON public.field_blocked_slots (field_id, date);

-- ---------------------------------------------------------------------------
-- Tabla: field_reviews
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.field_reviews (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id   uuid NOT NULL REFERENCES public.fields(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rating     integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_field_review_user UNIQUE (field_id, user_id)
);

COMMENT ON TABLE public.field_reviews IS 'Reseñas de canchas. Un usuario puede reseñar una cancha una sola vez.';

CREATE INDEX IF NOT EXISTS idx_field_reviews_field_id ON public.field_reviews (field_id);
CREATE INDEX IF NOT EXISTS idx_field_reviews_user_id  ON public.field_reviews (user_id);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_blocked_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "autenticados_ven_canchas_activas" ON public.fields;
CREATE POLICY "autenticados_ven_canchas_activas"
  ON public.fields FOR SELECT
  TO authenticated
  USING (is_active = true AND verified = true);

DROP POLICY IF EXISTS "dueno_ve_sus_canchas" ON public.fields;
CREATE POLICY "dueno_ve_sus_canchas"
  ON public.fields FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "dueno_registra_cancha" ON public.fields;
CREATE POLICY "dueno_registra_cancha"
  ON public.fields FOR INSERT
  TO authenticated
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.owner_profiles WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "dueno_actualiza_su_cancha" ON public.fields;
CREATE POLICY "dueno_actualiza_su_cancha"
  ON public.fields FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "autenticados_ven_horarios" ON public.field_schedules;
CREATE POLICY "autenticados_ven_horarios"
  ON public.field_schedules FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "dueno_gestiona_horarios" ON public.field_schedules;
CREATE POLICY "dueno_gestiona_horarios"
  ON public.field_schedules FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "autenticados_ven_bloqueos" ON public.field_blocked_slots;
CREATE POLICY "autenticados_ven_bloqueos"
  ON public.field_blocked_slots FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "dueno_gestiona_bloqueos" ON public.field_blocked_slots;
CREATE POLICY "dueno_gestiona_bloqueos"
  ON public.field_blocked_slots FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "autenticados_ven_resenas" ON public.field_reviews;
CREATE POLICY "autenticados_ven_resenas"
  ON public.field_reviews FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "usuario_crea_resena" ON public.field_reviews;
CREATE POLICY "usuario_crea_resena"
  ON public.field_reviews FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "usuario_actualiza_su_resena" ON public.field_reviews;
CREATE POLICY "usuario_actualiza_su_resena"
  ON public.field_reviews FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "usuario_borra_su_resena" ON public.field_reviews;
CREATE POLICY "usuario_borra_su_resena"
  ON public.field_reviews FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
