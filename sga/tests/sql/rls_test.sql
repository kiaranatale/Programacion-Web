-- Prueba funcional de las políticas RLS definidas en
-- 20261001000000_rls_policies.sql. Requiere correr contra una instancia
-- de Supabase (local o remota) que ya tenga los roles `anon`/`authenticated`
-- y el schema `auth` provistos por GoTrue — no corre contra un Postgres pelado.
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.


BEGIN;

-- Catálogo mínimo para poder dar de alta un legajo
INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba RLS');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'RLS', 'Carrera de Prueba RLS', id FROM sga.escuela;
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-RLS', 10, DATE '2020-01-01' FROM sga.carrera;

-- Usuarios de Auth simulados
INSERT INTO auth.users (id, email) VALUES
    ('11111111-1111-1111-1111-111111111111', 'alumno.a.rls@test.local'),
    ('22222222-2222-2222-2222-222222222222', 'alumno.b.rls@test.local'),
    ('33333333-3333-3333-3333-333333333333', 'admin.rls@test.local');

-- Personas vinculadas a cada usuario de Auth
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional, auth_user_id)
VALUES
    ('DNI', '90000001', 'Alumno', 'A', 'alumnoa.rls@itba.edu.ar', '11111111-1111-1111-1111-111111111111'),
    ('DNI', '90000002', 'Alumno', 'B', 'alumnob.rls@itba.edu.ar', '22222222-2222-2222-2222-222222222222'),
    ('DNI', '90000003', 'Admin', 'C', 'adminc.rls@itba.edu.ar', '33333333-3333-3333-3333-333333333333');

INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ALUMNO' FROM sga.persona WHERE nro_documento IN ('90000001', '90000002');
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '90000003';

INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT persona.id, 'RLS-' || persona.nro_documento, plan_estudio.id
FROM sga.persona
CROSS JOIN sga.plan_estudio
WHERE persona.nro_documento IN ('90000001', '90000002')
  AND plan_estudio.codigo = 'PLN-RLS';

-- Alumno A debe ver únicamente su propio legajo
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}';

DO $$
DECLARE
    visibles INTEGER;
BEGIN
    SELECT count(*) INTO visibles FROM sga.legajo WHERE numero_legajo LIKE 'RLS-%';
    IF visibles <> 1 THEN
        RAISE EXCEPTION 'RLS: alumno A debería ver únicamente su propio legajo (vio %)', visibles;
    END IF;
END;
$$;

RESET ROLE;
RESET request.jwt.claims;

-- El administrativo debe ver ambos legajos
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "33333333-3333-3333-3333-333333333333"}';

DO $$
DECLARE
    visibles INTEGER;
BEGIN
    SELECT count(*) INTO visibles FROM sga.legajo WHERE numero_legajo LIKE 'RLS-%';
    IF visibles <> 2 THEN
        RAISE EXCEPTION 'RLS: el administrativo debería ver ambos legajos (vio %)', visibles;
    END IF;
END;
$$;

RESET ROLE;
RESET request.jwt.claims;

-- El rol anon (sin JWT) no debe poder leer legajos
SET LOCAL ROLE anon;

DO $$
DECLARE
    visibles INTEGER;
BEGIN
    SELECT count(*) INTO visibles FROM sga.legajo WHERE numero_legajo LIKE 'RLS-%';
    IF visibles <> 0 THEN
        RAISE EXCEPTION 'RLS: el rol anon no debería poder leer sga.legajo (vio %)', visibles;
    END IF;
END;
$$;

RESET ROLE;

ROLLBACK;
