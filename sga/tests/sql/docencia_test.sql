-- Prueba de Docencia (20261011000000_docencia): carga de notas de cursada
-- y de finales solo en comisiones propias, con sus reglas. Requiere
-- Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Doc2');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Doc2');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'DC2', 'Carrera de Prueba Doc2', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Doc2';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-DC2', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'DC2';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'DC2.01', 'Materia de Prueba Doc2', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Doc2';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'DC2', DATE '2026-03-01', DATE '2026-07-01' FROM sga.materia WHERE codigo = 'DC2.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, x.n FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
CROSS JOIN (VALUES ('A'), ('B')) AS x (n) WHERE m.codigo = 'DC2.01';

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('dddddddd-0000-0000-0000-00000000000' || n)::UUID, 'p' || n || '.dc2@test.local', now() FROM generate_series(1, 5) AS n;
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
SELECT 'DNI', '9800000' || n, 'Persona' || n, 'Dc2', 'p' || n || '.dc2@test.local' FROM generate_series(1, 5) AS n;
-- p1..p3 alumnos (p1, p2 en A; p3 en B), p4 docente de A, p5 docente de B
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'DC2-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('98000001', '98000002', '98000003') AND pl.codigo = 'PLN-DC2';
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento IN ('98000004', '98000005');

CREATE TEMP VIEW dc2_comision AS
SELECT co.id, co.curso_id, co.nombre FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'DC2.01';
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, dc.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id
JOIN dc2_comision dc ON dc.nombre = CASE p.nro_documento WHEN '98000004' THEN 'A' ELSE 'B' END;
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, dc.curso_id, dc.id FROM sga.legajo l
JOIN dc2_comision dc ON dc.nombre = CASE l.numero_legajo WHEN 'DC2-3' THEN 'B' ELSE 'A' END
WHERE l.numero_legajo LIKE 'DC2-%';
INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin)
SELECT DISTINCT curso_id, x.f, TIME '09:00', TIME '12:00' FROM dc2_comision
CROSS JOIN (VALUES (sga.hoy() - 7), (sga.hoy() + 7)) AS x (f);

CREATE TEMP TABLE dc2_ids AS
SELECT
    (SELECT ic.id FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id WHERE l.numero_legajo = 'DC2-1') AS ic1,
    (SELECT ic.id FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id WHERE l.numero_legajo = 'DC2-2') AS ic2,
    (SELECT ic.id FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id WHERE l.numero_legajo = 'DC2-3') AS ic3,
    (SELECT ef.id FROM sga.examen_final ef JOIN dc2_comision dc ON dc.curso_id = ef.curso_id WHERE ef.fecha < sga.hoy() LIMIT 1) AS mesa_pasada,
    (SELECT ef.id FROM sga.examen_final ef JOIN dc2_comision dc ON dc.curso_id = ef.curso_id WHERE ef.fecha > sga.hoy() LIMIT 1) AS mesa_futura;
GRANT SELECT ON dc2_ids TO authenticated;

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

SET LOCAL ROLE authenticated;

-- ---------- Docente de A ----------
SET LOCAL request.jwt.claims TO '{"sub": "dddddddd-0000-0000-0000-000000000004"}';
DO $$
BEGIN
    IF (SELECT inscriptos FROM sga.mis_comisiones() WHERE codigo = 'DC2.01') <> 2
        OR (SELECT sin_nota FROM sga.mis_comisiones() WHERE codigo = 'DC2.01') <> 2 THEN
        RAISE EXCEPTION 'Docencia: la comisión A debería tener 2 inscriptos sin nota';
    END IF;
    PERFORM sga.cargar_nota_cursada((SELECT ic1 FROM dc2_ids), 8);
    PERFORM sga.cargar_nota_cursada((SELECT ic2 FROM dc2_ids), 3);
    IF (SELECT estado FROM sga.inscripcion_curso WHERE id = (SELECT ic1 FROM dc2_ids)) <> 'CURSADA_APROBADA'
        OR (SELECT estado FROM sga.inscripcion_curso WHERE id = (SELECT ic2 FROM dc2_ids)) <> 'DESAPROBADA' THEN
        RAISE EXCEPTION 'Docencia: estados de cursada inesperados';
    END IF;
    -- Corregir: borrar la nota vuelve a CURSANDO
    PERFORM sga.cargar_nota_cursada((SELECT ic2 FROM dc2_ids), NULL);
    IF (SELECT estado FROM sga.inscripcion_curso WHERE id = (SELECT ic2 FROM dc2_ids)) <> 'CURSANDO' THEN
        RAISE EXCEPTION 'Docencia: sin nota la cursada debería volver a CURSANDO';
    END IF;
END;
$$;
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_cursada(%s, 7)', ic3), 'comisiones que dictás') FROM dc2_ids;
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_cursada(%s, 11)', ic1), 'entre 0 y 10') FROM dc2_ids;

-- Inscripciones a la mesa pasada y a la futura (las hace Administración)
RESET ROLE;
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT ic1, mesa_pasada, 1 FROM dc2_ids;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "dddddddd-0000-0000-0000-000000000004"}';

DO $$
BEGIN
    IF (SELECT sin_nota FROM sga.mesas_de_final_docente() WHERE examen_final_id = (SELECT mesa_pasada FROM dc2_ids)) <> 1 THEN
        RAISE EXCEPTION 'Docencia: la mesa pasada debería tener 1 inscripto sin nota';
    END IF;
END;
$$;
-- Con finales rendidos ya no cambia la cursada
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_cursada(%s, 9)', ic1), 'ya no se puede cambiar') FROM dc2_ids;
SELECT sga.cargar_nota_final((SELECT ief.id FROM sga.inscripcion_examen_final ief WHERE ief.inscripcion_curso_id = ic1), 6) FROM dc2_ids;
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_final(%s, 9)', ief.id), 'ya está cargada')
FROM sga.inscripcion_examen_final ief, dc2_ids WHERE ief.inscripcion_curso_id = ic1;

-- ---------- Docente de B: no carga notas de A ----------
SET LOCAL request.jwt.claims TO '{"sub": "dddddddd-0000-0000-0000-000000000005"}';
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_cursada(%s, 7)', ic2), 'comisiones que dictás') FROM dc2_ids;

RESET ROLE;
DO $$
BEGIN
    -- Final 6 + cursada 8 = definitiva 7, APROBADA, y el rendimiento se recalcula
    IF (SELECT nota_definitiva FROM sga.inscripcion_curso WHERE id = (SELECT ic1 FROM dc2_ids)) <> 7.00
        OR (SELECT estado FROM sga.inscripcion_curso WHERE id = (SELECT ic1 FROM dc2_ids)) <> 'APROBADA' THEN
        RAISE EXCEPTION 'Docencia: no se calculó la nota definitiva';
    END IF;
    IF (SELECT rendimiento_academico FROM sga.legajo WHERE numero_legajo = 'DC2-1') <> 7.00 THEN
        RAISE EXCEPTION 'Docencia: no se recalculó el rendimiento académico';
    END IF;
END;
$$;

-- Mesa futura: todavía no se puede cargar
UPDATE sga.inscripcion_curso SET nota_cursada = 5, estado = 'CURSADA_APROBADA' WHERE id = (SELECT ic2 FROM dc2_ids);
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT ic2, mesa_futura, 1 FROM dc2_ids;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "dddddddd-0000-0000-0000-000000000004"}';
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_final(%s, 8)', ief.id), 'todavía no se tomó')
FROM sga.inscripcion_examen_final ief, dc2_ids WHERE ief.inscripcion_curso_id = ic2;

ROLLBACK;
