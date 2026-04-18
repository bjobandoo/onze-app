-- Migration: 014_fix_join_requests_update_policy.sql
-- Corrige la política UPDATE de team_join_requests para que el capitán
-- pueda actualizar (reenviar) invitaciones cuyo user_id es el invitado.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "actualizar_solicitud" ON public.team_join_requests;
--   CREATE POLICY "actualizar_solicitud"
--     ON public.team_join_requests FOR UPDATE
--     TO authenticated
--     USING (
--       (type = 'invitation' AND user_id = auth.uid())
--       OR (type = 'request' AND public.is_team_captain(team_id))
--     );

DROP POLICY IF EXISTS "actualizar_solicitud" ON public.team_join_requests;

CREATE POLICY "actualizar_solicitud"
  ON public.team_join_requests FOR UPDATE
  TO authenticated
  USING (
    (type = 'invitation' AND (user_id = auth.uid() OR public.is_team_captain(team_id)))
    OR (type = 'request' AND public.is_team_captain(team_id))
  );
