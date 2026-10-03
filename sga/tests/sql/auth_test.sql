-- Prueba del vínculo Auth ↔ persona y de la carga de notas de un docente
-- con RLS activo (20261002000000_auth_vinculo_persona.sql). Requiere
-- correr contra Supabase (schema `auth` y roles `authenticated`).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

-- Catálogo propio del test
INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Auth');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Auth');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'AUT', 'Carrera de Prueba Auth', id FROM sga.escuela
WHERE nombre = 'Escuela de Prueba Auth';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-AUT', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'AUT';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'AUT.01', 'Materia de Prueba Auth', id, 6 FROM sga.departamento
WHERE nombre = 'Departamento de Prueba Auth';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'AUT', DATE '2026-08-01', DATE '2026-12-01'
FROM sga.materia WHERE codigo = 'AUT.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'AUT.01';

-- Orden 1: la persona existe antes que el usuario de Auth
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '91000001', 'Alumno', 'Auth', 'alumno.auth@test.local');

INSERT INTO auth.users (id, email, email_confirmed_at)
VALUES ('44444444-4444-4444-4444-444444444444', 'Alumno.Auth@test.local', now());

-- Orden 2: el usuario de Auth existe antes que la persona
INSERT INTO auth.users (id, email, email_confirmed_at)
VALUES ('55555555-5555-5555-5555-555555555555', 'docente.auth@test.local', now());

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '91000002', 'Docente', 'Auth', 'docente.auth@test.local');

-- Un mail sin confirmar no se vincula
INSERT INTO auth.users (id, email)
VALUES ('66666666-6666-6666-6666-666666666666', 'sinconfirmar.auth@test.local');

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES ('DNI', '91000003', 'Sin', 'Confirmar', 'sinconfirmar.auth@test.local');

DO $$
BEGIN
    IF (SELECT auth_user_id FROM sga.persona WHERE nro_documento = '91000001')
        IS DISTINCT FROM '44444444-4444-4444-4444-444444444444' THEN
        RAISE EXCEPTION 'Auth: la persona existente no se vinculó al crear su usuario';
    END IF;
    IF (SELECT auth_user_id FROM sga.persona WHERE nro_documento = '91000002')
        IS DISTINCT FROM '55555555-5555-5555-5555-555555555555' THEN
        RAISE EXCEPTION 'Auth: la persona nueva no se vinculó con el usuario existente';
    END IF;
    IF (SELECT auth_user_id FROM sga.persona WHERE nro_documento = '91000003') IS NOT NULL THEN
        RAISE EXCEPTION 'Auth: no se debería vincular un mail sin confirmar';
    END IF;
END;
$$;

-- Cursada: alumno inscripto en la comisión que dicta el docente
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'DOCENTE' FROM sga.persona WHERE nro_documento = '91000002';
INSERT INTO sga.docente (persona_id)
SELECT id FROM sga.persona WHERE nro_documento = '91000002';

CREATE TEMP VIEW auth_comision AS
SELECT co.id, co.curso_id FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id
JOIN sga.materia m ON m.id = c.materia_id
WHERE m.codigo = 'AUT.01';

INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, ac.id
FROM sga.docente d
JOIN sga.persona p ON p.id = d.persona_id
CROSS JOIN auth_comision ac
WHERE p.nro_documento = '91000002';

INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'AUT-001', pl.id
FROM sga.persona p
JOIN sga.plan_estudio pl ON pl.codigo = 'PLN-AUT'
WHERE p.nro_documento = '91000001';

INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, nota_cursada)
SELECT l.id, ac.curso_id, ac.id, 8.00
FROM sga.legajo l CROSS JOIN auth_comision ac
WHERE l.numero_legajo = 'AUT-001';

INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin)
SELECT curso_id, DATE '2026-12-15', '09:00', '12:00' FROM auth_comision;

INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT ic.id, ef.id, 1
FROM sga.inscripcion_curso ic
JOIN sga.legajo l ON l.id = ic.legajo_id
JOIN sga.examen_final ef ON ef.curso_id = ic.curso_id
WHERE l.numero_legajo = 'AUT-001';

-- El docente carga la nota del final con su propia sesión (RLS activo)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "55555555-5555-5555-5555-555555555555"}';

UPDATE sga.inscripcion_examen_final ief
SET nota_final = 6.00
FROM sga.inscripcion_curso ic
JOIN sga.legajo l ON l.id = ic.legajo_id
WHERE ief.inscripcion_curso_id = ic.id
  AND l.numero_legajo = 'AUT-001';

RESET ROLE;
RESET request.jwt.claims;

DO $$
DECLARE
    v_nota_final NUMERIC(5,2);
    v_definitiva NUMERIC(5,2);
    v_rendimiento NUMERIC(5,2);
BEGIN
    SELECT ief.nota_final, ic.nota_definitiva, l.rendimiento_academico
    INTO v_nota_final, v_definitiva, v_rendimiento
    FROM sga.legajo l
    JOIN sga.inscripcion_curso ic ON ic.legajo_id = l.id
    JOIN sga.inscripcion_examen_final ief ON ief.inscripcion_curso_id = ic.id
    WHERE l.numero_legajo = 'AUT-001';

    IF v_nota_final IS DISTINCT FROM 6.00 THEN
        RAISE EXCEPTION 'RLS: el docente no pudo cargar la nota del final (quedó %)', v_nota_final;
    END IF;
    IF v_definitiva IS DISTINCT FROM 7.00 THEN
        RAISE EXCEPTION 'Nota definitiva esperada 7.00, obtenida %', v_definitiva;
    END IF;
    IF v_rendimiento IS DISTINCT FROM 7.00 THEN
        RAISE EXCEPTION 'El rendimiento del legajo no se actualizó con la nota del docente (quedó %)', v_rendimiento;
    END IF;
END;
$$;

ROLLBACK;

SELECT 'sga auth test passed' AS result;
