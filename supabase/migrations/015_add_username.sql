-- Migration: 015_add_username.sql
-- Agrega campo username único por jugador, usado para búsqueda y mención.
-- El usuario lo elige al crear su perfil (tras verificar teléfono).
--
-- ROLLBACK:
--   ALTER TABLE public.users DROP COLUMN IF EXISTS username;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS username text;

-- Solo minúsculas, dígitos y guión bajo, entre 3 y 20 caracteres.
DO $$ BEGIN
  ALTER TABLE public.users
    ADD CONSTRAINT chk_username_format
    CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,20}$');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Índice único (permite nulls múltiples en Postgres — cada null es distinto)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username
  ON public.users (username)
  WHERE username IS NOT NULL;

COMMENT ON COLUMN public.users.username IS
  'Alias único del jugador (a-z, 0-9, _). Se usa para búsqueda e invitaciones.';
