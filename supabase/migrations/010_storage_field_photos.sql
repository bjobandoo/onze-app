-- Migration: 010_storage_field_photos.sql
-- Crea el bucket de fotos de canchas y sus políticas RLS en Supabase Storage.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "Public can view field photos"        ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can upload photos"      ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can update photos"      ON storage.objects;
--   DROP POLICY IF EXISTS "Field owners can delete photos"      ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'field-photos';

-- ---------------------------------------------------------------------------
-- Bucket
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'field-photos',
  'field-photos',
  true,
  5242880,           -- 5 MB por foto
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Policies en storage.objects
-- Ruta de archivos: {field_id}/{photo_index}.jpg
-- ---------------------------------------------------------------------------

-- Lectura pública (las fotos de canchas son visibles para todos)
CREATE POLICY "Public can view field photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'field-photos');

-- El dueño de la cancha puede subir fotos.
-- Verifica que el primer segmento del path corresponda a una cancha propia.
CREATE POLICY "Field owners can upload photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = (storage.foldername(name))[1]
      AND owner_id = auth.uid()
  )
);

-- Actualizar (necesario para upsert: true)
CREATE POLICY "Field owners can update photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = (storage.foldername(name))[1]
      AND owner_id = auth.uid()
  )
)
WITH CHECK (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = (storage.foldername(name))[1]
      AND owner_id = auth.uid()
  )
);

-- El dueño puede eliminar fotos de sus canchas
CREATE POLICY "Field owners can delete photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'field-photos'
  AND EXISTS (
    SELECT 1 FROM public.fields
    WHERE id::text = (storage.foldername(name))[1]
      AND owner_id = auth.uid()
  )
);
