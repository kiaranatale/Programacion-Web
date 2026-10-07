-- Prueba del alta de personas (20261019000000_alta_personas): crear
-- persona con roles y legajo, roles, asignación a comisiones y búsqueda.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Per');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Per');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'PER', 'Carrera de Prueba Per', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Per';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-PER', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'PER';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'PER.01', 'Materia PER.01', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Per';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2030, '1C', DATE '2030-03-01', DATE '2030-07-01' FROM sga.materia WHERE codigo = 'PER.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'PER.01';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('b2b2b2b2-0000-0000-0000-000000000009', 'admin.per@test.local', now()),
    ('b2b2b2b2-0000-0000-0000-000000000001', 'alumno.per@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99600009', 'Admin', 'Per', 'admin.per@test.local'),
    ('DNI', '99600001', 'Alumno', 'Per', 'alumno.per@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99600009';
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ALUMNO' FROM sga.persona WHERE nro_documento = '99600001';

CREATE FUNCTION pg_temp.espera_error(p_sql TEXT, p_texto TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%' || p_texto || '%' THEN
            RAISE EXCEPTION 'Error inesperado: % (se esperaba "%")', SQLERRM, p_texto;
        END IF;
        RETURN;
    END;
    RAISE EXCEPTION 'Se esperaba un error "%" y no lo hubo: %', p_texto, p_sql;
END;
$$;
CREATE FUNCTION pg_temp.plan() RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM sga.plan_estudio WHERE codigo = 'PLN-PER' $$;
CREATE FUNCTION pg_temp.com() RETURNS INTEGER LANGUAGE sql AS $$
    SELECT co.id FROM sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'PER.01'
$$;
CREATE FUNCTION pg_temp.per(doc TEXT) RETURNS INTEGER LANGUAGE sql SECURITY DEFINER AS $$ SELECT id FROM sga.persona WHERE nro_documento = doc $$;
GRANT EXECUTE ON FUNCTION pg_temp.plan(), pg_temp.com(), pg_temp.per(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- Un alumno no puede crear personas ni buscar
SET LOCAL request.jwt.claims TO '{"sub": "b2b2b2b2-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600002', 'X', 'Y', 'x@test.local', NULL, NULL, NULL, ARRAY['ALUMNO']::sga.tipo_rol_persona[], pg_temp.plan(), 'PER-2')$$, 'Solo Administración');
SELECT pg_temp.espera_error($$SELECT * FROM sga.buscar_personas('per')$$, 'Solo Administración');

SET LOCAL request.jwt.claims TO '{"sub": "b2b2b2b2-0000-0000-0000-000000000009"}';
-- Validaciones
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600002', 'Nueva', 'Alumna', 'no-es-mail', NULL, NULL, NULL, ARRAY['ALUMNO']::sga.tipo_rol_persona[], pg_temp.plan(), 'PER-2')$$, 'mail institucional no es válido');
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600002', 'Nueva', 'Alumna', 'nueva.per@test.local', NULL, NULL, NULL, ARRAY[]::sga.tipo_rol_persona[], NULL, NULL)$$, 'al menos un rol');
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600001', 'Nueva', 'Alumna', 'nueva.per@test.local', NULL, NULL, NULL, ARRAY['DOCENTE']::sga.tipo_rol_persona[], NULL, NULL)$$, 'ese documento');
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600002', 'Nueva', 'Alumna', 'ALUMNO.PER@test.local', NULL, NULL, NULL, ARRAY['DOCENTE']::sga.tipo_rol_persona[], NULL, NULL)$$, 'ese mail');
SELECT pg_temp.espera_error($$SELECT sga.crear_persona('DNI', '99600002', 'Nueva', 'Alumna', 'nueva.per@test.local', NULL, NULL, NULL, ARRAY['ALUMNO']::sga.tipo_rol_persona[], pg_temp.plan(), ' ')$$, 'número de legajo');
-- Alumna con legajo; docente-ayudante
SELECT sga.crear_persona('DNI', '99600002', 'Nueva', 'Alumna', ' Nueva.Per@test.local ', 'MUJER', 'Argentina', DATE '2005-01-02',
                         ARRAY['ALUMNO']::sga.tipo_rol_persona[], pg_temp.plan(), 'PER-2');
SELECT sga.crear_persona('DNI', '99600003', 'Nuevo', 'Docente', 'docente.per@test.local', NULL, NULL, NULL,
                         ARRAY['DOCENTE', 'ALUMNO']::sga.tipo_rol_persona[], pg_temp.plan(), 'PER-3');
SELECT pg_temp.espera_error($$SELECT sga.crear_legajo(pg_temp.per('99600001'), pg_temp.plan(), 'PER-2')$$, 'ya existe');
SELECT pg_temp.espera_error($$SELECT sga.crear_legajo(pg_temp.per('99600002'), pg_temp.plan(), 'PER-9')$$, 'ya tiene legajo');
SELECT sga.crear_legajo(pg_temp.per('99600001'), pg_temp.plan(), 'PER-1');
-- Comisiones: solo con rol docente o ayudante
SELECT pg_temp.espera_error($$SELECT sga.asignar_docente_comision(pg_temp.per('99600002'), pg_temp.com())$$, 'rol de docente');
SELECT sga.asignar_docente_comision(pg_temp.per('99600003'), pg_temp.com());
SELECT pg_temp.espera_error($$SELECT sga.asignar_docente_comision(pg_temp.per('99600003'), pg_temp.com())$$, 'Ya está asignado');
SELECT sga.asignar_rol(pg_temp.per('99600002'), 'AYUDANTE');
SELECT sga.asignar_docente_comision(pg_temp.per('99600002'), pg_temp.com());
-- Roles
SELECT pg_temp.espera_error($$SELECT sga.quitar_rol(pg_temp.per('99600009'), 'ADMINISTRATIVO')$$, 'propio rol');
SELECT sga.quitar_rol(pg_temp.per('99600003'), 'ALUMNO');
DO $$
BEGIN
    IF (SELECT mail_institucional FROM sga.persona WHERE nro_documento = '99600002') <> 'nueva.per@test.local' THEN
        RAISE EXCEPTION 'Personas: el mail se guarda normalizado';
    END IF;
    IF (SELECT roles FROM sga.buscar_personas('PER-2')) <> 'ALUMNO,AYUDANTE' THEN
        RAISE EXCEPTION 'Personas: la alumna debería ser ALUMNO y AYUDANTE (busca por legajo)';
    END IF;
    IF (SELECT roles FROM sga.buscar_personas('docente.per')) <> 'DOCENTE' THEN
        RAISE EXCEPTION 'Personas: al docente se le quitó el rol de alumno';
    END IF;
    IF (SELECT count(*) FROM sga.buscar_personas('per')) < 4 THEN
        RAISE EXCEPTION 'Personas: la búsqueda por apellido debería traer a las 4 personas';
    END IF;
    IF (SELECT count(*) FROM sga.docente_comision WHERE comision_id = pg_temp.com()) <> 2 THEN
        RAISE EXCEPTION 'Personas: la comisión debería tener 2 docentes';
    END IF;
END;
$$;
SELECT sga.quitar_docente_comision(dc.id) FROM sga.docente_comision dc
JOIN sga.docente d ON d.id = dc.docente_id WHERE d.persona_id = pg_temp.per('99600002');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.docente_comision WHERE comision_id = pg_temp.com()) <> 1 THEN
        RAISE EXCEPTION 'Personas: quitar la asignación deja 1 docente';
    END IF;
END;
$$;

-- La nueva cuenta se vincula sola por mail (trigger de auth)
RESET ROLE;
INSERT INTO auth.users (id, email, email_confirmed_at) VALUES ('b2b2b2b2-0000-0000-0000-000000000002', 'nueva.per@test.local', now());
DO $$
BEGIN
    IF (SELECT auth_user_id FROM sga.persona WHERE nro_documento = '99600002') IS DISTINCT FROM 'b2b2b2b2-0000-0000-0000-000000000002' THEN
        RAISE EXCEPTION 'Personas: la cuenta nueva debería vincularse por mail';
    END IF;
END;
$$;

ROLLBACK;
