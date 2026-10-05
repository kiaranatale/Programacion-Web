-- Prueba de la inscripción a finales por turnos
-- (20261012000000_turnos_finales y 20261012000001_final_ausente).
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Fin');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Fin');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'FIN', 'Carrera de Prueba Fin', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Fin';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-FIN', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'FIN';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT x.c, 'Materia ' || x.c, d.id, 6 FROM sga.departamento d, (VALUES ('FIN.01'), ('FIN.02')) AS x (c)
WHERE d.nombre = 'Departamento de Prueba Fin';
-- FIN.02 pide FIN.01 aprobada para rendir
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT pl.id, m2.id, m1.id, 'PARA_RENDIR', 'APROBADA'
FROM sga.plan_estudio pl, sga.materia m1, sga.materia m2
WHERE pl.codigo = 'PLN-FIN' AND m1.codigo = 'FIN.01' AND m2.codigo = 'FIN.02';
-- Cursos: FIN.01 en dos cuatrimestres (las fechas son de la materia), FIN.02 uno
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT m.id, 2026, x.p, x.i, x.f FROM sga.materia m
JOIN (VALUES ('FIN.01', '1C', DATE '2026-03-01', DATE '2026-07-01'),
             ('FIN.01', '2C', DATE '2026-08-01', DATE '2026-12-01'),
             ('FIN.02', '1C', DATE '2026-03-01', DATE '2026-07-01')) AS x (m, p, i, f) ON x.m = m.codigo;
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo LIKE 'FIN.%';

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('eeeeeeee-0000-0000-0000-00000000000' || n)::UUID, 'p' || n || '.fin@test.local', now() FROM generate_series(1, 3) AS n;
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
SELECT 'DNI', '9900000' || n, 'Persona' || n, 'Fin', 'p' || n || '.fin@test.local' FROM generate_series(1, 3) AS n;
-- p1 alumno, p2 docente de FIN.01 2C (no de 1C), p3 alumno sin cursada
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'FIN-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99000001', '99000003') AND pl.codigo = 'PLN-FIN';
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento = '99000002';
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, co.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id,
     sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE p.nro_documento = '99000002' AND m.codigo = 'FIN.01' AND c.periodo = '2C';
-- El alumno cursó FIN.01 y FIN.02 en el 1C con cursada aprobada
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado, nota_cursada)
SELECT l.id, c.id, co.id, 'CURSADA_APROBADA', 8
FROM sga.legajo l, sga.curso c JOIN sga.materia m ON m.id = c.materia_id JOIN sga.comision co ON co.curso_id = c.id
WHERE l.numero_legajo = 'FIN-1' AND m.codigo LIKE 'FIN.%' AND c.periodo = '1C';

-- Turno abierto con dos fechas de FIN.01 (cargadas en el curso 2C) y una
-- que cierra en menos de 48 h; turno futuro y turno cerrado.
INSERT INTO sga.turno_examen (nombre, inscripcion_desde, inscripcion_hasta) VALUES
    ('Turno abierto Fin', sga.hoy() - 5, sga.hoy() + 20),
    ('Turno futuro Fin', sga.hoy() + 30, sga.hoy() + 40),
    ('Turno cerrado Fin', sga.hoy() - 40, sga.hoy() - 30);
INSERT INTO sga.examen_final (curso_id, turno_id, fecha, hora_inicio, hora_fin)
SELECT c.id, t.id, x.f, TIME '09:00', TIME '12:00'
FROM (VALUES ('FIN.01', 'Turno abierto Fin', sga.hoy() + 10),
             ('FIN.01', 'Turno abierto Fin', sga.hoy() + 17),
             ('FIN.02', 'Turno abierto Fin', sga.hoy() + 1),
             ('FIN.02', 'Turno abierto Fin', sga.hoy() + 12),
             ('FIN.01', 'Turno futuro Fin', sga.hoy() + 50),
             ('FIN.01', 'Turno cerrado Fin', sga.hoy() - 20)) AS x (m, t, f)
JOIN sga.materia m ON m.codigo = x.m
JOIN sga.curso c ON c.materia_id = m.id AND c.periodo = CASE x.m WHEN 'FIN.01' THEN '2C' ELSE '1C' END
JOIN sga.turno_examen t ON t.nombre = x.t;

CREATE TEMP TABLE fin_ids AS
SELECT
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id JOIN sga.materia m ON m.id = c.materia_id
     WHERE m.codigo = 'FIN.01' AND ef.fecha = sga.hoy() + 10) AS f1_a,
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id JOIN sga.materia m ON m.id = c.materia_id
     WHERE m.codigo = 'FIN.01' AND ef.fecha = sga.hoy() + 17) AS f1_b,
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id JOIN sga.materia m ON m.id = c.materia_id
     WHERE m.codigo = 'FIN.02' AND ef.fecha = sga.hoy() + 1) AS f2_48h,
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id JOIN sga.materia m ON m.id = c.materia_id
     WHERE m.codigo = 'FIN.02' AND ef.fecha = sga.hoy() + 12) AS f2,
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.turno_examen t ON t.id = ef.turno_id WHERE t.nombre = 'Turno futuro Fin') AS futuro,
    (SELECT ef.id FROM sga.examen_final ef JOIN sga.turno_examen t ON t.id = ef.turno_id WHERE t.nombre = 'Turno cerrado Fin') AS cerrado;
GRANT SELECT ON fin_ids TO authenticated;

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

-- ---------- Alumno ----------
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', futuro), 'abre el') FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', cerrado), 'cerró el') FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f2_48h), '48 h antes') FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f2), 'correlativas para rendir: FIN.01') FROM fin_ids;

-- Se anota a la primera fecha de FIN.01 (aunque la cargaron en el curso 2C)
SELECT sga.inscribirse_final(f1_a) FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f1_a), 'Ya estás anotado a esta fecha') FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f1_b), 'otra fecha de esta materia') FROM fin_ids;
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.finales_para_mi() WHERE codigo = 'FIN.01' AND inscripcion_id IS NOT NULL) <> 1 THEN
        RAISE EXCEPTION 'Finales: debería figurar anotado a una fecha de FIN.01';
    END IF;
END;
$$;
-- Se da de baja y se anota a la otra
SELECT sga.desinscribirse_final((SELECT inscripcion_id FROM sga.finales_para_mi() WHERE inscripcion_id IS NOT NULL));
SELECT sga.inscribirse_final(f1_b) FROM fin_ids;

-- ---------- Otro alumno sin cursada ----------
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000003"}';
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f1_a), 'No cursaste') FROM fin_ids;

-- ---------- Docente de FIN.01 (otra comisión): ve y carga ----------
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000002"}';
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.inscriptos_fecha_final((SELECT f1_b FROM fin_ids))) <> 1 THEN
        RAISE EXCEPTION 'Finales: el docente de la materia debería ver al inscripto de otra comisión';
    END IF;
END;
$$;
SELECT pg_temp.espera_error(format('SELECT * FROM sga.inscriptos_fecha_final(%s)', f2), 'docentes de la materia') FROM fin_ids;
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_final(%s, 8)', inscripcion_id), 'todavía no se tomó')
FROM sga.inscriptos_fecha_final((SELECT f1_b FROM fin_ids));

-- El examen pasó: el docente lo marca ausente (cuenta como intento)
RESET ROLE;
UPDATE sga.examen_final SET fecha = sga.hoy() - 1 WHERE id = (SELECT f1_b FROM fin_ids);
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000002"}';
SELECT sga.cargar_nota_final(inscripcion_id, NULL, TRUE) FROM sga.inscriptos_fecha_final((SELECT f1_b FROM fin_ids));
SELECT pg_temp.espera_error(format('SELECT sga.cargar_nota_final(%s, 7)', inscripcion_id), 'ya está cargada')
FROM sga.inscriptos_fecha_final((SELECT f1_b FROM fin_ids));
DO $$
BEGIN
    IF NOT (SELECT ausente FROM sga.inscriptos_fecha_final((SELECT f1_b FROM fin_ids))) THEN
        RAISE EXCEPTION 'Finales: el alumno debería figurar ausente';
    END IF;
    IF (SELECT sin_nota FROM sga.mesas_de_final_docente() WHERE examen_final_id = (SELECT f1_b FROM fin_ids)) <> 0 THEN
        RAISE EXCEPTION 'Finales: un ausente no queda pendiente de nota';
    END IF;
END;
$$;

-- Ya usó una fecha del turno (ausente): no puede anotarse a la otra
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', f1_a), 'otra fecha de esta materia') FROM fin_ids;

RESET ROLE;
-- Otra fecha en otro turno, ya tomada, con el alumno anotado: 2º intento
INSERT INTO sga.examen_final (curso_id, turno_id, fecha, hora_inicio, hora_fin)
SELECT curso_id, (SELECT id FROM sga.turno_examen WHERE nombre = 'Turno cerrado Fin'), sga.hoy() - 2, TIME '09:00', TIME '12:00'
FROM sga.examen_final WHERE id = (SELECT f1_a FROM fin_ids);
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT ic.id, ef.id, 2 FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id
JOIN sga.curso c ON c.id = ic.curso_id JOIN sga.materia m ON m.id = c.materia_id,
sga.examen_final ef WHERE l.numero_legajo = 'FIN-1' AND m.codigo = 'FIN.01' AND ef.fecha = sga.hoy() - 2
  AND ef.curso_id = (SELECT curso_id FROM sga.examen_final WHERE id = (SELECT f1_a FROM fin_ids));
SET LOCAL ROLE authenticated;

-- Con una nota pendiente no se puede anotar a otra fecha
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error(format('SELECT sga.inscribirse_final(%s)', futuro), 'abre el') FROM fin_ids;

SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000002"}';
SELECT sga.cargar_nota_final(i.inscripcion_id, 9)
FROM sga.examen_final ef, LATERAL sga.inscriptos_fecha_final(ef.id) i WHERE ef.fecha = sga.hoy() - 2;

RESET ROLE;
DO $$
BEGIN
    IF (SELECT ic.estado FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id
        JOIN sga.curso c ON c.id = ic.curso_id JOIN sga.materia m ON m.id = c.materia_id
        WHERE l.numero_legajo = 'FIN-1' AND m.codigo = 'FIN.01') <> 'APROBADA' THEN
        RAISE EXCEPTION 'Finales: FIN.01 debería quedar aprobada';
    END IF;
    IF (SELECT numero_intento FROM sga.inscripcion_examen_final ief JOIN sga.examen_final ef ON ef.id = ief.examen_final_id
        WHERE ef.fecha = sga.hoy() - 2) <> 2 THEN
        RAISE EXCEPTION 'Finales: el ausente debería contar como intento (este es el 2º)';
    END IF;
END;
$$;

-- Con FIN.01 aprobada ya puede anotarse a FIN.02
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "eeeeeeee-0000-0000-0000-000000000001"}';
SELECT sga.inscribirse_final(f2) FROM fin_ids;

-- Ausente en el 3er intento: la cursada queda desaprobada
RESET ROLE;
INSERT INTO sga.examen_final (curso_id, turno_id, fecha, hora_inicio, hora_fin)
SELECT ef.curso_id, (SELECT id FROM sga.turno_examen WHERE nombre = 'Turno cerrado Fin'), sga.hoy() - x.d, TIME '09:00', TIME '12:00'
FROM sga.examen_final ef, (VALUES (25), (24), (23)) AS x (d) WHERE ef.id = (SELECT f2 FROM fin_ids);
DELETE FROM sga.inscripcion_examen_final WHERE examen_final_id = (SELECT f2 FROM fin_ids);
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento, nota_final, ausente)
SELECT ic.id, ef.id, x.n, x.nota, x.ausente
FROM (VALUES (1, 25, 2::NUMERIC, FALSE), (2, 24, NULL, TRUE), (3, 23, NULL, TRUE)) AS x (n, d, nota, ausente)
JOIN sga.examen_final ef ON ef.fecha = sga.hoy() - x.d AND ef.curso_id = (SELECT curso_id FROM sga.examen_final WHERE id = (SELECT f2 FROM fin_ids))
JOIN sga.inscripcion_curso ic ON ic.curso_id = ef.curso_id
JOIN sga.legajo l ON l.id = ic.legajo_id AND l.numero_legajo = 'FIN-1'
ORDER BY x.n;
DO $$
BEGIN
    IF (SELECT ic.estado FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id
        JOIN sga.curso c ON c.id = ic.curso_id JOIN sga.materia m ON m.id = c.materia_id
        WHERE l.numero_legajo = 'FIN-1' AND m.codigo = 'FIN.02') <> 'DESAPROBADA' THEN
        RAISE EXCEPTION 'Finales: un ausente en el 3er intento debería desaprobar la cursada';
    END IF;
END;
$$;

ROLLBACK;
