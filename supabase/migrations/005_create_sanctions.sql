-- =============================================================================
-- Migración 005 — Sistema de sanciones: tarjetas y apelaciones
-- =============================================================================
-- ROLLBACK:
--   DROP TABLE IF EXISTS public.appeals;
--   DROP TABLE IF EXISTS public.yellow_cards;
--   DROP TYPE IF EXISTS appeal_resolution_status;
--   DROP TYPE IF EXISTS appeal_status;
--   DROP TYPE IF EXISTS yellow_card_reason;
--   DROP TYPE IF EXISTS yellow_card_target;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE yellow_card_target AS ENUM ('user', 'team');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE yellow_card_reason AS ENUM (
    'false_report', 'late_cancellation', 'no_report', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE appeal_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE appeal_resolution_status AS ENUM ('pending', 'upheld', 'revoked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tabla: yellow_cards
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.yellow_cards (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type       yellow_card_target NOT NULL,
  target_id         uuid NOT NULL,
  reason            yellow_card_reason NOT NULL,
  match_id          uuid REFERENCES public.matches(id) ON DELETE SET NULL,
  issued_at         timestamptz NOT NULL DEFAULT now(),
  appealed          boolean NOT NULL DEFAULT false,
  appeal_resolution appeal_resolution_status
);

COMMENT ON TABLE public.yellow_cards IS
  'Tarjetas amarillas emitidas a usuarios o equipos. Emitidas por Edge Functions.';
COMMENT ON COLUMN public.yellow_cards.target_id IS
  'UUID del usuario o equipo sancionado, según target_type.';

CREATE INDEX IF NOT EXISTS idx_yellow_cards_target    ON public.yellow_cards (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_yellow_cards_match_id  ON public.yellow_cards (match_id);
CREATE INDEX IF NOT EXISTS idx_yellow_cards_issued_at ON public.yellow_cards (issued_at DESC);

-- ---------------------------------------------------------------------------
-- Tabla: appeals
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.appeals (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  yellow_card_id uuid NOT NULL REFERENCES public.yellow_cards(id) ON DELETE CASCADE,
  submitted_by   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reason         text NOT NULL,
  evidence_urls  text[] NOT NULL DEFAULT '{}',
  status         appeal_status NOT NULL DEFAULT 'pending',
  admin_notes    text,
  resolved_by    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  resolved_at    timestamptz,
  CONSTRAINT uq_appeal_per_card UNIQUE (yellow_card_id)
);

COMMENT ON TABLE public.appeals IS
  'Apelaciones de tarjetas. Una tarjeta solo puede tener una apelación activa.';

CREATE INDEX IF NOT EXISTS idx_appeals_submitted_by   ON public.appeals (submitted_by);
CREATE INDEX IF NOT EXISTS idx_appeals_status         ON public.appeals (status);
CREATE INDEX IF NOT EXISTS idx_appeals_yellow_card_id ON public.appeals (yellow_card_id);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.yellow_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "usuario_ve_sus_tarjetas" ON public.yellow_cards;
CREATE POLICY "usuario_ve_sus_tarjetas"
  ON public.yellow_cards FOR SELECT
  TO authenticated
  USING (
    (target_type = 'user' AND target_id = auth.uid())
    OR (
      target_type = 'team'
      AND public.is_team_captain(target_id)
    )
  );

DROP POLICY IF EXISTS "usuario_ve_su_apelacion" ON public.appeals;
CREATE POLICY "usuario_ve_su_apelacion"
  ON public.appeals FOR SELECT
  TO authenticated
  USING (submitted_by = auth.uid());

DROP POLICY IF EXISTS "usuario_crea_apelacion" ON public.appeals;
CREATE POLICY "usuario_crea_apelacion"
  ON public.appeals FOR INSERT
  TO authenticated
  WITH CHECK (
    submitted_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.yellow_cards yc
      WHERE yc.id = yellow_card_id
        AND yc.appealed = false
        AND (
          (yc.target_type = 'user' AND yc.target_id = auth.uid())
          OR (yc.target_type = 'team' AND public.is_team_captain(yc.target_id))
        )
    )
  );
