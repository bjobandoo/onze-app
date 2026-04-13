-- =============================================================================
-- Migración 006 — Logros, recompensas, ranking y notificaciones
-- =============================================================================
-- ROLLBACK:
--   DROP TABLE IF EXISTS public.notifications;
--   DROP TABLE IF EXISTS public.ranking_snapshots;
--   DROP TABLE IF EXISTS public.rewards;
--   DROP TABLE IF EXISTS public.team_achievements;
--   DROP TABLE IF EXISTS public.user_achievements;
--   DROP TABLE IF EXISTS public.achievements;
--   DROP TYPE IF EXISTS ranking_period_type;
--   DROP TYPE IF EXISTS achievement_target_type;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE achievement_target_type AS ENUM ('user', 'team');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE ranking_period_type AS ENUM ('biweekly', 'monthly');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tabla: achievements
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.achievements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE,
  name        text NOT NULL,
  description text NOT NULL,
  icon_url    text,
  target_type achievement_target_type NOT NULL
);

COMMENT ON TABLE public.achievements IS
  'Catálogo de logros coleccionables disponibles en Onze.';
COMMENT ON COLUMN public.achievements.code IS
  'Identificador legible, ej: first_win, hat_trick, unbeaten_10.';

-- ---------------------------------------------------------------------------
-- Tabla: user_achievements
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_achievements (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  achievement_id uuid NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  unlocked_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_achievement UNIQUE (user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id        ON public.user_achievements (user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON public.user_achievements (achievement_id);

-- ---------------------------------------------------------------------------
-- Tabla: team_achievements
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.team_achievements (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id        uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  achievement_id uuid NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  unlocked_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_team_achievement UNIQUE (team_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_team_achievements_team_id        ON public.team_achievements (team_id);
CREATE INDEX IF NOT EXISTS idx_team_achievements_achievement_id ON public.team_achievements (achievement_id);

-- ---------------------------------------------------------------------------
-- Tabla: rewards
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.rewards (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL,
  description      text,
  partner_business text,
  discount_type    text,
  points_cost      integer NOT NULL CHECK (points_cost >= 0),
  active           boolean NOT NULL DEFAULT true,
  stock            integer CHECK (stock IS NULL OR stock >= 0)
);

COMMENT ON TABLE public.rewards IS
  'Recompensas ofrecidas por negocios asociados, canjeables por puntos de actividad.';
COMMENT ON COLUMN public.rewards.stock IS 'NULL = stock ilimitado.';

-- ---------------------------------------------------------------------------
-- Tabla: ranking_snapshots
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ranking_snapshots (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_type       ranking_period_type NOT NULL,
  period_start      date NOT NULL,
  period_end        date NOT NULL,
  team_id           uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  elo_at_period     integer NOT NULL,
  wins_in_period    integer NOT NULL DEFAULT 0 CHECK (wins_in_period >= 0),
  matches_in_period integer NOT NULL DEFAULT 0 CHECK (matches_in_period >= 0),
  rank_position     integer NOT NULL CHECK (rank_position >= 1),
  CONSTRAINT uq_ranking_snapshot UNIQUE (period_type, period_start, team_id),
  CONSTRAINT chk_period_dates CHECK (period_start < period_end)
);

COMMENT ON TABLE public.ranking_snapshots IS
  'Snapshots de ranking al cierre de cada periodo. Generados por Edge Function programada.';

CREATE INDEX IF NOT EXISTS idx_ranking_snapshots_period ON public.ranking_snapshots (period_type, period_start);
CREATE INDEX IF NOT EXISTS idx_ranking_snapshots_team   ON public.ranking_snapshots (team_id);
CREATE INDEX IF NOT EXISTS idx_ranking_snapshots_rank   ON public.ranking_snapshots (period_type, period_start, rank_position);

-- ---------------------------------------------------------------------------
-- Tabla: notifications
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type       text NOT NULL,
  title      text NOT NULL,
  body       text NOT NULL,
  data       jsonb NOT NULL DEFAULT '{}',
  read       boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notifications IS
  'Notificaciones en-app. Las push se envían vía FCM desde Edge Functions.';
COMMENT ON COLUMN public.notifications.type IS
  'Ej: match_request, match_confirmed, team_invitation, sanction, result_reported.';

CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read       ON public.notifications (user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications (created_at DESC);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranking_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "autenticados_ven_logros" ON public.achievements;
CREATE POLICY "autenticados_ven_logros"
  ON public.achievements FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "autenticados_ven_logros_usuario" ON public.user_achievements;
CREATE POLICY "autenticados_ven_logros_usuario"
  ON public.user_achievements FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "autenticados_ven_logros_equipo" ON public.team_achievements;
CREATE POLICY "autenticados_ven_logros_equipo"
  ON public.team_achievements FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "autenticados_ven_recompensas" ON public.rewards;
CREATE POLICY "autenticados_ven_recompensas"
  ON public.rewards FOR SELECT
  TO authenticated
  USING (active = true);

DROP POLICY IF EXISTS "autenticados_ven_ranking" ON public.ranking_snapshots;
CREATE POLICY "autenticados_ven_ranking"
  ON public.ranking_snapshots FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "usuario_ve_sus_notificaciones" ON public.notifications;
CREATE POLICY "usuario_ve_sus_notificaciones"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "usuario_marca_leida" ON public.notifications;
CREATE POLICY "usuario_marca_leida"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
