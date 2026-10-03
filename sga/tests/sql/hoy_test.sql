-- Prueba de Hoy en el ITBA (20261007000000_hoy_en_el_itba): solo los
-- miembros publican en nombre de su organización, cualquiera comenta, y
-- cada uno borra lo suyo (Administración modera todo). Requiere Supabase
-- (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('99999999-9999-9999-9999-999999999991', 'miembro.hoy@test.local', now()),
    ('99999999-9999-9999-9999-999999999992', 'otro.hoy@test.local', now()),
    ('99999999-9999-9999-9999-999999999993', 'admin.hoy@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '94000001', 'Miembro', 'Hoy', 'miembro.hoy@test.local'),
    ('DNI', '94000002', 'Otro', 'Hoy', 'otro.hoy@test.local'),
    ('DNI', '94000003', 'Admin', 'Hoy', 'admin.hoy@test.local');
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '94000003';

INSERT INTO sga.organizacion (nombre) VALUES ('Organización de Prueba Hoy'), ('Otra Organización de Prueba Hoy');
INSERT INTO sga.organizacion_miembro (organizacion_id, persona_id)
SELECT o.id, p.id FROM sga.organizacion o, sga.persona p
WHERE o.nombre = 'Organización de Prueba Hoy' AND p.nro_documento = '94000001';

CREATE TEMP TABLE hoy_ids AS
SELECT
    (SELECT id FROM sga.organizacion WHERE nombre = 'Organización de Prueba Hoy') AS org,
    (SELECT id FROM sga.organizacion WHERE nombre = 'Otra Organización de Prueba Hoy') AS otra_org,
    (SELECT id FROM sga.persona WHERE nro_documento = '94000001') AS miembro,
    (SELECT id FROM sga.persona WHERE nro_documento = '94000002') AS otro;
GRANT SELECT ON hoy_ids TO authenticated;

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

-- ---------- Miembro: publica en su organización, no en otra ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "99999999-9999-9999-9999-999999999991"}';

INSERT INTO sga.publicacion (organizacion_id, autor_persona_id, tipo, titulo, cuerpo, fecha_evento)
SELECT org, miembro, 'EVENTO', 'Evento de prueba Hoy', 'Texto', DATE '2026-11-01' FROM hoy_ids;

SELECT pg_temp.espera_error(
    format('INSERT INTO sga.publicacion (organizacion_id, autor_persona_id, tipo, titulo, cuerpo) VALUES (%s, %s, %L, %L, %L)',
           otra_org, miembro, 'NOVEDAD', 'No', 'No'),
    'row-level security')
FROM hoy_ids;

-- Un evento necesita fecha
SELECT pg_temp.espera_error(
    format('INSERT INTO sga.publicacion (organizacion_id, autor_persona_id, tipo, titulo, cuerpo) VALUES (%s, %s, %L, %L, %L)',
           org, miembro, 'EVENTO', 'Sin fecha', 'x'),
    'ck_publicacion_evento_fecha')
FROM hoy_ids;

-- ---------- Otro usuario: lee, comenta, no edita ni publica ----------
SET LOCAL request.jwt.claims TO '{"sub": "99999999-9999-9999-9999-999999999992"}';

DO $$
DECLARE v_pub INTEGER; v_editadas INTEGER; v_borradas INTEGER;
BEGIN
    SELECT id INTO v_pub FROM sga.publicacion_listado WHERE titulo = 'Evento de prueba Hoy' AND autor_apellido = 'Hoy' AND NOT puede_editar;
    IF v_pub IS NULL THEN
        RAISE EXCEPTION 'Hoy: otro usuario debería ver la publicación con su autor y sin poder editarla';
    END IF;

    UPDATE sga.publicacion SET titulo = 'Cambiado' WHERE id = v_pub;
    GET DIAGNOSTICS v_editadas = ROW_COUNT;
    DELETE FROM sga.publicacion WHERE id = v_pub;
    GET DIAGNOSTICS v_borradas = ROW_COUNT;
    IF v_editadas > 0 OR v_borradas > 0 THEN
        RAISE EXCEPTION 'Hoy: un usuario que no es miembro no puede editar ni borrar';
    END IF;

    INSERT INTO sga.publicacion_comentario (publicacion_id, autor_persona_id, cuerpo)
    SELECT v_pub, otro, 'Comentario de prueba' FROM hoy_ids;
END;
$$;

SELECT pg_temp.espera_error(
    format('INSERT INTO sga.publicacion_comentario (publicacion_id, autor_persona_id, cuerpo) SELECT id, %s, %L FROM sga.publicacion WHERE titulo = %L',
           miembro, 'Haciéndose pasar', 'Evento de prueba Hoy'),
    'row-level security')
FROM hoy_ids;

-- ---------- Miembro: edita (autor y fecha no cambian), no borra comentarios ajenos ----------
SET LOCAL request.jwt.claims TO '{"sub": "99999999-9999-9999-9999-999999999991"}';

DO $$
BEGIN
    UPDATE sga.publicacion SET titulo = 'Evento de prueba Hoy (editado)', autor_persona_id = NULL
    WHERE titulo = 'Evento de prueba Hoy';
    IF NOT EXISTS (SELECT 1 FROM sga.publicacion_listado
                   WHERE titulo = 'Evento de prueba Hoy (editado)' AND autor_apellido = 'Hoy' AND editada IS NOT NULL) THEN
        RAISE EXCEPTION 'Hoy: el miembro no pudo editar o se perdió el autor';
    END IF;

    DELETE FROM sga.publicacion_comentario WHERE cuerpo = 'Comentario de prueba';
    IF NOT EXISTS (SELECT 1 FROM sga.publicacion_comentario WHERE cuerpo = 'Comentario de prueba') THEN
        RAISE EXCEPTION 'Hoy: el miembro no debería borrar comentarios ajenos';
    END IF;
END;
$$;

-- ---------- Organización inactiva: sus miembros ya no publican ----------
RESET ROLE;
UPDATE sga.organizacion SET activa = FALSE WHERE nombre = 'Organización de Prueba Hoy';
SET LOCAL ROLE authenticated;
SELECT pg_temp.espera_error(
    format('INSERT INTO sga.publicacion (organizacion_id, autor_persona_id, tipo, titulo, cuerpo) VALUES (%s, %s, %L, %L, %L)',
           org, miembro, 'NOVEDAD', 'Inactiva', 'x'),
    'row-level security')
FROM hoy_ids;

-- ---------- Administración: modera ----------
SET LOCAL request.jwt.claims TO '{"sub": "99999999-9999-9999-9999-999999999993"}';
DO $$
BEGIN
    DELETE FROM sga.publicacion_comentario WHERE cuerpo = 'Comentario de prueba';
    DELETE FROM sga.publicacion WHERE titulo = 'Evento de prueba Hoy (editado)';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hoy: Administración debería poder borrar publicaciones';
    END IF;
END;
$$;

ROLLBACK;
