-- =============================================================================
-- Migración 003 — Equipos, miembros y solicitudes de unión
-- =============================================================================
-- ROLLBACK:
--   DROP TABLE IF EXISTS public.team_join_requests;
--   DROP TABLE IF EXISTS public.team_members;
--   DROP TABLE IF EXISTS public.teams;
--   DROP TYPE IF EXISTS join_request_status;
--   DROP TYPE IF EXISTS join_request_type;
--   DROP TYPE IF EXISTS team_member_role;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE team_member_role AS ENUM ('captain', 'member');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE join_request_type AS ENUM ('invitation', 'request');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE join_request_status AS ENUM ('pending', 'accepted', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tabla: teams
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.teams (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL,
  crest_url        text,
  description      text,
  captain_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_by       uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at       timestamptz NOT NULL DEFAULT now(),
  elo_rating       integer NOT NULL DEFAULT 1000 CHECK (elo_rating >= 0),
  is_suspended     boolean NOT NULL DEFAULT false,
  suspension_until timestamptz,
  suspension_level integer NOT NULL DEFAULT 0 CHECK (suspension_level BETWEEN 0 AND 3),
  yellow_cards_count integer NOT NULL DEFAULT 0 CHECK (yellow_cards_count BETWEEN 0 AND 3),
  wins             integer NOT NULL DEFAULT 0 CHECK (wins >= 0),
  losses           integer NOT NULL DEFAULT 0 CHECK (losses >= 0),
  draws            integer NOT NULL DEFAULT 0 CHECK (draws >= 0),
  matches_played   integer NOT NULL DEFAULT 0 CHECK (matches_played >= 0)
);

COMMENT ON TABLE public.teams IS 'Equipos de fútbol amateur registrados en Onze.';
COMMENT ON COLUMN public.teams.elo_rating IS 'Puntuación ELO global del equipo. Inicia en 1000.';

CREATE INDEX IF NOT EXISTS idx_teams_captain_id   ON public.teams (captain_id);
CREATE INDEX IF NOT EXISTS idx_teams_elo_rating   ON public.teams (elo_rating DESC);
CREATE INDEX IF NOT EXISTS idx_teams_is_suspended ON public.teams (is_suspended);

-- ---------------------------------------------------------------------------
-- Tabla: team_members
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.team_members (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id   uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  role      team_member_role NOT NULL DEFAULT 'member',
  CONSTRAINT uq_team_member UNIQUE (team_id, user_id)
);

COMMENT ON TABLE public.team_members IS 'Miembros de cada equipo.';

CREATE INDEX IF NOT EXISTS idx_team_members_team_id ON public.team_members (team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user_id ON public.team_members (user_id);

-- ---------------------------------------------------------------------------
-- Tabla: team_join_requests
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.team_join_requests (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id    uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type       join_request_type NOT NULL,
  status     join_request_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_join_request UNIQUE (team_id, user_id, type)
);

COMMENT ON TABLE public.team_join_requests IS
  'Solicitudes de unión (type=request) e invitaciones (type=invitation).';

CREATE INDEX IF NOT EXISTS idx_join_requests_team_id ON public.team_join_requests (team_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_user_id ON public.team_join_requests (user_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_status  ON public.team_join_requests (status);

-- ---------------------------------------------------------------------------
-- Funciones auxiliares de RLS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_team_captain(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id AND captain_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_team_member(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_join_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "autenticados_ven_equipos" ON public.teams;
CREATE POLICY "autenticados_ven_equipos"
  ON public.teams FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "autenticado_crea_equipo" ON public.teams;
CREATE POLICY "autenticado_crea_equipo"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (
    captain_id = auth.uid()
    AND created_by = auth.uid()
    AND (
      SELECT COUNT(*) FROM public.teams WHERE captain_id = auth.uid()
    ) < 2
  );

DROP POLICY IF EXISTS "capitan_actualiza_equipo" ON public.teams;
CREATE POLICY "capitan_actualiza_equipo"
  ON public.teams FOR UPDATE
  TO authenticated
  USING (captain_id = auth.uid())
  WITH CHECK (captain_id = auth.uid());

DROP POLICY IF EXISTS "autenticados_ven_miembros" ON public.team_members;
CREATE POLICY "autenticados_ven_miembros"
  ON public.team_members FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "capitan_agrega_miembro" ON public.team_members;
CREATE POLICY "capitan_agrega_miembro"
  ON public.team_members FOR INSERT
  TO authenticated
  WITH CHECK (public.is_team_captain(team_id));

DROP POLICY IF EXISTS "capitan_o_miembro_borra_membresia" ON public.team_members;
CREATE POLICY "capitan_o_miembro_borra_membresia"
  ON public.team_members FOR DELETE
  TO authenticated
  USING (
    public.is_team_captain(team_id) OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "usuario_o_capitan_ven_solicitudes" ON public.team_join_requests;
CREATE POLICY "usuario_o_capitan_ven_solicitudes"
  ON public.team_join_requests FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_team_captain(team_id)
  );

DROP POLICY IF EXISTS "usuario_envia_solicitud" ON public.team_join_requests;
CREATE POLICY "usuario_envia_solicitud"
  ON public.team_join_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    (type = 'request' AND user_id = auth.uid())
    OR (type = 'invitation' AND public.is_team_captain(team_id))
  );

DROP POLICY IF EXISTS "actualizar_solicitud" ON public.team_join_requests;
CREATE POLICY "actualizar_solicitud"
  ON public.team_join_requests FOR UPDATE
  TO authenticated
  USING (
    (type = 'invitation' AND user_id = auth.uid())
    OR (type = 'request' AND public.is_team_captain(team_id))
  );
