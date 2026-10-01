
BEGIN;

-- Catálogos base
INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Gestión y Tecnología');
INSERT INTO sga.departamento (nombre) VALUES ('Sistemas Digitales y Datos');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'SMK', 'Carrera de Prueba Smoke', id FROM sga.escuela
WHERE nombre = 'Escuela de Gestión y Tecnología';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'AI2', 180, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'SMK';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT '71.28', 'Programación Web (smoke)', id, 6 FROM sga.departamento
WHERE nombre = 'Sistemas Digitales y Datos';

-- Persona + legajo (dispara activación automática de facturables)
INSERT INTO sga.item_facturable (codigo, nombre, monto)
VALUES ('ADITBA', 'Aporte ADITBA', 1000);

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '47345567', 'Kiara', 'Natale', 'knatale@itba.edu.ar');

INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT persona.id, '66092', plan_estudio.id
FROM sga.persona
CROSS JOIN sga.plan_estudio
WHERE persona.nro_documento = '47345567'
  AND plan_estudio.codigo = 'AI2';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sga.item_facturable_legajo
        JOIN sga.legajo ON legajo.id = item_facturable_legajo.legajo_id
        WHERE legajo.numero_legajo = '66092'
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'El item facturable no se activó automáticamente para el legajo nuevo';
    END IF;
END;
$$;

-- Nuevo item facturable posterior: debe propagarse a legajos existentes
INSERT INTO sga.item_facturable (codigo, nombre, monto)
VALUES ('CEITBA', 'Aporte CEITBA', 500);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sga.item_facturable_legajo
        JOIN sga.legajo ON legajo.id = item_facturable_legajo.legajo_id
        JOIN sga.item_facturable ON item_facturable.id = item_facturable_legajo.item_facturable_id
        WHERE legajo.numero_legajo = '66092'
          AND item_facturable.codigo = 'CEITBA'
    ) THEN
        RAISE EXCEPTION 'El item facturable creado después no se propagó a legajos existentes';
    END IF;
END;
$$;

-- Docente + comisión + curso
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '30000001', 'Juan', 'Docente', 'jdocente@itba.edu.ar');

INSERT INTO sga.docente (persona_id)
SELECT id FROM sga.persona WHERE nro_documento = '30000001';

INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'Segundo Cuat.', DATE '2026-08-01', DATE '2026-12-01'
FROM sga.materia WHERE codigo = '71.28';

INSERT INTO sga.comision (curso_id, nombre)
SELECT curso.id, 'A' FROM sga.curso
JOIN sga.materia ON materia.id = curso.materia_id
WHERE materia.codigo = '71.28';

-- Los datos de prueba (seed.sql) pueden convivir con este test: todas las
-- consultas siguientes se acotan a la cursada de 71.28 y al legajo 66092.
CREATE TEMP VIEW smoke_curso AS
SELECT curso.id FROM sga.curso
JOIN sga.materia ON materia.id = curso.materia_id
WHERE materia.codigo = '71.28';

CREATE TEMP VIEW smoke_comision AS
SELECT comision.id FROM sga.comision WHERE curso_id IN (SELECT id FROM smoke_curso);

CREATE TEMP VIEW smoke_legajo AS
SELECT id FROM sga.legajo WHERE numero_legajo = '66092';

CREATE TEMP VIEW smoke_inscripcion AS
SELECT * FROM sga.inscripcion_curso WHERE legajo_id IN (SELECT id FROM smoke_legajo);

INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT docente.id, comision.id
FROM sga.docente
JOIN sga.persona ON persona.id = docente.persona_id
CROSS JOIN smoke_comision AS comision
WHERE persona.nro_documento = '30000001';

-- Docente que NO dicta la comisión no puede cargar nota (debe fallar)
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '30000002', 'Otro', 'Docente', 'odocente@itba.edu.ar');
INSERT INTO sga.docente (persona_id)
SELECT id FROM sga.persona WHERE nro_documento = '30000002';

CREATE OR REPLACE FUNCTION pg_temp.expect_error(p_statement TEXT, p_expected_sqlstate TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_failed BOOLEAN := FALSE;
    v_sqlstate TEXT;
BEGIN
    BEGIN
        EXECUTE p_statement;
    EXCEPTION WHEN OTHERS THEN
        v_failed := TRUE;
        v_sqlstate := SQLSTATE;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'Expected statement to fail with %, but it succeeded: %', p_expected_sqlstate, p_statement;
    END IF;
    IF v_sqlstate <> p_expected_sqlstate THEN
        RAISE EXCEPTION 'Expected SQLSTATE %, got % for: %', p_expected_sqlstate, v_sqlstate, p_statement;
    END IF;
END;
$$;

SELECT pg_temp.expect_error(
    $stmt$
        INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, docente_id)
        SELECT legajo.id, curso.id, comision.id, docente.id
        FROM smoke_legajo AS legajo, smoke_curso AS curso, smoke_comision AS comision, sga.docente
        JOIN sga.persona ON persona.id = docente.persona_id
        WHERE persona.nro_documento = '30000002'
    $stmt$,
    '23514'
);

-- Inscripción correcta con el docente que sí dicta
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, docente_id)
SELECT legajo.id, curso.id, comision.id, docente.id
FROM smoke_legajo AS legajo, smoke_curso AS curso, smoke_comision AS comision, sga.docente
JOIN sga.persona ON persona.id = docente.persona_id
WHERE persona.nro_documento = '30000001';

-- Carga nota de cursada
UPDATE sga.inscripcion_curso SET nota_cursada = 8.00
WHERE legajo_id IN (SELECT id FROM smoke_legajo);

-- Examen final
INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin)
SELECT id, DATE '2026-12-15', '09:00', '12:00' FROM smoke_curso;

CREATE TEMP VIEW smoke_examen AS
SELECT id FROM sga.examen_final WHERE curso_id IN (SELECT id FROM smoke_curso);

-- Intento 1: desaprueba
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento, docente_id)
SELECT inscripcion_curso.id, examen_final.id, 1, docente.id
FROM smoke_inscripcion AS inscripcion_curso, smoke_examen AS examen_final, sga.docente
JOIN sga.persona ON persona.id = docente.persona_id
WHERE persona.nro_documento = '30000001';

UPDATE sga.inscripcion_examen_final SET nota_final = 3.00 WHERE numero_intento = 1
  AND inscripcion_curso_id IN (SELECT id FROM smoke_inscripcion);

DO $$
BEGIN
    IF (SELECT estado FROM smoke_inscripcion) <> 'CURSANDO' THEN
        RAISE EXCEPTION 'Un intento desaprobado (no el 3ro) no debería cambiar el estado de la cursada';
    END IF;
END;
$$;

-- Intento 2: no puede saltear numeración
SELECT pg_temp.expect_error(
    $stmt$
        INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
        SELECT inscripcion_curso.id, examen_final.id, 3
        FROM smoke_inscripcion AS inscripcion_curso, smoke_examen AS examen_final
    $stmt$,
    '23514'
);

INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT inscripcion_curso.id, examen_final.id, 2
FROM smoke_inscripcion AS inscripcion_curso, smoke_examen AS examen_final;

UPDATE sga.inscripcion_examen_final SET nota_final = 6.00 WHERE numero_intento = 2
  AND inscripcion_curso_id IN (SELECT id FROM smoke_inscripcion);

-- Verificar nota_definitiva = (8+6)/2 = 7 y rendimiento académico se propagó
DO $$
DECLARE
    v_nota_definitiva NUMERIC(5,2);
    v_rendimiento NUMERIC(5,2);
    v_condicional BOOLEAN;
BEGIN
    SELECT nota_definitiva INTO v_nota_definitiva FROM smoke_inscripcion;
    SELECT rendimiento_academico, condicional_especial
    INTO v_rendimiento, v_condicional
    FROM sga.legajo WHERE numero_legajo = '66092';

    IF v_nota_definitiva <> 7.00 THEN
        RAISE EXCEPTION 'Nota definitiva esperada 7.00, obtenida %', v_nota_definitiva;
    END IF;
    IF v_rendimiento <> 7.00 THEN
        RAISE EXCEPTION 'Rendimiento académico esperado 7.00, obtenido %', v_rendimiento;
    END IF;
    IF v_condicional <> FALSE THEN
        RAISE EXCEPTION 'condicional_especial debería ser FALSE con rendimiento 7.00';
    END IF;
END;
$$;

-- No se puede cargar un 3er intento si ya aprobó
SELECT pg_temp.expect_error(
    $stmt$
        INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
        SELECT inscripcion_curso.id, examen_final.id, 3
        FROM smoke_inscripcion AS inscripcion_curso, smoke_examen AS examen_final
    $stmt$,
    '23514'
);

ROLLBACK;

SELECT 'sga smoke test passed' AS result;
