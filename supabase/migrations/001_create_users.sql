-- =============================================================================
-- Migración 001 — Usuarios y perfiles
-- =============================================================================
-- ROLLBACK:
--   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
--   DROP FUNCTION IF EXISTS public.handle_new_user();
--   DROP TABLE IF EXISTS public.owner_profiles;
--   DROP TABLE IF EXISTS public.player_profiles;
--   DROP TABLE IF EXISTS public.users;
--   DROP TYPE IF EXISTS experience_level;
--   DROP TYPE IF EXISTS dominant_foot;
--   DROP TYPE IF EXISTS player_position;
--   DROP TYPE IF EXISTS user_role;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

CREATE TYPE user_role AS ENUM ('player', 'owner', 'admin');

CREATE TYPE player_position AS ENUM (
  'portero',
  'defensa',
  'mediocampista',
  'delantero'
);

CREATE TYPE dominant_foot AS ENUM ('izquierdo', 'derecho', 'ambidiestro');

CREATE TYPE experience_level AS ENUM ('principiante', 'intermedio', 'avanzado');

-- ---------------------------------------------------------------------------
-- Tabla: users
-- Extiende auth.users con datos del dominio.
-- ---------------------------------------------------------------------------

CREATE TABLE public.users (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone            text UNIQUE,
  email            text,
  full_name        text NOT NULL DEFAULT '',
  avatar_url       text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  is_suspended     boolean NOT NULL DEFAULT false,
  suspension_until timestamptz,
  suspension_level integer NOT NULL DEFAULT 0 CHECK (suspension_level BETWEEN 0 AND 3),
  yellow_cards_count integer NOT NULL DEFAULT 0 CHECK (yellow_cards_count BETWEEN 0 AND 3),
  roles            user_role[] NOT NULL DEFAULT ARRAY['player'::user_role]
);

COMMENT ON TABLE public.users IS 'Perfil público de cada usuario registrado en Onze.';
COMMENT ON COLUMN public.users.suspension_level IS '0=sin suspensión, 1=2 semanas, 2=2 meses, 3=permanente';
COMMENT ON COLUMN public.users.yellow_cards_count IS 'Se reinicia al llegar a 3 (que genera tarjeta roja automática)';

-- Índices
CREATE INDEX idx_users_phone ON public.users (phone);
CREATE INDEX idx_users_roles ON public.users USING GIN (roles);

-- ---------------------------------------------------------------------------
-- Tabla: player_profiles
-- Datos deportivos de jugadores.
-- ---------------------------------------------------------------------------

CREATE TABLE public.player_profiles (
  user_id          uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  position         player_position,
  dominant_foot    dominant_foot,
  experience_level experience_level,
  bio              text
);

COMMENT ON TABLE public.player_profiles IS 'Perfil deportivo del jugador.';

-- ---------------------------------------------------------------------------
-- Tabla: owner_profiles
-- Datos del dueño de cancha(s).
-- ---------------------------------------------------------------------------

CREATE TABLE public.owner_profiles (
  user_id       uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  business_name text NOT NULL,
  id_document   text NOT NULL,
  verified      boolean NOT NULL DEFAULT false,
  verified_at   timestamptz
);

COMMENT ON TABLE public.owner_profiles IS 'Perfil del dueño de canchas sintéticas.';

-- ---------------------------------------------------------------------------
-- Trigger: crear fila en public.users al registrarse con Supabase Auth
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

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_profiles ENABLE ROW LEVEL SECURITY;

-- users: cualquier usuario autenticado puede leer perfiles (para búsqueda de jugadores)
CREATE POLICY "usuarios_autenticados_pueden_leer"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

-- users: solo el propio usuario puede actualizar su fila
CREATE POLICY "usuario_actualiza_propio_perfil"
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- player_profiles: lectura pública para autenticados
CREATE POLICY "autenticados_leen_perfiles_jugadores"
  ON public.player_profiles FOR SELECT
  TO authenticated
  USING (true);

-- player_profiles: el usuario crea y actualiza su propio perfil
CREATE POLICY "jugador_gestiona_su_perfil"
  ON public.player_profiles FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- owner_profiles: lectura pública para autenticados
CREATE POLICY "autenticados_leen_perfiles_duenos"
  ON public.owner_profiles FOR SELECT
  TO authenticated
  USING (true);

-- owner_profiles: el usuario gestiona su propio perfil de dueño
CREATE POLICY "dueno_gestiona_su_perfil"
  ON public.owner_profiles FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
