-- =============================================================================
-- Migración 004 — Solicitudes de partido, partidos y estadísticas individuales
-- =============================================================================
-- ROLLBACK:
--   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
--   DROP FUNCTION IF EXISTS public.handle_new_user();
--   DROP TABLE IF EXISTS public.individual_stats;
--   DROP TABLE IF EXISTS public.matches;
--   DROP TABLE IF EXISTS public.match_requests;
--   DROP TYPE IF EXISTS match_final_result;
--   DROP TYPE IF EXISTS owner_resolution_type;
--   DROP TYPE IF EXISTS match_report;
--   DROP TYPE IF EXISTS match_status;
--   DROP TYPE IF EXISTS match_request_status;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE match_request_status AS ENUM (
    'pending_opponent', 'pending_owner', 'confirmed',
    'rejected', 'expired', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE match_status AS ENUM (
    'scheduled', 'awaiting_report', 'disputed', 'resolved', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE match_report AS ENUM ('win', 'loss', 'draw');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE owner_resolution_type AS ENUM ('team_a_win', 'team_b_win', 'draw');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE match_final_result AS ENUM ('team_a_win', 'team_b_win', 'draw');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tabla: match_requests
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.match_requests (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_team_id      uuid NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  challenged_team_id      uuid NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  field_id                uuid NOT NULL REFERENCES public.fields(id) ON DELETE RESTRICT,
  requested_date          date NOT NULL,
  requested_start_time    time NOT NULL,
  requested_end_time      time NOT NULL,
  price                   decimal(10, 2) NOT NULL CHECK (price >= 0),
  status                  match_request_status NOT NULL DEFAULT 'pending_opponent',
  challenger_responded_at timestamptz,
  opponent_responded_at   timestamptz,
  owner_responded_at      timestamptz,
  blocked_until           timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_match_request_times CHECK (requested_start_time < requested_end_time),
  CONSTRAINT chk_different_teams CHECK (challenger_team_id <> challenged_team_id)
);

COMMENT ON TABLE public.match_requests IS
  'Desafíos enviados entre equipos. El flujo es: pending_opponent → pending_owner → confirmed.';
COMMENT ON COLUMN public.match_requests.blocked_until IS
  'Cuando pasa a pending_owner, el horario se bloquea 45 minutos mientras el dueño confirma.';

CREATE INDEX IF NOT EXISTS idx_match_requests_challenger ON public.match_requests (challenger_team_id);
CREATE INDEX IF NOT EXISTS idx_match_requests_challenged ON public.match_requests (challenged_team_id);
CREATE INDEX IF NOT EXISTS idx_match_requests_field_id   ON public.match_requests (field_id);
CREATE INDEX IF NOT EXISTS idx_match_requests_status     ON public.match_requests (status);
CREATE INDEX IF NOT EXISTS idx_match_requests_date       ON public.match_requests (requested_date);

-- ---------------------------------------------------------------------------
-- Tabla: matches
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.matches (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_request_id uuid NOT NULL REFERENCES public.match_requests(id) ON DELETE RESTRICT,
  team_a_id        uuid NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  team_b_id        uuid NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  field_id         uuid NOT NULL REFERENCES public.fields(id) ON DELETE RESTRICT,
  match_date       date NOT NULL,
  start_time       time NOT NULL,
  end_time         time NOT NULL,
  status           match_status NOT NULL DEFAULT 'scheduled',
  team_a_report    match_report,
  team_b_report    match_report,
  owner_resolution owner_resolution_type,
  final_result     match_final_result,
  team_a_elo_change integer NOT NULL DEFAULT 0,
  team_b_elo_change integer NOT NULL DEFAULT 0,
  reported_at      timestamptz,
  resolved_at      timestamptz,
  CONSTRAINT chk_match_times CHECK (start_time < end_time),
  CONSTRAINT chk_different_match_teams CHECK (team_a_id <> team_b_id)
);

COMMENT ON TABLE public.matches IS
  'Partidos oficiales. Solo estos cuentan para ELO y estadísticas.';

CREATE INDEX IF NOT EXISTS idx_matches_team_a_id        ON public.matches (team_a_id);
CREATE INDEX IF NOT EXISTS idx_matches_team_b_id        ON public.matches (team_b_id);
CREATE INDEX IF NOT EXISTS idx_matches_field_id         ON public.matches (field_id);
CREATE INDEX IF NOT EXISTS idx_matches_status           ON public.matches (status);
CREATE INDEX IF NOT EXISTS idx_matches_match_date       ON public.matches (match_date);
CREATE INDEX IF NOT EXISTS idx_matches_match_request_id ON public.matches (match_request_id);

-- ---------------------------------------------------------------------------
-- Tabla: individual_stats
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.individual_stats (
  user_id        uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  wins           integer NOT NULL DEFAULT 0 CHECK (wins >= 0),
  losses         integer NOT NULL DEFAULT 0 CHECK (losses >= 0),
  draws          integer NOT NULL DEFAULT 0 CHECK (draws >= 0),
  matches_played integer NOT NULL DEFAULT 0 CHECK (matches_played >= 0)
);

COMMENT ON TABLE public.individual_stats IS
  'Estadísticas globales de cada jugador. Se actualiza vía Edge Function post-partido.';

-- ---------------------------------------------------------------------------
-- Actualizar handle_new_user para crear también las estadísticas
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, phone, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.phone,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    NEW.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.individual_stats (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- El trigger ya existe desde 001; al reemplazar la función el trigger lo usa automáticamente.

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.match_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.individual_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "involucrados_ven_desafio" ON public.match_requests;
CREATE POLICY "involucrados_ven_desafio"
  ON public.match_requests FOR SELECT
  TO authenticated
  USING (
    public.is_team_member(challenger_team_id)
    OR public.is_team_member(challenged_team_id)
    OR EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "capitan_crea_desafio" ON public.match_requests;
CREATE POLICY "capitan_crea_desafio"
  ON public.match_requests FOR INSERT
  TO authenticated
  WITH CHECK (public.is_team_captain(challenger_team_id));

DROP POLICY IF EXISTS "involucrados_actualizan_desafio" ON public.match_requests;
CREATE POLICY "involucrados_actualizan_desafio"
  ON public.match_requests FOR UPDATE
  TO authenticated
  USING (
    public.is_team_captain(challenger_team_id)
    OR public.is_team_captain(challenged_team_id)
    OR EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "autenticados_ven_partidos" ON public.matches;
CREATE POLICY "autenticados_ven_partidos"
  ON public.matches FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "capitan_reporta_resultado" ON public.matches;
CREATE POLICY "capitan_reporta_resultado"
  ON public.matches FOR UPDATE
  TO authenticated
  USING (
    public.is_team_captain(team_a_id)
    OR public.is_team_captain(team_b_id)
    OR EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "autenticados_ven_estadisticas" ON public.individual_stats;
CREATE POLICY "autenticados_ven_estadisticas"
  ON public.individual_stats FOR SELECT
  TO authenticated
  USING (true);
