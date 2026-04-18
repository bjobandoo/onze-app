-- Migration: 011_fix_storage_field_photos_policy.sql
-- Recrea las políticas de storage para field-photos usando split_part,
-- más robusto que storage.foldername en distintas versiones de Supabase.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "Field owners can upload photos"   ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can update photos"   ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can delete photos"   ON storage.objects;
--   (luego recrear las originales desde 010_storage_field_photos.sql)

-- Asegurar que el bucket exista (por si la migración 010 no se aplicó)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'field-photos',
  'field-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Reemplazar políticas con versión más robusta usando split_part
DROP POLICY IF EXISTS "Field owners can upload photos" ON storage.objects;
CREATE POLICY "Field owners can upload photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = split_part(name, '/', 1)
      AND owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Field owners can update photos" ON storage.objects;
CREATE POLICY "Field owners can update photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = split_part(name, '/', 1)
      AND owner_id = auth.uid()
  )
)
WITH CHECK (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = split_part(name, '/', 1)
      AND owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Field owners can delete photos" ON storage.objects;
CREATE POLICY "Field owners can delete photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = split_part(name, '/', 1)
      AND owner_id = auth.uid()
  )
);
