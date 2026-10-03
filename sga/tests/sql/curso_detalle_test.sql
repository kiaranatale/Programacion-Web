-- Prueba del detalle del curso (20261006000000_curso_cupos_companeros_contenidos):
-- ocupación del cupo, listado de inscriptos de una comisión y edición de
-- contenidos mínimos por el responsable. Requiere Supabase (schema auth y
-- roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Curso');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Curso');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'CUR', 'Carrera de Prueba Curso', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Curso';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-CUR', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'CUR';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'CUR.01', 'Materia de Prueba Curso', id, 6 FROM sga.departamento
WHERE nombre = 'Departamento de Prueba Curso';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'CUR', DATE '2026-08-01', DATE '2026-12-01' FROM sga.materia WHERE codigo = 'CUR.01';
INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, x.nombre, x.cupo
FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
CROSS JOIN (VALUES ('A', 40), ('B', 30)) AS x (nombre, cupo)
WHERE m.codigo = 'CUR.01';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('88888888-8888-8888-8888-888888888881', 'alumno1.cur@test.local', now()),
    ('88888888-8888-8888-8888-888888888882', 'alumno2.cur@test.local', now()),
    ('88888888-8888-8888-8888-888888888883', 'alumno3.cur@test.local', now()),
    ('88888888-8888-8888-8888-888888888884', 'alumno4.cur@test.local', now()),
    ('88888888-8888-8888-8888-888888888885', 'jefe.cur@test.local', now()),
    ('88888888-8888-8888-8888-888888888886', 'ayudante.cur@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '93000001', 'Uno',    'Alumno', 'alumno1.cur@test.local'),
    ('DNI', '93000002', 'Dos',    'Alumno', 'alumno2.cur@test.local'),
    ('DNI', '93000003', 'Tres',   'Alumno', 'alumno3.cur@test.local'),
    ('DNI', '93000004', 'Cuatro', 'Alumno', 'alumno4.cur@test.local'),
    ('DNI', '93000005', 'Jefe',   'Curso',  'jefe.cur@test.local'),
    ('DNI', '93000006', 'Ayudante', 'Curso', 'ayudante.cur@test.local');
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'CUR-' || right(p.nro_documento, 1), pl.id
FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('93000001', '93000002', '93000003', '93000004') AND pl.codigo = 'PLN-CUR';
INSERT INTO sga.docente (persona_id)
SELECT id FROM sga.persona WHERE nro_documento IN ('93000005', '93000006');

CREATE TEMP VIEW cur_comision AS
SELECT co.id, co.curso_id, co.nombre FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id
JOIN sga.materia m ON m.id = c.materia_id
WHERE m.codigo = 'CUR.01';

-- Alumnos 1 y 2 en A, 3 en B (abandonó), 4 en B
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado)
SELECT l.id, cc.curso_id, cc.id, x.estado::sga.estado_inscripcion_curso
FROM (VALUES ('CUR-1', 'A', 'CURSANDO'), ('CUR-2', 'A', 'CURSANDO'),
             ('CUR-3', 'B', 'ABANDONADA'), ('CUR-4', 'B', 'CURSANDO')) AS x (legajo, comision, estado)
JOIN sga.legajo l ON l.numero_legajo = x.legajo
JOIN cur_comision cc ON cc.nombre = x.comision;

-- Jefe: responsable del curso. Ayudante: docente de la comisión A.
UPDATE sga.curso c SET responsable_docente_id = d.id
FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id
WHERE p.nro_documento = '93000005' AND c.id = (SELECT curso_id FROM cur_comision LIMIT 1);
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, cc.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id, cur_comision cc
WHERE p.nro_documento = '93000006' AND cc.nombre = 'A';

CREATE TEMP TABLE cur_ids AS
SELECT
    (SELECT curso_id FROM cur_comision LIMIT 1) AS curso,
    (SELECT id FROM cur_comision WHERE nombre = 'A') AS com_a,
    (SELECT id FROM cur_comision WHERE nombre = 'B') AS com_b;
GRANT SELECT ON cur_ids, cur_comision TO authenticated;

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

-- ---------- Alumno 1 (comisión A) ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "88888888-8888-8888-8888-888888888881"}';

DO $$
DECLARE v_ids RECORD;
BEGIN
    SELECT * INTO v_ids FROM cur_ids;
    -- Ocupación del cupo: A 2, B 1 (la inscripción abandonada no cuenta)
    IF (SELECT inscriptos FROM sga.comision_inscriptos WHERE comision_id = v_ids.com_a) <> 2
        OR (SELECT inscriptos FROM sga.comision_inscriptos WHERE comision_id = v_ids.com_b) <> 1 THEN
        RAISE EXCEPTION 'Curso: la ocupación del cupo no es la esperada';
    END IF;
    IF NOT sga.puede_ver_inscriptos(v_ids.com_a) OR sga.puede_ver_inscriptos(v_ids.com_b) THEN
        RAISE EXCEPTION 'Curso: el alumno debería ver solo el listado de su comisión';
    END IF;
    IF (SELECT string_agg(apellido || ', ' || nombre, ' / ') FROM sga.companeros_comision(v_ids.com_a))
        IS DISTINCT FROM 'Alumno, Dos / Alumno, Uno' THEN
        RAISE EXCEPTION 'Curso: el listado de la comisión A no es el esperado';
    END IF;
    IF sga.puede_editar_contenidos(v_ids.curso) THEN
        RAISE EXCEPTION 'Curso: un alumno no puede editar contenidos';
    END IF;
END;
$$;

SELECT pg_temp.espera_error(format('SELECT * FROM sga.companeros_comision(%s)', com_b), 'Solo los inscriptos') FROM cur_ids;
SELECT pg_temp.espera_error(format('SELECT sga.actualizar_contenidos_minimos(%s, %L)', curso, 'x'), 'Solo el responsable') FROM cur_ids;

-- ---------- Alumno 3 (abandonó B): ya no ve el listado ----------
SET LOCAL request.jwt.claims TO '{"sub": "88888888-8888-8888-8888-888888888883"}';
SELECT pg_temp.espera_error(format('SELECT * FROM sga.companeros_comision(%s)', com_b), 'Solo los inscriptos') FROM cur_ids;

-- ---------- Ayudante (docente de A, no responsable) ----------
SET LOCAL request.jwt.claims TO '{"sub": "88888888-8888-8888-8888-888888888886"}';
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.companeros_comision((SELECT com_a FROM cur_ids))) <> 2 THEN
        RAISE EXCEPTION 'Curso: el docente de la comisión debería ver sus inscriptos';
    END IF;
END;
$$;
SELECT pg_temp.espera_error(format('SELECT sga.actualizar_contenidos_minimos(%s, %L)', curso, 'x'), 'Solo el responsable') FROM cur_ids;

-- ---------- Jefe de cátedra (responsable) ----------
SET LOCAL request.jwt.claims TO '{"sub": "88888888-8888-8888-8888-888888888885"}';
SELECT sga.actualizar_contenidos_minimos(curso, '  Unidad 1. Unidad 2.  ') FROM cur_ids;

RESET ROLE;
DO $$
BEGIN
    IF (SELECT contenidos_minimos FROM sga.materia WHERE codigo = 'CUR.01') IS DISTINCT FROM 'Unidad 1. Unidad 2.' THEN
        RAISE EXCEPTION 'Curso: el responsable no pudo actualizar los contenidos mínimos';
    END IF;
END;
$$;

ROLLBACK;
