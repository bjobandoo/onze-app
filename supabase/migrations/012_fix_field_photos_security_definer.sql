-- Migration: 012_fix_field_photos_security_definer.sql
-- Reemplaza las políticas de storage field-photos con una función SECURITY DEFINER
-- para evitar problemas de RLS anidado al consultar public.fields desde storage.objects.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "Field owners can upload photos"  ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can update photos"  ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can delete photos"  ON storage.objects;
--   DROP FUNCTION IF EXISTS public.is_field_owner(text);

-- ---------------------------------------------------------------------------
-- Función helper con SECURITY DEFINER
-- Ejecuta como el dueño de la función (postgres), bypaseando RLS en fields,
-- pero sigue usando auth.uid() para verificar la identidad del llamante.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_field_owner(p_field_id text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = p_field_id
      AND owner_id = auth.uid()
  );
$$;

-- Dar acceso a usuarios autenticados
GRANT EXECUTE ON FUNCTION public.is_field_owner(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Recrear políticas usando la función helper
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Field owners can upload photos" ON storage.objects;
CREATE POLICY "Field owners can upload photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'field-photos'
  AND public.is_field_owner(split_part(name, '/', 1))
);

DROP POLICY IF EXISTS "Field owners can update photos" ON storage.objects;
CREATE POLICY "Field owners can update photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND public.is_field_owner(split_part(name, '/', 1))
)
WITH CHECK (
  bucket_id = 'field-photos'
  AND public.is_field_owner(split_part(name, '/', 1))
);

DROP POLICY IF EXISTS "Field owners can delete photos" ON storage.objects;
CREATE POLICY "Field owners can delete photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND public.is_field_owner(split_part(name, '/', 1))
);
