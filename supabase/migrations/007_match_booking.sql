-- =============================================================================
-- Migración 007 — Políticas y función para confirmación de reservas
-- =============================================================================
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS public.confirm_match(uuid);
--   DROP POLICY IF EXISTS "dueno_confirma_reserva" ON public.matches;
-- =============================================================================

DROP POLICY IF EXISTS "dueno_confirma_reserva" ON public.matches;
CREATE POLICY "dueno_confirma_reserva"
  ON public.matches FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.fields
      WHERE id = field_id AND owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- Función: confirm_match
-- Confirma atómicamente una reserva: actualiza match_request a 'confirmed'
-- e inserta el registro en matches. Solo el dueño de la cancha puede llamarla.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.confirm_match(p_match_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req  public.match_requests;
  v_match_id uuid;
BEGIN
  -- Bloquear la fila para evitar condiciones de carrera
  SELECT * INTO v_req
  FROM public.match_requests
  WHERE id = p_match_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de partido no encontrada.';
  END IF;

  -- Verificar que el dueño que llama es dueño de esta cancha
  IF NOT EXISTS (
    SELECT 1 FROM public.fields
    WHERE id = v_req.field_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'No tienes permiso para confirmar esta reserva.';
  END IF;

  -- Solo se puede confirmar desde pending_owner
  IF v_req.status <> 'pending_owner' THEN
    RAISE EXCEPTION 'La solicitud no está en estado pending_owner (actual: %).', v_req.status;
  END IF;

  -- Verificar que el bloqueo de 45 minutos no haya expirado
  IF v_req.blocked_until IS NOT NULL AND v_req.blocked_until < now() AT TIME ZONE 'UTC' THEN
    UPDATE public.match_requests
    SET status = 'expired'
    WHERE id = p_match_request_id;
    RAISE EXCEPTION 'El bloqueo temporal ha expirado. El horario ya no está reservado.';
  END IF;

  -- Actualizar el estado de la solicitud
  UPDATE public.match_requests
  SET
    status             = 'confirmed',
    owner_responded_at = now()
  WHERE id = p_match_request_id;

  -- Crear el partido oficial
  INSERT INTO public.matches (
    match_request_id,
    team_a_id,
    team_b_id,
    field_id,
    match_date,
    start_time,
    end_time,
    status
  ) VALUES (
    v_req.id,
    v_req.challenger_team_id,
    v_req.challenged_team_id,
    v_req.field_id,
    v_req.requested_date,
    v_req.requested_start_time,
    v_req.requested_end_time,
    'scheduled'
  )
  RETURNING id INTO v_match_id;

  RETURN v_match_id;
END;
$$;
