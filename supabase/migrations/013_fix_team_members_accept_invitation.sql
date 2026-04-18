-- Migration: 013_fix_team_members_accept_invitation.sql
-- Agrega política que permite al usuario invitado insertarse en team_members
-- cuando existe una invitación aceptada para él en ese equipo.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "invitado_acepta_unirse" ON public.team_members;
--   DROP FUNCTION IF EXISTS public.has_team_invitation(uuid, uuid);

-- ---------------------------------------------------------------------------
-- Función SECURITY DEFINER para verificar invitación sin RLS anidado
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_team_invitation(p_team_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.team_join_requests
    WHERE team_id   = p_team_id
      AND user_id   = p_user_id
      AND type      = 'invitation'
      AND status    IN ('pending', 'accepted')
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_team_invitation(uuid, uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Nueva política: el invitado puede agregarse a sí mismo como miembro
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "invitado_acepta_unirse" ON public.team_members;
CREATE POLICY "invitado_acepta_unirse"
  ON public.team_members FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND public.has_team_invitation(team_id, auth.uid())
  );
