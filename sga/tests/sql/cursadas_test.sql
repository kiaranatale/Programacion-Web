-- Prueba de la inscripción a cursadas (20261013000000_inscripcion_cursadas).
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Cur2');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Cur2');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'CU2', 'Carrera de Prueba Cur2', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Cur2';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-CU2', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'CU2';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT x.c, 'Materia ' || x.c, d.id, 6 FROM sga.departamento d,
     (VALUES ('CU2.01'), ('CU2.02'), ('CU2.03'), ('CU2.04'), ('CU2.99')) AS x (c)
WHERE d.nombre = 'Departamento de Prueba Cur2';
-- Todas del plan salvo CU2.99; CU2.03 pide CU2.01 regular para cursar
INSERT INTO sga.plan_materia (plan_id, materia_id)
SELECT pl.id, m.id FROM sga.plan_estudio pl, sga.materia m
WHERE pl.codigo = 'PLN-CU2' AND m.codigo IN ('CU2.01', 'CU2.02', 'CU2.03', 'CU2.04');
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT pl.id, m3.id, m1.id, 'PARA_CURSAR', 'REGULAR' FROM sga.plan_estudio pl, sga.materia m1, sga.materia m3
WHERE pl.codigo = 'PLN-CU2' AND m1.codigo = 'CU2.01' AND m3.codigo = 'CU2.03';

-- Cuatrimestre con inscripción abierta ('X1') y otro cerrado ('X0')
INSERT INTO sga.periodo_inscripcion_cursada (anio, periodo, desde, hasta) VALUES
    (2030, 'X1', sga.hoy() - 1, sga.hoy() + 10),
    (2030, 'X0', sga.hoy() - 30, sga.hoy() - 10);
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT m.id, 2030, x.p, DATE '2030-03-01', DATE '2030-07-01'
FROM sga.materia m JOIN (VALUES ('CU2.01', 'X1'), ('CU2.02', 'X1'), ('CU2.03', 'X1'), ('CU2.04', 'X0'), ('CU2.99', 'X1')) AS x (c, p) ON x.c = m.codigo;
-- CU2.01: A (cupo 1) y B; CU2.02: A, superpuesta con CU2.01 B
INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, x.n, x.cupo FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
JOIN (VALUES ('CU2.01', 'A', 1), ('CU2.01', 'B', 30), ('CU2.02', 'A', 30), ('CU2.03', 'A', 30), ('CU2.04', 'A', 30), ('CU2.99', 'A', 30)) AS x (c, n, cupo)
  ON x.c = m.codigo;
INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin)
SELECT co.id, x.d::sga.dia_semana, x.i, x.f FROM sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
JOIN (VALUES ('CU2.01', 'A', 'LUNES', TIME '09:00', TIME '12:00'),
             ('CU2.01', 'B', 'MARTES', TIME '14:00', TIME '17:00'),
             ('CU2.02', 'A', 'MARTES', TIME '16:00', TIME '19:00')) AS x (c, n, d, i, f)
  ON x.c = m.codigo AND x.n = co.nombre;

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('ffffffff-0000-0000-0000-00000000000' || n)::UUID, 'p' || n || '.cu2@test.local', now() FROM generate_series(1, 2) AS n;
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
SELECT 'DNI', '9910000' || n, 'Persona' || n, 'Cu2', 'p' || n || '.cu2@test.local' FROM generate_series(1, 2) AS n;
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'CU2-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.mail_institucional LIKE '%.cu2@test.local' AND pl.codigo = 'PLN-CU2';

CREATE TEMP TABLE cu2 AS
SELECT co.id, m.codigo || '-' || co.nombre AS clave FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo LIKE 'CU2.%';
GRANT SELECT ON cu2 TO authenticated;

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
CREATE FUNCTION pg_temp.com(p TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM cu2 WHERE clave = p $$;
GRANT EXECUTE ON FUNCTION pg_temp.com(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- ---------- Alumno 2 ocupa el único lugar de CU2.01 A ----------
SET LOCAL request.jwt.claims TO '{"sub": "ffffffff-0000-0000-0000-000000000002"}';
SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-A'));

-- ---------- Alumno 1 ----------
SET LOCAL request.jwt.claims TO '{"sub": "ffffffff-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-A'))$$, 'No quedan vacantes');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.04-A'))$$, 'cerró el');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.99-A'))$$, 'no es de tu plan');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.03-A'))$$, 'correlativas: CU2.01');

SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-B'));
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-B'))$$, 'Ya estás inscripto en esta comisión');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-A'))$$, 'comisión B (date de baja');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.02-A'))$$, 'Se superpone con el horario de CU2.01');

DO $$
BEGIN
    IF (SELECT count(*) FROM sga.cursadas_para_mi() WHERE codigo LIKE 'CU2.%') <> 4 THEN
        RAISE EXCEPTION 'Cursadas: debería ver las 4 comisiones de su plan con inscripción abierta (no la del cuatrimestre cerrado hace más de una semana)';
    END IF;
    IF (SELECT inscripcion_id FROM sga.cursadas_para_mi() WHERE codigo = 'CU2.01' AND comision = 'B') IS NULL THEN
        RAISE EXCEPTION 'Cursadas: debería figurar inscripto en CU2.01 B';
    END IF;
END;
$$;

-- Baja: libera el horario y puede tomar CU2.02
SELECT sga.desinscribirse_cursada((SELECT inscripcion_id FROM sga.cursadas_para_mi() WHERE codigo = 'CU2.01' AND comision = 'B'));
SELECT sga.inscribirse_cursada(pg_temp.com('CU2.02-A'));

-- Con CU2.01 regular (cursada aprobada) puede cursar CU2.03
RESET ROLE;
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2029, 'X1', DATE '2029-03-01', DATE '2029-07-01' FROM sga.materia WHERE codigo = 'CU2.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'CU2.01' AND c.anio = 2029;
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado, nota_cursada)
SELECT l.id, c.id, co.id, 'CURSADA_APROBADA', 7 FROM sga.legajo l, sga.curso c
JOIN sga.materia m ON m.id = c.materia_id JOIN sga.comision co ON co.curso_id = c.id
WHERE l.numero_legajo = 'CU2-1' AND m.codigo = 'CU2.01' AND c.anio = 2029;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "ffffffff-0000-0000-0000-000000000001"}';
SELECT sga.inscribirse_cursada(pg_temp.com('CU2.03-A'));
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_cursada(pg_temp.com('CU2.01-B'))$$, 'te falta el final');

-- El alumno 2 no puede dar de baja la inscripción de otro
SET LOCAL request.jwt.claims TO '{"sub": "ffffffff-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error(format('SELECT sga.desinscribirse_cursada(%s)', ic.id), 'No estás inscripto')
FROM sga.inscripcion_curso ic WHERE ic.comision_id = pg_temp.com('CU2.03-A');

ROLLBACK;
