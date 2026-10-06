-- Prueba de Proyectos (20261016000000_proyectos): carga del alumno,
-- revisión de Administración y ayudantías automáticas.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Pry');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Pry');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'PRY', 'Carrera de Prueba Pry', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Pry';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-PRY', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'PRY';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'PRY.01', 'Materia PRY.01', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Pry';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('cdcdcdcd-0000-0000-0000-000000000001', 'a1.pry@test.local', now()),
    ('cdcdcdcd-0000-0000-0000-000000000002', 'a2.pry@test.local', now()),
    ('cdcdcdcd-0000-0000-0000-000000000009', 'admin.pry@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99300001', 'Alumno1', 'Pry', 'a1.pry@test.local'),
    ('DNI', '99300002', 'Alumno2', 'Pry', 'a2.pry@test.local'),
    ('DNI', '99300009', 'Admin', 'Pry', 'admin.pry@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99300009';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'PRY-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99300001', '99300002') AND pl.codigo = 'PLN-PRY';

-- El alumno 1 es ayudante de PRY.01 A
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento = '99300001';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, '1C', DATE '2026-03-01', DATE '2026-07-01' FROM sga.materia WHERE codigo = 'PRY.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'PRY.01';
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, co.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id, sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE p.nro_documento = '99300001' AND m.codigo = 'PRY.01';

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

CREATE TEMP TABLE pry (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON pry TO authenticated;
CREATE FUNCTION pg_temp.p(c TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM pry WHERE clave = c $$;
GRANT EXECUTE ON FUNCTION pg_temp.p(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- Alumno 1: carga dos proyectos, ve sus ayudantías
SET LOCAL request.jwt.claims TO '{"sub": "cdcdcdcd-0000-0000-0000-000000000001"}';
INSERT INTO pry SELECT 'inv', sga.cargar_proyecto('INVESTIGACION', 'Grupo de robótica', NULL, 'Dra. Prueba', 'Visión artificial', DATE '2025-03-01', NULL);
INSERT INTO pry SELECT 'ext', sga.cargar_proyecto('EXTENSION', 'Tutorías de ingreso', NULL, NULL, NULL, DATE '2025-02-01', DATE '2025-02-28');
SELECT pg_temp.espera_error($$SELECT sga.cargar_proyecto('CUALQUIERA', 'X', NULL, NULL, NULL, DATE '2025-01-01', NULL)$$, 'tipo de proyecto');
SELECT pg_temp.espera_error($$SELECT sga.cargar_proyecto('OTRO', '  ', NULL, NULL, NULL, DATE '2025-01-01', NULL)$$, 'título');
SELECT pg_temp.espera_error($$SELECT sga.cargar_proyecto('OTRO', 'X', NULL, NULL, NULL, DATE '2025-01-01', DATE '2024-01-01')$$, 'anterior');
SELECT pg_temp.espera_error($$SELECT sga.revisar_proyecto(pg_temp.p('inv'), TRUE, NULL)$$, 'Solo Administración');
SELECT pg_temp.espera_error($$SELECT * FROM sga.proyectos_para_revisar()$$, 'Solo Administración');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.proyecto_alumno) <> 2 THEN
        RAISE EXCEPTION 'Proyectos: el alumno debería ver sus 2 proyectos';
    END IF;
    IF (SELECT estado FROM sga.proyecto_alumno WHERE id = pg_temp.p('inv')) <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Proyectos: un proyecto nuevo queda pendiente';
    END IF;
    IF (SELECT count(*) FROM sga.mis_ayudantias() WHERE codigo = 'PRY.01' AND comision = 'A') <> 1 THEN
        RAISE EXCEPTION 'Proyectos: debería figurar la ayudantía de PRY.01 A';
    END IF;
END;
$$;

-- Alumno 2: no ve ni toca los proyectos del alumno 1
SET LOCAL request.jwt.claims TO '{"sub": "cdcdcdcd-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error($$SELECT sga.borrar_proyecto(pg_temp.p('ext'))$$, 'No tenés ese proyecto');
SELECT pg_temp.espera_error($$SELECT sga.editar_proyecto(pg_temp.p('ext'), 'OTRO', 'X', NULL, NULL, NULL, DATE '2025-01-01', NULL)$$, 'No tenés ese proyecto');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.proyecto_alumno) <> 0 THEN
        RAISE EXCEPTION 'Proyectos: el alumno 2 no debería ver proyectos ajenos';
    END IF;
    IF (SELECT count(*) FROM sga.mis_ayudantias()) <> 0 THEN
        RAISE EXCEPTION 'Proyectos: el alumno 2 no tiene ayudantías';
    END IF;
END;
$$;

-- Administración: valida uno y rechaza el otro (con motivo)
SET LOCAL request.jwt.claims TO '{"sub": "cdcdcdcd-0000-0000-0000-000000000009"}';
SELECT pg_temp.espera_error($$SELECT sga.revisar_proyecto(pg_temp.p('ext'), FALSE, ' ')$$, 'motivo');
SELECT sga.revisar_proyecto(pg_temp.p('inv'), TRUE, NULL);
SELECT sga.revisar_proyecto(pg_temp.p('ext'), FALSE, 'Falta el aval del área');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.proyectos_para_revisar() WHERE numero_legajo = 'PRY-1') <> 2 THEN
        RAISE EXCEPTION 'Proyectos: Administración debería ver los 2 proyectos';
    END IF;
END;
$$;

-- Alumno 1: no puede tocar el validado; corrige el rechazado y vuelve a pendiente
SET LOCAL request.jwt.claims TO '{"sub": "cdcdcdcd-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.editar_proyecto(pg_temp.p('inv'), 'OTRO', 'X', NULL, NULL, NULL, DATE '2025-01-01', NULL)$$, 'ya está validado');
SELECT pg_temp.espera_error($$SELECT sga.borrar_proyecto(pg_temp.p('inv'))$$, 'ya está validado');
SELECT sga.editar_proyecto(pg_temp.p('ext'), 'EXTENSION', 'Tutorías de ingreso 2025', NULL, 'Área de Ingreso', NULL, DATE '2025-02-01', DATE '2025-02-28');
DO $$
BEGIN
    IF (SELECT estado || '|' || coalesce(observaciones, '') FROM sga.proyecto_alumno WHERE id = pg_temp.p('ext')) <> 'PENDIENTE|' THEN
        RAISE EXCEPTION 'Proyectos: al corregir un rechazado vuelve a pendiente sin motivo';
    END IF;
END;
$$;
SELECT sga.borrar_proyecto(pg_temp.p('ext'));
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.proyecto_alumno) <> 1 THEN
        RAISE EXCEPTION 'Proyectos: debería quedar solo el validado';
    END IF;
END;
$$;

ROLLBACK;
