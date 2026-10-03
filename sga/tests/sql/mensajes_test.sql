-- Prueba de Mensajes (20261008000000_mensajes): a quién puede escribirle
-- cada rol, respuestas, lectura y privacidad. Requiere Supabase (schema
-- auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Msj');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Msj');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'MSJ', 'Carrera de Prueba Msj', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Msj';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-MSJ', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'MSJ';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'MSJ.01', 'Materia de Prueba Msj', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Msj';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'MSJ', DATE '2026-08-01', DATE '2026-12-01' FROM sga.materia WHERE codigo = 'MSJ.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, x.nombre FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
CROSS JOIN (VALUES ('A'), ('B')) AS x (nombre) WHERE m.codigo = 'MSJ.01';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'alumno1.msj@test.local', now()),
    ('aaaaaaaa-0000-0000-0000-000000000002', 'alumno2.msj@test.local', now()),
    ('aaaaaaaa-0000-0000-0000-000000000003', 'alumno3.msj@test.local', now()),
    ('aaaaaaaa-0000-0000-0000-000000000004', 'docente.msj@test.local', now()),
    ('aaaaaaaa-0000-0000-0000-000000000005', 'admin.msj@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '95000001', 'Uno', 'Msj', 'alumno1.msj@test.local'),
    ('DNI', '95000002', 'Dos', 'Msj', 'alumno2.msj@test.local'),
    ('DNI', '95000003', 'Tres', 'Msj', 'alumno3.msj@test.local'),
    ('DNI', '95000004', 'Docente', 'Msj', 'docente.msj@test.local'),
    ('DNI', '95000005', 'Admin', 'Msj', 'admin.msj@test.local');
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT p.id, x.rol::sga.tipo_rol_persona
FROM (VALUES ('95000001', 'ALUMNO'), ('95000002', 'ALUMNO'), ('95000003', 'ALUMNO'),
             ('95000004', 'DOCENTE'), ('95000005', 'ADMINISTRATIVO')) AS x (doc, rol)
JOIN sga.persona p ON p.nro_documento = x.doc;
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'MSJ-' || right(p.nro_documento, 1), pl.id
FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('95000001', '95000002', '95000003') AND pl.codigo = 'PLN-MSJ';
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento = '95000004';

CREATE TEMP VIEW msj_comision AS
SELECT co.id, co.curso_id, co.nombre FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE m.codigo = 'MSJ.01';

-- Alumnos 1 y 2 en A (la dicta el docente), 3 en B
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, mc.curso_id, mc.id
FROM (VALUES ('MSJ-1', 'A'), ('MSJ-2', 'A'), ('MSJ-3', 'B')) AS x (legajo, comision)
JOIN sga.legajo l ON l.numero_legajo = x.legajo
JOIN msj_comision mc ON mc.nombre = x.comision;
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, mc.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id, msj_comision mc
WHERE p.nro_documento = '95000004' AND mc.nombre = 'A';

CREATE TEMP TABLE msj_ids AS
SELECT
    (SELECT id FROM msj_comision WHERE nombre = 'A') AS com_a,
    (SELECT id FROM msj_comision WHERE nombre = 'B') AS com_b,
    (SELECT id FROM sga.carrera WHERE codigo = 'MSJ') AS carrera;
CREATE TEMP TABLE msj_enviados (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT ON msj_ids TO authenticated;
GRANT SELECT, INSERT ON msj_enviados TO authenticated;

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

-- ---------- Docente: a su comisión sí, a otra no ----------
SET LOCAL request.jwt.claims TO '{"sub": "aaaaaaaa-0000-0000-0000-000000000004"}';

INSERT INTO msj_enviados
SELECT 'comision', sga.enviar_mensaje('Parcial', 'El parcial es el viernes.', 'COMISION', com_a) FROM msj_ids;

SELECT pg_temp.espera_error(format('SELECT sga.enviar_mensaje(%L, %L, %L, %s)', 'x', 'x', 'COMISION', com_b), 'comisiones que dictás') FROM msj_ids;
SELECT pg_temp.espera_error(format('SELECT sga.enviar_mensaje(%L, %L, %L, %s)', 'x', 'x', 'CARRERA', carrera), 'Solo Administración') FROM msj_ids;
SELECT pg_temp.espera_error($$SELECT sga.enviar_mensaje('x', 'x', 'TODOS')$$, 'Solo Administración');
-- A un alumno de otra comisión no; a uno propio sí
SELECT pg_temp.espera_error($$SELECT sga.enviar_mensaje('x', 'x', 'PERSONA', NULL, 'alumno3.msj@test.local')$$, 'No podés escribirle');
SELECT sga.enviar_mensaje('Consulta', 'Pasá por la oficina.', 'PERSONA', NULL, 'ALUMNO1.msj@test.local');

DO $$
BEGIN
    IF (SELECT destinatarios FROM sga.mensaje_enviado WHERE asunto = 'Parcial') <> 2 THEN
        RAISE EXCEPTION 'Mensajes: el mensaje a la comisión A debería llegar a sus 2 alumnos';
    END IF;
END;
$$;

-- ---------- Alumno 1: recibe, lee y responde; no inicia mensajes ----------
SET LOCAL request.jwt.claims TO '{"sub": "aaaaaaaa-0000-0000-0000-000000000001"}';

DO $$
DECLARE v_id INTEGER;
BEGIN
    IF (SELECT count(*) FROM sga.mensaje_recibido WHERE leido_en IS NULL AND remitente_apellido = 'Msj') <> 2 THEN
        RAISE EXCEPTION 'Mensajes: el alumno 1 debería tener 2 mensajes sin leer';
    END IF;
    SELECT id INTO v_id FROM sga.mensaje_recibido WHERE asunto = 'Parcial';
    PERFORM sga.marcar_mensaje_leido(v_id);
    IF (SELECT leido_en FROM sga.mensaje_recibido WHERE id = v_id) IS NULL THEN
        RAISE EXCEPTION 'Mensajes: no quedó marcado como leído';
    END IF;
    INSERT INTO msj_enviados VALUES ('respuesta', sga.responder_mensaje(v_id, '¿Entra la unidad 3?'));
    -- No ve quiénes más recibieron el mensaje
    IF (SELECT count(*) FROM sga.mensaje_destinatario WHERE mensaje_id = v_id) <> 1 THEN
        RAISE EXCEPTION 'Mensajes: el alumno solo debería ver su propia fila de destinatario';
    END IF;
END;
$$;

SELECT pg_temp.espera_error($$SELECT sga.enviar_mensaje('x', 'x', 'PERSONA', NULL, 'alumno2.msj@test.local')$$, 'No podés escribirle');
SELECT pg_temp.espera_error($$INSERT INTO sga.mensaje (persona_emisor_id, asunto, cuerpo, destino_descripcion) SELECT id, 'x', 'x', 'x' FROM sga.persona WHERE nro_documento = '95000001'$$, 'row-level security');

-- ---------- Alumno 3: no ve mensajes ajenos ni puede responderlos ----------
SET LOCAL request.jwt.claims TO '{"sub": "aaaaaaaa-0000-0000-0000-000000000003"}';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sga.mensaje WHERE asunto IN ('Parcial', 'Consulta', 'Re: Parcial')) THEN
        RAISE EXCEPTION 'Mensajes: el alumno 3 no debería ver mensajes ajenos';
    END IF;
END;
$$;
SELECT pg_temp.espera_error(format('SELECT sga.responder_mensaje(%s, %L)', id, 'x'), 'Solo podés responder') FROM msj_enviados WHERE clave = 'comision';

-- ---------- Docente: recibe la respuesta y ve cuántos leyeron ----------
SET LOCAL request.jwt.claims TO '{"sub": "aaaaaaaa-0000-0000-0000-000000000004"}';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sga.mensaje_recibido WHERE asunto = 'Re: Parcial' AND remitente_nombre = 'Uno'
                   AND respuesta_a_id = (SELECT id FROM msj_enviados WHERE clave = 'comision')) THEN
        RAISE EXCEPTION 'Mensajes: la respuesta no le llegó al docente';
    END IF;
    IF (SELECT leidos FROM sga.mensaje_enviado WHERE asunto = 'Parcial') <> 1 THEN
        RAISE EXCEPTION 'Mensajes: el docente debería ver 1 de 2 leídos';
    END IF;
END;
$$;

-- ---------- Administración: carrera y todos; no lee mensajes ajenos ----------
SET LOCAL request.jwt.claims TO '{"sub": "aaaaaaaa-0000-0000-0000-000000000005"}';

SELECT sga.enviar_mensaje('Inscripciones', 'Abren el lunes.', 'CARRERA', carrera) FROM msj_ids;
DO $$
BEGIN
    IF (SELECT destinatarios FROM sga.mensaje_enviado WHERE asunto = 'Inscripciones') <> 3 THEN
        RAISE EXCEPTION 'Mensajes: el mensaje a la carrera debería llegar a sus 3 alumnos';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.mensaje WHERE asunto = 'Parcial') THEN
        RAISE EXCEPTION 'Mensajes: Administración no debería leer mensajes ajenos';
    END IF;
END;
$$;
SELECT pg_temp.espera_error($$SELECT sga.enviar_mensaje('x', 'x', 'PERSONA', NULL, 'nadie@test.local')$$, 'No hay ninguna persona');
SELECT pg_temp.espera_error($$SELECT sga.enviar_mensaje(' ', 'x', 'TODOS')$$, 'Completá el asunto');

ROLLBACK;
