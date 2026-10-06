-- =====================================================================
-- Trámites: Inicio → Tareas → "Iniciar nuevo trámite" / "Ver historial
-- de trámites", como en el SGA.
--
--   - tramite: título, destino (Secretaría Académica o Administrativa) y
--     descripción (hasta 8000 caracteres). Administración lo toma (queda
--     asignado a quien lo tomó) y lo resuelve o lo rechaza:
--       PENDIENTE ──▶ EN_CURSO ──▶ RESUELTO | RECHAZADO
--       PENDIENTE ──(quien lo envió)──▶ CANCELADO
--   - tramite_movimiento: historial (cambios de estado y comentarios de
--     las dos partes). Cada novedad de Administración le deja una
--     notificación a quien envió el trámite.
-- =====================================================================

CREATE TABLE sga.tramite (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL REFERENCES sga.persona (id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    destino TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    estado TEXT NOT NULL DEFAULT 'PENDIENTE',
    asignado_persona_id INTEGER REFERENCES sga.persona (id) ON DELETE SET NULL,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_tramite_destino CHECK (destino IN ('ACADEMICA', 'ADMINISTRATIVA')),
    CONSTRAINT ck_tramite_estado CHECK (estado IN ('PENDIENTE', 'EN_CURSO', 'RESUELTO', 'RECHAZADO', 'CANCELADO')),
    CONSTRAINT ck_tramite_titulo CHECK (length(btrim(titulo)) BETWEEN 1 AND 150),
    CONSTRAINT ck_tramite_descripcion CHECK (length(btrim(descripcion)) BETWEEN 1 AND 8000)
);

CREATE INDEX ix_tramite_persona_id ON sga.tramite (persona_id);
CREATE INDEX ix_tramite_estado ON sga.tramite (estado);

CREATE TABLE sga.tramite_movimiento (
    id SERIAL PRIMARY KEY,
    tramite_id INTEGER NOT NULL REFERENCES sga.tramite (id) ON DELETE CASCADE,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    autor_persona_id INTEGER REFERENCES sga.persona (id) ON DELETE SET NULL,
    -- Estado al que pasó (NULL si es solo un comentario)
    estado TEXT,
    comentario TEXT,

    CONSTRAINT ck_tramite_movimiento_algo CHECK (estado IS NOT NULL OR comentario IS NOT NULL)
);

CREATE INDEX ix_tramite_movimiento_tramite_id ON sga.tramite_movimiento (tramite_id);

ALTER TABLE sga.tramite ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.tramite FORCE ROW LEVEL SECURITY;
CREATE POLICY tramite_select ON sga.tramite
    FOR SELECT TO authenticated USING (persona_id = sga.persona_actual_id() OR sga.es_admin());
GRANT SELECT ON sga.tramite TO authenticated;

ALTER TABLE sga.tramite_movimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.tramite_movimiento FORCE ROW LEVEL SECURITY;
CREATE POLICY tramite_movimiento_select ON sga.tramite_movimiento
    FOR SELECT TO authenticated USING (
        sga.es_admin()
        OR EXISTS (SELECT 1 FROM sga.tramite t WHERE t.id = tramite_id AND t.persona_id = sga.persona_actual_id())
    );
GRANT SELECT ON sga.tramite_movimiento TO authenticated;

-- Listado y historial con nombres (persona no es visible para todos; las
-- vistas corren con los permisos del dueño y filtran igual que las
-- políticas de arriba: lo propio, o todo para Administración).
CREATE VIEW sga.tramite_listado AS
SELECT t.id, t.persona_id, t.titulo, t.destino, t.descripcion, t.estado, t.fecha_creacion, t.fecha_actualizacion,
       pe.apellido || ', ' || pe.nombre AS enviado_por,
       l.numero_legajo,
       CASE WHEN pa.id IS NULL THEN NULL ELSE pa.apellido || ', ' || pa.nombre END AS asignado_a
FROM sga.tramite t
JOIN sga.persona pe ON pe.id = t.persona_id
LEFT JOIN sga.legajo l ON l.persona_id = pe.id
LEFT JOIN sga.persona pa ON pa.id = t.asignado_persona_id
WHERE sga.es_admin() OR t.persona_id = sga.persona_actual_id();

CREATE VIEW sga.tramite_movimiento_listado AS
SELECT m.id, m.tramite_id, m.fecha, m.estado, m.comentario,
       CASE WHEN p.id IS NULL THEN NULL ELSE p.apellido || ', ' || p.nombre END AS autor,
       EXISTS (SELECT 1 FROM sga.persona_rol r WHERE r.persona_id = m.autor_persona_id AND r.rol = 'ADMINISTRATIVO') AS de_administracion
FROM sga.tramite_movimiento m
JOIN sga.tramite t ON t.id = m.tramite_id
LEFT JOIN sga.persona p ON p.id = m.autor_persona_id
WHERE sga.es_admin() OR t.persona_id = sga.persona_actual_id();

GRANT SELECT ON sga.tramite_listado, sga.tramite_movimiento_listado TO authenticated;

CREATE FUNCTION sga.etiqueta_estado_tramite(p_estado TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT CASE p_estado
        WHEN 'PENDIENTE' THEN 'Pendiente'
        WHEN 'EN_CURSO' THEN 'En curso'
        WHEN 'RESUELTO' THEN 'Resuelto'
        WHEN 'RECHAZADO' THEN 'Rechazado'
        WHEN 'CANCELADO' THEN 'Cancelado'
    END;
$$;

-- Envía un trámite. Devuelve su número.
CREATE FUNCTION sga.iniciar_tramite(p_titulo TEXT, p_destino TEXT, p_descripcion TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_yo INTEGER := sga.persona_actual_id();
    v_titulo TEXT := btrim(coalesce(p_titulo, ''));
    v_descripcion TEXT := btrim(coalesce(p_descripcion, ''));
    v_id INTEGER;
BEGIN
    IF v_yo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene una persona asociada' USING ERRCODE = '42501';
    END IF;
    IF v_titulo = '' THEN
        RAISE EXCEPTION 'Completá el título' USING ERRCODE = '23514';
    END IF;
    IF length(v_titulo) > 150 THEN
        RAISE EXCEPTION 'El título puede tener hasta 150 caracteres' USING ERRCODE = '23514';
    END IF;
    IF p_destino IS NULL OR p_destino NOT IN ('ACADEMICA', 'ADMINISTRATIVA') THEN
        RAISE EXCEPTION 'Elegí el destino' USING ERRCODE = '23514';
    END IF;
    IF v_descripcion = '' THEN
        RAISE EXCEPTION 'Completá la descripción' USING ERRCODE = '23514';
    END IF;
    IF length(v_descripcion) > 8000 THEN
        RAISE EXCEPTION 'La descripción puede tener hasta 8000 caracteres' USING ERRCODE = '23514';
    END IF;

    INSERT INTO sga.tramite (persona_id, titulo, destino, descripcion)
    VALUES (v_yo, v_titulo, p_destino, v_descripcion) RETURNING id INTO v_id;
    INSERT INTO sga.tramite_movimiento (tramite_id, autor_persona_id, estado) VALUES (v_id, v_yo, 'PENDIENTE');
    RETURN v_id;
END;
$$;

-- Quien lo envió lo cancela mientras nadie lo haya tomado.
CREATE FUNCTION sga.cancelar_tramite(p_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_estado TEXT;
BEGIN
    SELECT estado INTO v_estado FROM sga.tramite WHERE id = p_id AND persona_id = sga.persona_actual_id() FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés ese trámite' USING ERRCODE = '42501';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se puede cancelar un trámite que todavía nadie tomó' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.tramite SET estado = 'CANCELADO', fecha_actualizacion = now() WHERE id = p_id;
    INSERT INTO sga.tramite_movimiento (tramite_id, autor_persona_id, estado) VALUES (p_id, sga.persona_actual_id(), 'CANCELADO');
END;
$$;

-- Comentario de quien lo envió o de Administración, mientras siga abierto.
CREATE FUNCTION sga.comentar_tramite(p_id INTEGER, p_comentario TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_t sga.tramite%ROWTYPE;
    v_texto TEXT := NULLIF(btrim(p_comentario), '');
BEGIN
    SELECT * INTO v_t FROM sga.tramite WHERE id = p_id;
    IF NOT FOUND OR NOT (v_t.persona_id = sga.persona_actual_id() OR sga.es_admin()) THEN
        RAISE EXCEPTION 'No tenés ese trámite' USING ERRCODE = '42501';
    END IF;
    IF v_t.estado NOT IN ('PENDIENTE', 'EN_CURSO') THEN
        RAISE EXCEPTION 'El trámite ya está cerrado' USING ERRCODE = '23514';
    END IF;
    IF v_texto IS NULL THEN
        RAISE EXCEPTION 'Escribí un comentario' USING ERRCODE = '23514';
    END IF;
    IF length(v_texto) > 8000 THEN
        RAISE EXCEPTION 'El comentario puede tener hasta 8000 caracteres' USING ERRCODE = '23514';
    END IF;
    INSERT INTO sga.tramite_movimiento (tramite_id, autor_persona_id, comentario) VALUES (p_id, sga.persona_actual_id(), v_texto);
    UPDATE sga.tramite SET fecha_actualizacion = now() WHERE id = p_id;
    IF v_t.persona_id <> sga.persona_actual_id() THEN
        INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
        VALUES (v_t.persona_id, 'TRAMITE', format('Tenés una respuesta en el trámite "%s"', v_t.titulo));
    END IF;
END;
$$;

-- Administración: tomar (EN_CURSO), resolver o rechazar (con motivo).
-- Quien lo toma (o lo cierra sin tomarlo) queda asignado.
CREATE FUNCTION sga.cambiar_estado_tramite(p_id INTEGER, p_estado TEXT, p_comentario TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_t sga.tramite%ROWTYPE;
    v_texto TEXT := NULLIF(btrim(p_comentario), '');
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración gestiona trámites' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_t FROM sga.tramite WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El trámite no existe' USING ERRCODE = 'P0002';
    END IF;
    IF NOT (
        (v_t.estado = 'PENDIENTE' AND p_estado IN ('EN_CURSO', 'RESUELTO', 'RECHAZADO'))
        OR (v_t.estado = 'EN_CURSO' AND p_estado IN ('RESUELTO', 'RECHAZADO'))
    ) THEN
        RAISE EXCEPTION 'No se puede pasar un trámite % a %', lower(sga.etiqueta_estado_tramite(v_t.estado)),
            coalesce(lower(sga.etiqueta_estado_tramite(p_estado)), p_estado) USING ERRCODE = '23514';
    END IF;
    IF p_estado = 'RECHAZADO' AND v_texto IS NULL THEN
        RAISE EXCEPTION 'Indicá el motivo del rechazo' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.tramite
    SET estado = p_estado, fecha_actualizacion = now(),
        asignado_persona_id = coalesce(asignado_persona_id, sga.persona_actual_id())
    WHERE id = p_id;
    INSERT INTO sga.tramite_movimiento (tramite_id, autor_persona_id, estado, comentario)
    VALUES (p_id, sga.persona_actual_id(), p_estado, v_texto);
    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    VALUES (v_t.persona_id, 'TRAMITE', format('Tu trámite "%s" está %s', v_t.titulo, lower(sga.etiqueta_estado_tramite(p_estado))));
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.iniciar_tramite(TEXT, TEXT, TEXT),
    sga.cancelar_tramite(INTEGER),
    sga.comentar_tramite(INTEGER, TEXT),
    sga.cambiar_estado_tramite(INTEGER, TEXT, TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.iniciar_tramite(TEXT, TEXT, TEXT),
    sga.cancelar_tramite(INTEGER),
    sga.comentar_tramite(INTEGER, TEXT),
    sga.cambiar_estado_tramite(INTEGER, TEXT, TEXT)
TO authenticated;
