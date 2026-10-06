-- Prueba de Intercambios (20261018000000_intercambios): requisitos,
-- postulación, retiro, selección y publicación de resultados.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Int');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Int');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'INT', 'Carrera de Prueba Int', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Int';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-INT', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'INT';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'INT.01', 'Materia INT.01', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Int';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('a1a1a1a1-0000-0000-0000-000000000001', 'a1.int@test.local', now()),
    ('a1a1a1a1-0000-0000-0000-000000000002', 'a2.int@test.local', now()),
    ('a1a1a1a1-0000-0000-0000-000000000003', 'a3.int@test.local', now()),
    ('a1a1a1a1-0000-0000-0000-000000000009', 'admin.int@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99500001', 'Alumno1', 'Int', 'a1.int@test.local'),
    ('DNI', '99500002', 'Alumno2', 'Int', 'a2.int@test.local'),
    ('DNI', '99500003', 'Alumno3', 'Int', 'a3.int@test.local'),
    ('DNI', '99500009', 'Admin', 'Int', 'admin.int@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99500009';
-- Alumnos 1 y 3: 6 créditos aprobados y promedio 8; alumno 2: sin créditos
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id, rendimiento_academico)
SELECT p.id, 'INT-' || right(p.nro_documento, 1), pl.id, CASE WHEN p.nro_documento = '99500002' THEN NULL ELSE 8 END
FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99500001', '99500002', '99500003') AND pl.codigo = 'PLN-INT';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2025, '1C', DATE '2025-03-01', DATE '2025-07-01' FROM sga.materia WHERE codigo = 'INT.01';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'INT.01';
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado, nota_cursada, nota_definitiva)
SELECT l.id, co.curso_id, co.id, 'APROBADA', 8, 8 FROM sga.legajo l, sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE l.numero_legajo IN ('INT-1', 'INT-3') AND m.codigo = 'INT.01';

INSERT INTO sga.convocatoria_intercambio (universidad, pais, anio, periodo, vacantes, creditos_minimos, promedio_minimo, postulacion_desde, postulacion_hasta)
VALUES ('Universidad de Prueba Int', 'Prueba', 2027, '2C', 1, 6, 7, sga.hoy() - 1, sga.hoy() + 5),
       ('Universidad Futura Int', 'Prueba', 2027, '2C', 2, 0, NULL, sga.hoy() + 10, sga.hoy() + 20);

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
CREATE FUNCTION pg_temp.conv(u TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM sga.convocatoria_intercambio WHERE universidad = u $$;
GRANT EXECUTE ON FUNCTION pg_temp.conv(TEXT) TO authenticated;
CREATE FUNCTION pg_temp.post(leg TEXT) RETURNS INTEGER LANGUAGE sql SECURITY DEFINER AS $$
    SELECT p.id FROM sga.postulacion_intercambio p JOIN sga.legajo l ON l.id = p.legajo_id WHERE l.numero_legajo = leg
$$;
GRANT EXECUTE ON FUNCTION pg_temp.post(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- Alumno 1: cumple; se postula; no puede en la futura ni dos veces
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), 'corta')$$, '50 caracteres');
SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), repeat('Quiero conocer otra cultura. ', 3));
SELECT pg_temp.espera_error($$SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), repeat('x', 60))$$, 'Ya te postulaste');
SELECT pg_temp.espera_error($$SELECT sga.postular_intercambio(pg_temp.conv('Universidad Futura Int'), repeat('x', 60))$$, 'abre el');
SELECT pg_temp.espera_error($$SELECT * FROM sga.postulantes_intercambio(pg_temp.conv('Universidad de Prueba Int'))$$, 'Solo Administración');
DO $$
BEGIN
    IF (SELECT resultado FROM sga.intercambios_para_mi() WHERE universidad = 'Universidad de Prueba Int') <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Intercambios: la postulación nueva queda pendiente';
    END IF;
    IF (SELECT count(*) FROM sga.postulacion_intercambio) <> 0 THEN
        RAISE EXCEPTION 'Intercambios: el alumno no lee la tabla de postulaciones';
    END IF;
END;
$$;

-- Alumno 2: no cumple los créditos
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000002"}';
DO $$
BEGIN
    IF (SELECT motivo FROM sga.intercambios_para_mi() WHERE universidad = 'Universidad de Prueba Int') NOT LIKE 'Pide 6 créditos%' THEN
        RAISE EXCEPTION 'Intercambios: debería explicar que faltan créditos';
    END IF;
END;
$$;
SELECT pg_temp.espera_error($$SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), repeat('x', 60))$$, 'créditos');
SELECT pg_temp.espera_error($$SELECT sga.retirar_postulacion_intercambio(pg_temp.post('INT-1'))$$, 'No tenés esa postulación');

-- Alumno 3: se postula y se retira; vuelve a postularse
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000003"}';
SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), repeat('Me interesa la universidad. ', 3));
SELECT sga.retirar_postulacion_intercambio(pg_temp.post('INT-3'));
SELECT sga.postular_intercambio(pg_temp.conv('Universidad de Prueba Int'), repeat('Me interesa la universidad. ', 3));

-- Administración: no selecciona antes del cierre; cierra, selecciona y publica
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000009"}';
SELECT pg_temp.espera_error($$SELECT sga.marcar_postulacion_intercambio(pg_temp.post('INT-1'), TRUE)$$, 'cuando cierra');
UPDATE sga.convocatoria_intercambio SET postulacion_desde = sga.hoy() - 10, postulacion_hasta = sga.hoy() - 1
WHERE universidad = 'Universidad de Prueba Int';
SELECT sga.marcar_postulacion_intercambio(pg_temp.post('INT-1'), TRUE);
SELECT sga.marcar_postulacion_intercambio(pg_temp.post('INT-3'), TRUE);
SELECT pg_temp.espera_error($$SELECT sga.publicar_resultados_intercambio(pg_temp.conv('Universidad de Prueba Int'))$$, 'vacantes');
SELECT sga.marcar_postulacion_intercambio(pg_temp.post('INT-3'), FALSE);
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.postulantes_intercambio(pg_temp.conv('Universidad de Prueba Int'))) <> 2 THEN
        RAISE EXCEPTION 'Intercambios: Administración debería ver 2 postulantes';
    END IF;
END;
$$;

-- Antes de publicar, el alumno 3 sigue viendo "pendiente"
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000003"}';
DO $$
BEGIN
    IF (SELECT resultado FROM sga.intercambios_para_mi() WHERE universidad = 'Universidad de Prueba Int') <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Intercambios: el resultado no se ve antes de publicarlo';
    END IF;
END;
$$;
SELECT pg_temp.espera_error($$SELECT sga.retirar_postulacion_intercambio(pg_temp.post('INT-3'))$$, 'ya cerró');

SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000009"}';
DO $$
BEGIN
    IF sga.publicar_resultados_intercambio(pg_temp.conv('Universidad de Prueba Int')) <> 1 THEN
        RAISE EXCEPTION 'Intercambios: debería haber 1 seleccionado';
    END IF;
END;
$$;
SELECT pg_temp.espera_error($$SELECT sga.marcar_postulacion_intercambio(pg_temp.post('INT-1'), FALSE)$$, 'ya están publicados');

SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000001"}';
DO $$
BEGIN
    IF (SELECT resultado FROM sga.intercambios_para_mi() WHERE universidad = 'Universidad de Prueba Int') <> 'SELECCIONADA' THEN
        RAISE EXCEPTION 'Intercambios: el alumno 1 debería ver que quedó seleccionado';
    END IF;
    IF (SELECT count(*) FROM sga.notificacion WHERE tipo = 'INTERCAMBIO' AND mensaje LIKE '%Quedaste seleccionado%') <> 1 THEN
        RAISE EXCEPTION 'Intercambios: el alumno 1 debería tener la notificación de seleccionado';
    END IF;
END;
$$;
SET LOCAL request.jwt.claims TO '{"sub": "a1a1a1a1-0000-0000-0000-000000000003"}';
DO $$
BEGIN
    IF (SELECT resultado FROM sga.intercambios_para_mi() WHERE universidad = 'Universidad de Prueba Int') <> 'NO_SELECCIONADA' THEN
        RAISE EXCEPTION 'Intercambios: el alumno 3 debería ver que no quedó seleccionado';
    END IF;
END;
$$;

ROLLBACK;
