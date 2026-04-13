-- =============================================================================
-- Migración 008 — Token FCM para notificaciones push
-- =============================================================================
-- ROLLBACK:
--   ALTER TABLE public.users DROP COLUMN IF EXISTS fcm_token;
-- =============================================================================

-- Columna para almacenar el token FCM del dispositivo activo del usuario.
-- Se sobreescribe cada vez que el usuario abre la app en un dispositivo nuevo.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS fcm_token text;

COMMENT ON COLUMN public.users.fcm_token IS
  'Token FCM del dispositivo activo. Se actualiza al iniciar sesión.';

-- Índice parcial para acelerar búsquedas de usuarios con token válido.
CREATE INDEX IF NOT EXISTS idx_users_has_fcm_token
  ON public.users (id)
  WHERE fcm_token IS NOT NULL;
