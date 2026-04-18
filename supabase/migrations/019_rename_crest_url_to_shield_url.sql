-- Migration: 019_rename_crest_url_to_shield_url.sql
-- Renombra teams.crest_url → teams.shield_url para alinear con el código Flutter.
-- El renombre preserva todos los datos existentes.
--
-- ROLLBACK:
--   ALTER TABLE public.teams RENAME COLUMN shield_url TO crest_url;

ALTER TABLE public.teams RENAME COLUMN crest_url TO shield_url;
