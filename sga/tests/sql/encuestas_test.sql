-- Prueba de Encuestas y Autoridades (20261009000000_autoridades_encuestas):
-- quién responde, una sola vez, anonimato, resultados y cierre. Requiere
-- Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Enc');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Enc');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'ENC', 'Carrera de Prueba Enc', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Enc';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-ENC', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'ENC';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'ENC.01', 'Materia de Prueba Enc', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Enc';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, 'ENC', DATE '2026-08-01', DATE '2026-12-01' FROM sga.materia WHERE codigo = 'ENC.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'ENC.01';

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('bbbbbbbb-0000-0000-0000-00000000000' || n)::UUID, 'p' || n || '.enc@test.local', now()
FROM generate_series(1, 6) AS n;
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
SELECT 'DNI', '9600000' || n, 'Persona' || n, 'Enc', 'p' || n || '.enc@test.local'
FROM generate_series(1, 6) AS n;
-- p1..p3 alumnos de la comisión, p4 alumno de otra cosa, p5 docente, p6 admin
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT p.id, CASE WHEN p.nro_documento <= '96000004' THEN 'ALUMNO' WHEN p.nro_documento = '96000005' THEN 'DOCENTE' ELSE 'ADMINISTRATIVO' END::sga.tipo_rol_persona
FROM sga.persona p WHERE p.mail_institucional LIKE '%.enc@test.local';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'ENC-' || right(p.nro_documento, 1), pl.id
FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('96000001', '96000002', '96000003', '96000004') AND pl.codigo = 'PLN-ENC';
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento = '96000005';
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, co.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id,
     sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE p.nro_documento = '96000005' AND m.codigo = 'ENC.01';
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id
FROM sga.legajo l, sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE l.numero_legajo IN ('ENC-1', 'ENC-2', 'ENC-3') AND m.codigo = 'ENC.01';

-- Autoridad: la ve cualquiera con su nombre
INSERT INTO sga.cargo_institucional (nombre) VALUES ('Cargo de Prueba Enc');
INSERT INTO sga.autoridad (persona_id, cargo_institucional_id, fecha_desde)
SELECT p.id, c.id, DATE '2020-01-01' FROM sga.persona p, sga.cargo_institucional c
WHERE p.nro_documento = '96000006' AND c.nombre = 'Cargo de Prueba Enc';

CREATE TEMP TABLE enc_ids (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON enc_ids TO authenticated;

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

-- Responde con 5 en las preguntas de escala y un texto en las de texto
CREATE FUNCTION pg_temp.respuestas(p_encuesta INTEGER, p_valor INTEGER) RETURNS JSONB LANGUAGE sql AS $$
    SELECT jsonb_object_agg(id::TEXT, CASE WHEN tipo = 'ESCALA' THEN to_jsonb(p_valor) ELSE to_jsonb('Comentario ' || p_valor) END)
    FROM sga.encuesta_pregunta WHERE encuesta_id = p_encuesta;
$$;
GRANT EXECUTE ON FUNCTION pg_temp.respuestas(INTEGER, INTEGER) TO authenticated;

SET LOCAL ROLE authenticated;

-- ---------- Administración crea las encuestas ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000006"}';

DO $$
BEGIN
    IF sga.crear_encuestas_desempeno('Desempeño de prueba Enc', sga.hoy() - 1, sga.hoy() + 10) < 1 THEN
        RAISE EXCEPTION 'Encuestas: no se crearon encuestas de desempeño';
    END IF;
    -- Volver a generarlas no las duplica
    PERFORM sga.crear_encuestas_desempeno('Desempeño de prueba Enc', sga.hoy() - 1, sga.hoy() + 10);
    INSERT INTO enc_ids
    SELECT 'desempeno', id FROM sga.encuestas_resumen() WHERE nombre = 'Desempeño de prueba Enc' AND sobre LIKE 'Enc, Persona5%';
    IF (SELECT count(*) FROM sga.encuestas_resumen() WHERE nombre = 'Desempeño de prueba Enc' AND sobre LIKE 'Enc, Persona5%') <> 1 THEN
        RAISE EXCEPTION 'Encuestas: debería haber una sola encuesta para el docente de prueba';
    END IF;
    INSERT INTO enc_ids VALUES ('general', sga.crear_encuesta('General de prueba Enc', NULL, sga.hoy(), sga.hoy() + 5,
        '[{"texto": "¿Qué tal?", "tipo": "ESCALA"}]'));
    IF NOT EXISTS (SELECT 1 FROM sga.autoridad_listado WHERE cargo = 'Cargo de Prueba Enc' AND apellido = 'Enc' AND vigente) THEN
        RAISE EXCEPTION 'Autoridades: no se ve la autoridad vigente';
    END IF;
END;
$$;
SELECT pg_temp.espera_error($$SELECT sga.crear_encuesta('Sin preguntas', NULL, sga.hoy(), sga.hoy(), '[]')$$, 'al menos una pregunta');

-- ---------- Alumnos 1 a 3 responden la de desempeño ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000001"}';
DO $$
DECLARE v_id INTEGER := (SELECT id FROM enc_ids WHERE clave = 'desempeno');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sga.encuestas_para_mi() WHERE id = v_id AND estado = 'ACTIVA' AND NOT respondida) THEN
        RAISE EXCEPTION 'Encuestas: el alumno debería tener la encuesta pendiente';
    END IF;
    PERFORM sga.responder_encuesta(v_id, pg_temp.respuestas(v_id, 5));
    IF NOT (SELECT respondida FROM sga.encuestas_para_mi() WHERE id = v_id) THEN
        RAISE EXCEPTION 'Encuestas: no quedó como respondida';
    END IF;
END;
$$;
SELECT pg_temp.espera_error(format('SELECT sga.responder_encuesta(%s, pg_temp.respuestas(%s, 4))', id, id), 'Ya respondiste') FROM enc_ids WHERE clave = 'desempeno';
-- Anonimato: nadie lee las respuestas directamente
SELECT pg_temp.espera_error('SELECT * FROM sga.encuesta_respuesta', 'permission denied');
SELECT pg_temp.espera_error(format('SELECT * FROM sga.resultados_encuesta(%s)', id), 'no están disponibles') FROM enc_ids WHERE clave = 'desempeno';

SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000002"}';
-- Falta una de escala
SELECT pg_temp.espera_error(format('SELECT sga.responder_encuesta(%s, %L)', id, '{}'), 'del 1 al 5') FROM enc_ids WHERE clave = 'desempeno';
SELECT pg_temp.espera_error(format('SELECT sga.responder_encuesta(%s, pg_temp.respuestas(%s, 7))', id, id), 'del 1 al 5') FROM enc_ids WHERE clave = 'desempeno';
SELECT sga.responder_encuesta(id, pg_temp.respuestas(id, 3)) FROM enc_ids WHERE clave = 'desempeno';

-- ---------- Docente: todavía no ve resultados (encuesta abierta) ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000005"}';
SELECT pg_temp.espera_error(format('SELECT * FROM sga.resultados_encuesta(%s)', id), 'no están disponibles') FROM enc_ids WHERE clave = 'desempeno';
DO $$
BEGIN
    IF (SELECT respuestas FROM sga.encuestas_resumen() WHERE id = (SELECT id FROM enc_ids WHERE clave = 'desempeno')) <> 2 THEN
        RAISE EXCEPTION 'Encuestas: el docente debería ver 2 respuestas en el resumen';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.encuestas_resumen() WHERE id = (SELECT id FROM enc_ids WHERE clave = 'general')) THEN
        RAISE EXCEPTION 'Encuestas: el docente no debería ver las encuestas generales en su resumen';
    END IF;
END;
$$;

-- ---------- Alumno 4: no es de la comisión; sí responde la general ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000004"}';
SELECT pg_temp.espera_error(format('SELECT sga.responder_encuesta(%s, pg_temp.respuestas(%s, 4))', id, id), 'no es para vos') FROM enc_ids WHERE clave = 'desempeno';
SELECT sga.responder_encuesta(id, pg_temp.respuestas(id, 4)) FROM enc_ids WHERE clave = 'general';

-- ---------- Alumno 3 responde; Administración cierra ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000003"}';
SELECT sga.responder_encuesta(id, pg_temp.respuestas(id, 4)) FROM enc_ids WHERE clave = 'desempeno';

SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000006"}';
DO $$
DECLARE v_id INTEGER := (SELECT id FROM enc_ids WHERE clave = 'desempeno');
BEGIN
    IF (SELECT promedio FROM sga.resultados_encuesta(v_id) WHERE orden = 1) <> 4.00
        OR (SELECT distribucion FROM sga.resultados_encuesta(v_id) WHERE orden = 1) <> ARRAY[0, 0, 1, 1, 1] THEN
        RAISE EXCEPTION 'Encuestas: resultados de escala inesperados';
    END IF;
    IF (SELECT cardinality(textos) FROM sga.resultados_encuesta(v_id) WHERE tipo = 'TEXTO') <> 3 THEN
        RAISE EXCEPTION 'Encuestas: deberían verse los 3 comentarios';
    END IF;
    PERFORM sga.finalizar_encuesta(v_id);
END;
$$;

-- Cerrada: ya no se responde, y se calculó la evaluación del docente
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error(format('SELECT sga.responder_encuesta(%s, pg_temp.respuestas(%s, 4))', id, id), 'no está abierta') FROM enc_ids WHERE clave = 'desempeno';

-- ---------- Docente: con la encuesta cerrada y 3 respuestas, ve los resultados ----------
SET LOCAL request.jwt.claims TO '{"sub": "bbbbbbbb-0000-0000-0000-000000000005"}';
DO $$
BEGIN
    IF (SELECT promedio FROM sga.resultados_encuesta((SELECT id FROM enc_ids WHERE clave = 'desempeno')) WHERE orden = 5) <> 4.00 THEN
        RAISE EXCEPTION 'Encuestas: el docente debería ver los resultados al cerrarse';
    END IF;
END;
$$;
RESET ROLE;
DO $$
BEGIN
    IF (SELECT ev.calificacion FROM sga.evaluacion_docente ev
        JOIN sga.encuesta e ON e.docente_comision_id = ev.docente_comision_id
        WHERE e.id = (SELECT id FROM enc_ids WHERE clave = 'desempeno')) <> 4.00 THEN
        RAISE EXCEPTION 'Encuestas: no se calculó la evaluación docente al cerrar';
    END IF;
    -- La respuesta guardada no tiene persona
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'sga' AND table_name = 'encuesta_respuesta' AND column_name = 'persona_id') THEN
        RAISE EXCEPTION 'Encuestas: encuesta_respuesta no debería guardar la persona';
    END IF;
END;
$$;

ROLLBACK;
