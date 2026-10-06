-- =====================================================================
-- Lo mínimo de Supabase para correr migraciones, seeds y tests en un
-- Postgres común (CI de GitHub Actions o una base local): roles de la
-- Data API, auth.users/auth.uid() y las tablas de Storage que usan las
-- políticas. NO correr en el proyecto de Supabase (ya trae todo esto).
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END;
$$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (id UUID PRIMARY KEY, email TEXT, email_confirmed_at TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql STABLE AS $$
    SELECT (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::UUID
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS storage;
CREATE TABLE IF NOT EXISTS storage.buckets (
    id TEXT PRIMARY KEY, name TEXT, public BOOLEAN, file_size_limit BIGINT, allowed_mime_types TEXT[]
);
CREATE TABLE IF NOT EXISTS storage.objects (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id TEXT, name TEXT);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION storage.foldername(name TEXT) RETURNS TEXT[] LANGUAGE sql IMMUTABLE AS $$
    SELECT (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
