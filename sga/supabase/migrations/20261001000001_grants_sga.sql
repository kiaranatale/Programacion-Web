-- =====================================================================
-- Permisos sobre el schema `sga` para los roles de la Data API
-- Supabase solo otorga permisos automáticos sobre `public`. Sin estos
-- GRANT, cualquier consulta de la app (roles anon/authenticated) falla
-- con "permission denied for schema sga" antes de llegar a evaluar RLS.
--
-- Los permisos de tabla no abren los datos: RLS (habilitado en todas las
-- tablas por 20261001000000_rls_policies.sql) sigue filtrando fila por
-- fila. Las políticas son TO authenticated, así que anon ve 0 filas.
-- =====================================================================

GRANT USAGE ON SCHEMA sga TO anon, authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sga
    TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sga
    TO anon, authenticated, service_role;

-- Tablas y secuencias que se creen en migraciones futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA sga
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
    TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA sga
    GRANT USAGE, SELECT ON SEQUENCES
    TO anon, authenticated, service_role;

-- Faltaba en el GRANT EXECUTE de 20261001000000_rls_policies.sql; lo usan
-- las políticas de legajo/facturación del alumno.
GRANT EXECUTE ON FUNCTION sga.legajo_actual_id() TO authenticated;
