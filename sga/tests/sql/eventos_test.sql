-- Prueba de la inscripción a eventos académicos
-- (20261014000000_eventos_inscripcion). Requiere Supabase (schema auth y
-- roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('abababab-0000-0000-0000-00000000000' || n)::UUID, 'p' || n || '.evt@test.local', now() FROM generate_series(1, 3) AS n;
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
SELECT 'DNI', '9920000' || n, 'Persona' || n, 'Evt', 'p' || n || '.evt@test.local' FROM generate_series(1, 3) AS n;

INSERT INTO sga.evento_academico (nombre, tipo, fecha, hora_inicio, hora_fin, cupo, con_inscripcion, inscripcion_hasta) VALUES
    ('Taller de prueba Evt', 'Taller', sga.hoy() + 7, '18:00', '20:00', 2, TRUE, NULL),
    ('Charla cerrada Evt', 'Charla', sga.hoy() + 7, '10:00', '11:00', NULL, TRUE, now() - INTERVAL '1 hour'),
    ('Jornada sin inscripción Evt', 'Jornada', sga.hoy() + 7, '12:00', '13:00', NULL, FALSE, NULL);

CREATE TEMP TABLE evt AS SELECT id, nombre FROM sga.evento_academico WHERE nombre LIKE '%Evt';
GRANT SELECT ON evt TO authenticated;

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
CREATE FUNCTION pg_temp.ev(p TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM evt WHERE nombre = p $$;
GRANT EXECUTE ON FUNCTION pg_temp.ev(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

SET LOCAL request.jwt.claims TO '{"sub": "abababab-0000-0000-0000-000000000001"}';
SELECT sga.inscribirse_evento(pg_temp.ev('Taller de prueba Evt'));
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_evento(pg_temp.ev('Taller de prueba Evt'))$$, 'Ya estás anotado');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_evento(pg_temp.ev('Charla cerrada Evt'))$$, 'ya cerró');
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_evento(pg_temp.ev('Jornada sin inscripción Evt'))$$, 'no tiene inscripción');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.eventos_para_mi() WHERE nombre LIKE '%Evt') <> 2 THEN
        RAISE EXCEPTION 'Eventos: deberían listarse solo los 2 eventos con inscripción';
    END IF;
    IF NOT (SELECT inscripto FROM sga.eventos_para_mi() WHERE nombre = 'Taller de prueba Evt') THEN
        RAISE EXCEPTION 'Eventos: debería figurar anotado al taller';
    END IF;
END;
$$;

SET LOCAL request.jwt.claims TO '{"sub": "abababab-0000-0000-0000-000000000002"}';
SELECT sga.inscribirse_evento(pg_temp.ev('Taller de prueba Evt'));
-- No ve quién más se anotó
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.evento_inscripcion WHERE evento_id = pg_temp.ev('Taller de prueba Evt')) <> 1 THEN
        RAISE EXCEPTION 'Eventos: cada uno solo ve su propia inscripción';
    END IF;
END;
$$;

-- Cupo lleno
SET LOCAL request.jwt.claims TO '{"sub": "abababab-0000-0000-0000-000000000003"}';
SELECT pg_temp.espera_error($$SELECT sga.inscribirse_evento(pg_temp.ev('Taller de prueba Evt'))$$, 'No quedan lugares');
SELECT pg_temp.espera_error($$SELECT sga.desinscribirse_evento(pg_temp.ev('Taller de prueba Evt'))$$, 'No estás anotado');

-- Una baja libera el lugar
SET LOCAL request.jwt.claims TO '{"sub": "abababab-0000-0000-0000-000000000001"}';
SELECT sga.desinscribirse_evento(pg_temp.ev('Taller de prueba Evt'));
SET LOCAL request.jwt.claims TO '{"sub": "abababab-0000-0000-0000-000000000003"}';
SELECT sga.inscribirse_evento(pg_temp.ev('Taller de prueba Evt'));

ROLLBACK;
