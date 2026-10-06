-- =====================================================================
-- Proyectos: registro estilo CV de lo que el alumno hizo para el ITBA
-- (ayudantías, investigación, extensión, otros proyectos).
--
--   - Ayudantías: salen solas de docente_comision cuando la persona del
--     alumno fue asignada a una comisión (mis_ayudantias()).
--   - El resto lo carga el alumno (proyecto_alumno) y Administración lo
--     valida o lo rechaza con un motivo:
--       PENDIENTE ──▶ VALIDADO | RECHAZADO
--       RECHAZADO ──(el alumno lo corrige)──▶ PENDIENTE
--     El alumno puede editar o borrar lo que no esté validado.
-- =====================================================================

CREATE TABLE sga.proyecto_alumno (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL REFERENCES sga.legajo (id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    materia_id INTEGER REFERENCES sga.materia (id) ON DELETE SET NULL,
    responsable TEXT,
    descripcion TEXT,
    desde DATE NOT NULL,
    hasta DATE,
    estado TEXT NOT NULL DEFAULT 'PENDIENTE',
    observaciones TEXT,
    fecha_carga TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_revision TIMESTAMPTZ,

    CONSTRAINT ck_proyecto_alumno_tipo CHECK (tipo IN ('AYUDANTIA', 'INVESTIGACION', 'EXTENSION', 'PROYECTO', 'OTRO')),
    CONSTRAINT ck_proyecto_alumno_estado CHECK (estado IN ('PENDIENTE', 'VALIDADO', 'RECHAZADO')),
    CONSTRAINT ck_proyecto_alumno_titulo CHECK (length(btrim(titulo)) > 0),
    CONSTRAINT ck_proyecto_alumno_fechas CHECK (hasta IS NULL OR hasta >= desde)
);

CREATE INDEX ix_proyecto_alumno_legajo_id ON sga.proyecto_alumno (legajo_id);

ALTER TABLE sga.proyecto_alumno ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.proyecto_alumno FORCE ROW LEVEL SECURITY;
CREATE POLICY proyecto_alumno_select ON sga.proyecto_alumno
    FOR SELECT TO authenticated USING (legajo_id = sga.legajo_actual_id() OR sga.es_admin());
GRANT SELECT ON sga.proyecto_alumno TO authenticated;

-- Valida los datos comunes a alta y edición.
CREATE FUNCTION sga.validar_datos_proyecto(p_tipo TEXT, p_titulo TEXT, p_desde DATE, p_hasta DATE)
RETURNS VOID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
BEGIN
    IF p_tipo IS NULL OR p_tipo NOT IN ('AYUDANTIA', 'INVESTIGACION', 'EXTENSION', 'PROYECTO', 'OTRO') THEN
        RAISE EXCEPTION 'Elegí el tipo de proyecto' USING ERRCODE = '23514';
    END IF;
    IF p_titulo IS NULL OR length(btrim(p_titulo)) = 0 THEN
        RAISE EXCEPTION 'Completá el título' USING ERRCODE = '23514';
    END IF;
    IF p_desde IS NULL THEN
        RAISE EXCEPTION 'Completá la fecha de inicio' USING ERRCODE = '23514';
    END IF;
    IF p_hasta IS NOT NULL AND p_hasta < p_desde THEN
        RAISE EXCEPTION 'La fecha de fin no puede ser anterior a la de inicio' USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE FUNCTION sga.cargar_proyecto(
    p_tipo TEXT, p_titulo TEXT, p_materia_id INTEGER, p_responsable TEXT, p_descripcion TEXT, p_desde DATE, p_hasta DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_id INTEGER;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    PERFORM sga.validar_datos_proyecto(p_tipo, p_titulo, p_desde, p_hasta);
    INSERT INTO sga.proyecto_alumno (legajo_id, tipo, titulo, materia_id, responsable, descripcion, desde, hasta)
    VALUES (v_legajo, p_tipo, btrim(p_titulo), p_materia_id, NULLIF(btrim(p_responsable), ''), NULLIF(btrim(p_descripcion), ''), p_desde, p_hasta)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- Editar vuelve el proyecto a PENDIENTE (Administración lo revisa de nuevo).
CREATE FUNCTION sga.editar_proyecto(
    p_id INTEGER, p_tipo TEXT, p_titulo TEXT, p_materia_id INTEGER, p_responsable TEXT, p_descripcion TEXT, p_desde DATE, p_hasta DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_estado TEXT;
BEGIN
    SELECT estado INTO v_estado FROM sga.proyecto_alumno WHERE id = p_id AND legajo_id = sga.legajo_actual_id() FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés ese proyecto' USING ERRCODE = '42501';
    END IF;
    IF v_estado = 'VALIDADO' THEN
        RAISE EXCEPTION 'El proyecto ya está validado: no se puede cambiar' USING ERRCODE = '23514';
    END IF;
    PERFORM sga.validar_datos_proyecto(p_tipo, p_titulo, p_desde, p_hasta);
    UPDATE sga.proyecto_alumno
    SET tipo = p_tipo, titulo = btrim(p_titulo), materia_id = p_materia_id,
        responsable = NULLIF(btrim(p_responsable), ''), descripcion = NULLIF(btrim(p_descripcion), ''),
        desde = p_desde, hasta = p_hasta, estado = 'PENDIENTE', observaciones = NULL, fecha_revision = NULL
    WHERE id = p_id;
END;
$$;

CREATE FUNCTION sga.borrar_proyecto(p_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_estado TEXT;
BEGIN
    SELECT estado INTO v_estado FROM sga.proyecto_alumno WHERE id = p_id AND legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés ese proyecto' USING ERRCODE = '42501';
    END IF;
    IF v_estado = 'VALIDADO' THEN
        RAISE EXCEPTION 'El proyecto ya está validado: pedile a Administración que lo quite' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.proyecto_alumno WHERE id = p_id;
END;
$$;

-- Administración valida o rechaza (el rechazo lleva motivo).
CREATE FUNCTION sga.revisar_proyecto(p_id INTEGER, p_validar BOOLEAN, p_observaciones TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración revisa proyectos' USING ERRCODE = '42501';
    END IF;
    IF NOT p_validar AND (p_observaciones IS NULL OR length(btrim(p_observaciones)) = 0) THEN
        RAISE EXCEPTION 'Indicá el motivo del rechazo' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.proyecto_alumno
    SET estado = CASE WHEN p_validar THEN 'VALIDADO' ELSE 'RECHAZADO' END,
        observaciones = NULLIF(btrim(p_observaciones), ''), fecha_revision = now()
    WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El proyecto no existe' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

-- Administración: proyectos con el alumno (pendientes primero).
CREATE FUNCTION sga.proyectos_para_revisar()
RETURNS TABLE (
    id INTEGER,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    tipo TEXT,
    titulo TEXT,
    materia TEXT,
    responsable TEXT,
    descripcion TEXT,
    desde DATE,
    hasta DATE,
    estado TEXT,
    observaciones TEXT,
    fecha_carga TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración revisa proyectos' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT p.id, pe.apellido::TEXT, pe.nombre::TEXT, l.numero_legajo::TEXT, p.tipo, p.titulo,
           CASE WHEN m.id IS NULL THEN NULL ELSE m.codigo || ' - ' || m.nombre END,
           p.responsable, p.descripcion, p.desde, p.hasta, p.estado, p.observaciones, p.fecha_carga
    FROM sga.proyecto_alumno p
    JOIN sga.legajo l ON l.id = p.legajo_id
    JOIN sga.persona pe ON pe.id = l.persona_id
    LEFT JOIN sga.materia m ON m.id = p.materia_id
    ORDER BY p.estado <> 'PENDIENTE', p.fecha_carga DESC;
END;
$$;

-- Ayudantías registradas por el ITBA: comisiones en las que la persona
-- del alumno figura como docente.
CREATE FUNCTION sga.mis_ayudantias()
RETURNS TABLE (
    anio INTEGER,
    periodo TEXT,
    codigo TEXT,
    materia TEXT,
    comision TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT c.anio::INTEGER, c.periodo::TEXT, m.codigo::TEXT, m.nombre::TEXT, co.nombre::TEXT
    FROM sga.docente d
    JOIN sga.docente_comision dc ON dc.docente_id = d.id
    JOIN sga.comision co ON co.id = dc.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE d.persona_id = sga.persona_actual_id()
    ORDER BY c.anio DESC, c.periodo DESC, m.codigo;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.validar_datos_proyecto(TEXT, TEXT, DATE, DATE),
    sga.cargar_proyecto(TEXT, TEXT, INTEGER, TEXT, TEXT, DATE, DATE),
    sga.editar_proyecto(INTEGER, TEXT, TEXT, INTEGER, TEXT, TEXT, DATE, DATE),
    sga.borrar_proyecto(INTEGER),
    sga.revisar_proyecto(INTEGER, BOOLEAN, TEXT),
    sga.proyectos_para_revisar(),
    sga.mis_ayudantias()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.cargar_proyecto(TEXT, TEXT, INTEGER, TEXT, TEXT, DATE, DATE),
    sga.editar_proyecto(INTEGER, TEXT, TEXT, INTEGER, TEXT, TEXT, DATE, DATE),
    sga.borrar_proyecto(INTEGER),
    sga.revisar_proyecto(INTEGER, BOOLEAN, TEXT),
    sga.proyectos_para_revisar(),
    sga.mis_ayudantias()
TO authenticated;
