-- =====================================================================
-- Administración → Personas: alta y gestión de alumnos, docentes y
-- administrativos sin tocar SQL.
--
--   - crear_persona(): datos, roles y (si es alumno) legajo en un paso.
--   - asignar_rol() / quitar_rol(): activa o desactiva un rol (no se
--     borra, queda el historial). Un administrativo no se puede quitar
--     su propio rol de Administración.
--   - crear_legajo(): legajo de alumno (una persona tiene uno).
--   - asignar_docente_comision() / quitar_docente_comision(): crea la
--     fila de docente si falta y la vincula a la comisión.
--   - buscar_personas(): búsqueda por nombre, documento, mail o legajo.
--
-- La cuenta de acceso (Supabase Auth) la crea la app con la clave de
-- servicio y manda el mail para elegir contraseña; el trigger de
-- 20261002000000_auth_vinculo_persona la vincula por mail.
-- =====================================================================

CREATE FUNCTION sga.validar_admin()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración gestiona personas' USING ERRCODE = '42501';
    END IF;
END;
$$;

-- Crea la fila de docente de una persona si no la tiene. Devuelve su id.
CREATE FUNCTION sga.asegurar_docente(p_persona_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM sga.docente WHERE persona_id = p_persona_id;
    IF v_id IS NULL THEN
        INSERT INTO sga.docente (persona_id, fecha_ingreso_sad) VALUES (p_persona_id, sga.hoy()) RETURNING id INTO v_id;
    END IF;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.crear_legajo(p_persona_id INTEGER, p_plan_id INTEGER, p_numero_legajo TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_numero TEXT := btrim(coalesce(p_numero_legajo, ''));
    v_id INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    IF v_numero = '' THEN
        RAISE EXCEPTION 'Indicá el número de legajo' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.plan_estudio WHERE id = p_plan_id) THEN
        RAISE EXCEPTION 'Elegí el plan de estudio' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.legajo WHERE persona_id = p_persona_id) THEN
        RAISE EXCEPTION 'La persona ya tiene legajo' USING ERRCODE = '23505';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.legajo WHERE numero_legajo = v_numero) THEN
        RAISE EXCEPTION 'El legajo % ya existe', v_numero USING ERRCODE = '23505';
    END IF;
    INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id, fecha_registracion)
    VALUES (p_persona_id, v_numero, p_plan_id, sga.hoy()) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.asignar_rol(p_persona_id INTEGER, p_rol sga.tipo_rol_persona)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    IF NOT EXISTS (SELECT 1 FROM sga.persona WHERE id = p_persona_id) THEN
        RAISE EXCEPTION 'La persona no existe' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO sga.persona_rol (persona_id, rol, activo) VALUES (p_persona_id, p_rol, TRUE)
    ON CONFLICT (persona_id, rol) DO UPDATE SET activo = TRUE;
    IF p_rol IN ('DOCENTE', 'AYUDANTE') THEN
        PERFORM sga.asegurar_docente(p_persona_id);
    END IF;
END;
$$;

CREATE FUNCTION sga.quitar_rol(p_persona_id INTEGER, p_rol sga.tipo_rol_persona)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    IF p_rol = 'ADMINISTRATIVO' AND p_persona_id = sga.persona_actual_id() THEN
        RAISE EXCEPTION 'No te podés quitar tu propio rol de Administración' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.persona_rol SET activo = FALSE WHERE persona_id = p_persona_id AND rol = p_rol;
END;
$$;

-- Alta completa. p_roles: ALUMNO, DOCENTE, AYUDANTE, ADMINISTRATIVO.
CREATE FUNCTION sga.crear_persona(
    p_tipo_documento sga.tipo_documento,
    p_nro_documento TEXT,
    p_nombre TEXT,
    p_apellido TEXT,
    p_mail_institucional TEXT,
    p_genero sga.genero,
    p_nacionalidad TEXT,
    p_fecha_nacimiento DATE,
    p_roles sga.tipo_rol_persona[],
    p_plan_id INTEGER,
    p_numero_legajo TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_mail TEXT := lower(btrim(coalesce(p_mail_institucional, '')));
    v_documento TEXT := btrim(coalesce(p_nro_documento, ''));
    v_id INTEGER;
    v_rol sga.tipo_rol_persona;
BEGIN
    PERFORM sga.validar_admin();
    IF btrim(coalesce(p_nombre, '')) = '' OR btrim(coalesce(p_apellido, '')) = '' THEN
        RAISE EXCEPTION 'Completá nombre y apellido' USING ERRCODE = '23514';
    END IF;
    IF v_documento = '' THEN
        RAISE EXCEPTION 'Completá el número de documento' USING ERRCODE = '23514';
    END IF;
    IF v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'El mail institucional no es válido' USING ERRCODE = '23514';
    END IF;
    IF coalesce(array_length(p_roles, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Elegí al menos un rol' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.persona WHERE tipo_documento = p_tipo_documento AND nro_documento = v_documento) THEN
        RAISE EXCEPTION 'Ya hay una persona con ese documento' USING ERRCODE = '23505';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.persona WHERE lower(mail_institucional) = v_mail) THEN
        RAISE EXCEPTION 'Ya hay una persona con ese mail institucional' USING ERRCODE = '23505';
    END IF;

    INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional, genero, nacionalidad, fecha_nacimiento)
    VALUES (p_tipo_documento, v_documento, btrim(p_nombre), btrim(p_apellido), v_mail, p_genero,
            NULLIF(btrim(p_nacionalidad), ''), p_fecha_nacimiento)
    RETURNING id INTO v_id;

    FOREACH v_rol IN ARRAY p_roles LOOP
        PERFORM sga.asignar_rol(v_id, v_rol);
    END LOOP;
    IF 'ALUMNO' = ANY (p_roles) THEN
        PERFORM sga.crear_legajo(v_id, p_plan_id, p_numero_legajo);
    END IF;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.asignar_docente_comision(p_persona_id INTEGER, p_comision_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_docente INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    IF NOT EXISTS (
        SELECT 1 FROM sga.persona_rol WHERE persona_id = p_persona_id AND rol IN ('DOCENTE', 'AYUDANTE') AND activo
    ) THEN
        RAISE EXCEPTION 'Para asignarle comisiones, la persona tiene que tener rol de docente o ayudante' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.comision WHERE id = p_comision_id) THEN
        RAISE EXCEPTION 'Elegí la comisión' USING ERRCODE = '23514';
    END IF;
    v_docente := sga.asegurar_docente(p_persona_id);
    IF EXISTS (SELECT 1 FROM sga.docente_comision WHERE docente_id = v_docente AND comision_id = p_comision_id) THEN
        RAISE EXCEPTION 'Ya está asignado a esa comisión' USING ERRCODE = '23505';
    END IF;
    INSERT INTO sga.docente_comision (docente_id, comision_id) VALUES (v_docente, p_comision_id);
END;
$$;

CREATE FUNCTION sga.quitar_docente_comision(p_docente_comision_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    DELETE FROM sga.docente_comision WHERE id = p_docente_comision_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La asignación no existe' USING ERRCODE = 'P0002';
    END IF;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'No se puede quitar: la asignación ya tiene datos asociados (encuestas o notas)' USING ERRCODE = '23503';
END;
$$;

CREATE FUNCTION sga.buscar_personas(p_texto TEXT)
RETURNS TABLE (
    id INTEGER,
    apellido TEXT,
    nombre TEXT,
    tipo_documento TEXT,
    nro_documento TEXT,
    mail_institucional TEXT,
    roles TEXT,
    numero_legajo TEXT,
    con_cuenta BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_q TEXT := '%' || lower(btrim(coalesce(p_texto, ''))) || '%';
BEGIN
    PERFORM sga.validar_admin();
    RETURN QUERY
    SELECT p.id, p.apellido::TEXT, p.nombre::TEXT, p.tipo_documento::TEXT, p.nro_documento::TEXT, p.mail_institucional::TEXT,
           (SELECT string_agg(r.rol::TEXT, ',' ORDER BY r.rol) FROM sga.persona_rol r WHERE r.persona_id = p.id AND r.activo),
           l.numero_legajo::TEXT,
           p.auth_user_id IS NOT NULL
    FROM sga.persona p
    LEFT JOIN sga.legajo l ON l.persona_id = p.id
    WHERE lower(p.apellido || ' ' || p.nombre || ' ' || p.nombre || ' ' || p.apellido) LIKE v_q
       OR lower(p.nro_documento) LIKE v_q
       OR lower(p.mail_institucional) LIKE v_q
       OR lower(coalesce(l.numero_legajo, '')) LIKE v_q
    ORDER BY p.apellido, p.nombre
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.validar_admin(),
    sga.asegurar_docente(INTEGER),
    sga.crear_legajo(INTEGER, INTEGER, TEXT),
    sga.asignar_rol(INTEGER, sga.tipo_rol_persona),
    sga.quitar_rol(INTEGER, sga.tipo_rol_persona),
    sga.crear_persona(sga.tipo_documento, TEXT, TEXT, TEXT, TEXT, sga.genero, TEXT, DATE, sga.tipo_rol_persona[], INTEGER, TEXT),
    sga.asignar_docente_comision(INTEGER, INTEGER),
    sga.quitar_docente_comision(INTEGER),
    sga.buscar_personas(TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.crear_legajo(INTEGER, INTEGER, TEXT),
    sga.asignar_rol(INTEGER, sga.tipo_rol_persona),
    sga.quitar_rol(INTEGER, sga.tipo_rol_persona),
    sga.crear_persona(sga.tipo_documento, TEXT, TEXT, TEXT, TEXT, sga.genero, TEXT, DATE, sga.tipo_rol_persona[], INTEGER, TEXT),
    sga.asignar_docente_comision(INTEGER, INTEGER),
    sga.quitar_docente_comision(INTEGER),
    sga.buscar_personas(TEXT)
TO authenticated;
