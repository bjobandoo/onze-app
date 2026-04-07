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

CREATE TYPE team_member_role AS ENUM ('captain', 'member');

CREATE TYPE join_request_type AS ENUM ('invitation', 'request');

CREATE TYPE join_request_status AS ENUM ('pending', 'accepted', 'rejected');

-- ---------------------------------------------------------------------------
-- Tabla: teams
-- ---------------------------------------------------------------------------

CREATE TABLE public.teams (
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

-- Índices
CREATE INDEX idx_teams_captain_id   ON public.teams (captain_id);
CREATE INDEX idx_teams_elo_rating   ON public.teams (elo_rating DESC);
CREATE INDEX idx_teams_is_suspended ON public.teams (is_suspended);

-- ---------------------------------------------------------------------------
-- Tabla: team_members
-- ---------------------------------------------------------------------------

CREATE TABLE public.team_members (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id   uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  role      team_member_role NOT NULL DEFAULT 'member',
  CONSTRAINT uq_team_member UNIQUE (team_id, user_id)
);

COMMENT ON TABLE public.team_members IS 'Miembros de cada equipo.';

-- Índices
CREATE INDEX idx_team_members_team_id ON public.team_members (team_id);
CREATE INDEX idx_team_members_user_id ON public.team_members (user_id);

-- ---------------------------------------------------------------------------
-- Tabla: team_join_requests
-- Solicitudes de unión e invitaciones (bidireccional).
-- ---------------------------------------------------------------------------

CREATE TABLE public.team_join_requests (
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

-- Índices
CREATE INDEX idx_join_requests_team_id ON public.team_join_requests (team_id);
CREATE INDEX idx_join_requests_user_id ON public.team_join_requests (user_id);
CREATE INDEX idx_join_requests_status  ON public.team_join_requests (status);

-- ---------------------------------------------------------------------------
-- Función auxiliar de RLS: verificar si el usuario es capitán de un equipo
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

-- Función auxiliar: verificar si el usuario pertenece a un equipo
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

-- teams: cualquier autenticado puede ver equipos
CREATE POLICY "autenticados_ven_equipos"
  ON public.teams FOR SELECT
  TO authenticated
  USING (true);

-- teams: cualquier autenticado puede crear un equipo
CREATE POLICY "autenticado_crea_equipo"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (
    captain_id = auth.uid()
    AND created_by = auth.uid()
    -- Límite: máx 2 equipos como capitán
    AND (
      SELECT COUNT(*) FROM public.teams WHERE captain_id = auth.uid()
    ) < 2
  );

-- teams: solo el capitán puede actualizar su equipo
CREATE POLICY "capitan_actualiza_equipo"
  ON public.teams FOR UPDATE
  TO authenticated
  USING (captain_id = auth.uid())
  WITH CHECK (captain_id = auth.uid());

-- team_members: cualquier autenticado puede ver miembros
CREATE POLICY "autenticados_ven_miembros"
  ON public.team_members FOR SELECT
  TO authenticated
  USING (true);

-- team_members: el capitán puede agregar miembros a su equipo
CREATE POLICY "capitan_agrega_miembro"
  ON public.team_members FOR INSERT
  TO authenticated
  WITH CHECK (public.is_team_captain(team_id));

-- team_members: el capitán puede expulsar miembros; el miembro puede salir
CREATE POLICY "capitan_o_miembro_borra_membresia"
  ON public.team_members FOR DELETE
  TO authenticated
  USING (
    public.is_team_captain(team_id) OR user_id = auth.uid()
  );

-- team_join_requests: el usuario ve sus propias solicitudes e invitaciones
--                     y el capitán ve las de su equipo
CREATE POLICY "usuario_o_capitan_ven_solicitudes"
  ON public.team_join_requests FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_team_captain(team_id)
  );

-- team_join_requests: un usuario puede enviar solicitud de unión
CREATE POLICY "usuario_envia_solicitud"
  ON public.team_join_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    (type = 'request' AND user_id = auth.uid())
    OR (type = 'invitation' AND public.is_team_captain(team_id))
  );

-- team_join_requests: el capitán actualiza invitaciones; el usuario actualiza solicitudes propias
CREATE POLICY "actualizar_solicitud"
  ON public.team_join_requests FOR UPDATE
  TO authenticated
  USING (
    (type = 'invitation' AND user_id = auth.uid())
    OR (type = 'request' AND public.is_team_captain(team_id))
  );
