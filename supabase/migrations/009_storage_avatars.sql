-- Migration: 009_storage_avatars.sql
-- Crea el bucket de avatares y sus políticas RLS en Supabase Storage.
--
-- ROLLBACK:
--   DROP POLICY IF EXISTS "Public can view avatars"    ON storage.objects;
--   DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
--   DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
--   DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'avatars';

-- ---------------------------------------------------------------------------
-- Bucket
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152,           -- 2 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Policies en storage.objects
-- ---------------------------------------------------------------------------

-- Lectura pública (la URL es pública para mostrar avatares en la UI)
CREATE POLICY "Public can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- El usuario autenticado puede subir SU propio avatar.
-- Ruta: {auth.uid()}.jpg  (plana, sin subcarpeta)
CREATE POLICY "Users can upload own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND name = auth.uid()::text || '.jpg'
);

-- Actualizar (necesario para upsert: true)
CREATE POLICY "Users can update own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND owner_id = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND name = auth.uid()::text || '.jpg'
);

-- Eliminar el propio avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND owner_id = auth.uid()::text
);
