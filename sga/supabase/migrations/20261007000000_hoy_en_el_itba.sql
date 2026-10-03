-- =====================================================================
-- Hoy en el ITBA: foro de las organizaciones estudiantiles.
--
--   - organizacion: centros de estudiantes, clubes, grupos, etc. Las da
--     de alta Administración.
--   - organizacion_miembro: quiénes publican en nombre de cada
--     organización (los asigna Administración).
--   - publicacion: eventos (con fecha, hora y lugar) y novedades. Las
--     escriben los miembros; las editan o borran los miembros de esa
--     organización y Administración.
--   - publicacion_comentario: cualquier usuario con sesión comenta; borra
--     su autor o Administración.
--   - Vistas publicacion_listado y comentario_listado: todo lo anterior
--     con el nombre del autor (las políticas de persona solo dejan ver la
--     propia) y si quien consulta puede editar o borrar.
-- =====================================================================

CREATE TABLE sga.organizacion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    descripcion TEXT,
    activa BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_organizacion_nombre UNIQUE (nombre),
    CONSTRAINT ck_organizacion_nombre CHECK (btrim(nombre) <> '')
);

CREATE TABLE sga.organizacion_miembro (
    organizacion_id INTEGER NOT NULL REFERENCES sga.organizacion (id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL REFERENCES sga.persona (id) ON DELETE CASCADE,
    desde DATE NOT NULL DEFAULT current_date,

    PRIMARY KEY (organizacion_id, persona_id)
);

CREATE INDEX ix_organizacion_miembro_persona_id ON sga.organizacion_miembro (persona_id);

CREATE TABLE sga.publicacion (
    id SERIAL PRIMARY KEY,
    organizacion_id INTEGER NOT NULL REFERENCES sga.organizacion (id) ON DELETE CASCADE,
    autor_persona_id INTEGER REFERENCES sga.persona (id) ON DELETE SET NULL,
    tipo VARCHAR NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    cuerpo TEXT NOT NULL,
    fecha_evento DATE,
    hora_evento TIME,
    lugar VARCHAR(150),
    creada TIMESTAMPTZ NOT NULL DEFAULT now(),
    editada TIMESTAMPTZ,

    CONSTRAINT ck_publicacion_tipo CHECK (tipo IN ('EVENTO', 'NOVEDAD')),
    CONSTRAINT ck_publicacion_titulo CHECK (btrim(titulo) <> ''),
    CONSTRAINT ck_publicacion_cuerpo CHECK (btrim(cuerpo) <> '' AND length(cuerpo) <= 5000),
    CONSTRAINT ck_publicacion_evento_fecha CHECK (tipo <> 'EVENTO' OR fecha_evento IS NOT NULL)
);

CREATE INDEX ix_publicacion_organizacion_id ON sga.publicacion (organizacion_id);
CREATE INDEX ix_publicacion_creada ON sga.publicacion (creada DESC);
CREATE INDEX ix_publicacion_fecha_evento ON sga.publicacion (fecha_evento) WHERE tipo = 'EVENTO';

CREATE TABLE sga.publicacion_comentario (
    id SERIAL PRIMARY KEY,
    publicacion_id INTEGER NOT NULL REFERENCES sga.publicacion (id) ON DELETE CASCADE,
    autor_persona_id INTEGER REFERENCES sga.persona (id) ON DELETE SET NULL,
    cuerpo TEXT NOT NULL,
    creado TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_publicacion_comentario_cuerpo CHECK (btrim(cuerpo) <> '' AND length(cuerpo) <= 2000)
);

CREATE INDEX ix_publicacion_comentario_publicacion_id ON sga.publicacion_comentario (publicacion_id);

-- ---------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.es_miembro_organizacion(p_organizacion_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM sga.organizacion_miembro om
        JOIN sga.organizacion o ON o.id = om.organizacion_id
        WHERE om.organizacion_id = p_organizacion_id
          AND om.persona_id = sga.persona_actual_id()
          AND o.activa);
$$;

REVOKE EXECUTE ON FUNCTION sga.es_miembro_organizacion(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sga.es_miembro_organizacion(INTEGER) TO authenticated;

ALTER TABLE sga.organizacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.organizacion FORCE ROW LEVEL SECURITY;
CREATE POLICY organizacion_select_autenticados ON sga.organizacion
    FOR SELECT TO authenticated USING (true);
CREATE POLICY organizacion_admin_all ON sga.organizacion
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.organizacion_miembro ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.organizacion_miembro FORCE ROW LEVEL SECURITY;
CREATE POLICY organizacion_miembro_select_propio ON sga.organizacion_miembro
    FOR SELECT TO authenticated USING (persona_id = sga.persona_actual_id());
CREATE POLICY organizacion_miembro_admin_all ON sga.organizacion_miembro
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.publicacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.publicacion FORCE ROW LEVEL SECURITY;
CREATE POLICY publicacion_select_autenticados ON sga.publicacion
    FOR SELECT TO authenticated USING (true);
CREATE POLICY publicacion_insert_miembro ON sga.publicacion
    FOR INSERT TO authenticated
    WITH CHECK (sga.es_miembro_organizacion(organizacion_id) AND autor_persona_id = sga.persona_actual_id());
CREATE POLICY publicacion_update_miembro_o_admin ON sga.publicacion
    FOR UPDATE TO authenticated
    USING (sga.es_miembro_organizacion(organizacion_id) OR sga.es_admin())
    WITH CHECK (sga.es_miembro_organizacion(organizacion_id) OR sga.es_admin());
CREATE POLICY publicacion_delete_miembro_o_admin ON sga.publicacion
    FOR DELETE TO authenticated
    USING (sga.es_miembro_organizacion(organizacion_id) OR sga.es_admin());

ALTER TABLE sga.publicacion_comentario ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.publicacion_comentario FORCE ROW LEVEL SECURITY;
CREATE POLICY publicacion_comentario_select_autenticados ON sga.publicacion_comentario
    FOR SELECT TO authenticated USING (true);
CREATE POLICY publicacion_comentario_insert_propio ON sga.publicacion_comentario
    FOR INSERT TO authenticated WITH CHECK (autor_persona_id = sga.persona_actual_id());
CREATE POLICY publicacion_comentario_delete_autor_o_admin ON sga.publicacion_comentario
    FOR DELETE TO authenticated
    USING (autor_persona_id = sga.persona_actual_id() OR sga.es_admin());

-- El autor y la fecha de creación no se cambian al editar; la edición
-- queda registrada.
CREATE FUNCTION sga.publicacion_antes_de_editar()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.autor_persona_id := OLD.autor_persona_id;
    NEW.organizacion_id := OLD.organizacion_id;
    NEW.creada := OLD.creada;
    NEW.editada := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_publicacion_antes_de_editar
    BEFORE UPDATE ON sga.publicacion
    FOR EACH ROW EXECUTE FUNCTION sga.publicacion_antes_de_editar();

GRANT SELECT, INSERT, UPDATE, DELETE ON sga.organizacion, sga.organizacion_miembro,
    sga.publicacion, sga.publicacion_comentario TO authenticated;
GRANT USAGE ON SEQUENCE sga.organizacion_id_seq, sga.publicacion_id_seq,
    sga.publicacion_comentario_id_seq TO authenticated;

-- ---------------------------------------------------------------------
-- Vistas para el foro (corren con permisos de su dueño)
-- ---------------------------------------------------------------------

CREATE VIEW sga.publicacion_listado AS
SELECT
    p.id,
    p.organizacion_id,
    o.nombre AS organizacion,
    p.tipo,
    p.titulo,
    p.cuerpo,
    p.fecha_evento,
    p.hora_evento,
    p.lugar,
    p.creada,
    p.editada,
    pe.apellido AS autor_apellido,
    pe.nombre AS autor_nombre,
    (SELECT count(*) FROM sga.publicacion_comentario c WHERE c.publicacion_id = p.id)::INTEGER AS comentarios,
    (sga.es_miembro_organizacion(p.organizacion_id) OR sga.es_admin()) AS puede_editar
FROM sga.publicacion p
JOIN sga.organizacion o ON o.id = p.organizacion_id
LEFT JOIN sga.persona pe ON pe.id = p.autor_persona_id;

CREATE VIEW sga.comentario_listado AS
SELECT
    c.id,
    c.publicacion_id,
    c.cuerpo,
    c.creado,
    pe.apellido AS autor_apellido,
    pe.nombre AS autor_nombre,
    (c.autor_persona_id = sga.persona_actual_id() OR sga.es_admin()) AS puede_borrar
FROM sga.publicacion_comentario c
LEFT JOIN sga.persona pe ON pe.id = c.autor_persona_id;

REVOKE ALL ON sga.publicacion_listado, sga.comentario_listado FROM anon;
GRANT SELECT ON sga.publicacion_listado, sga.comentario_listado TO authenticated;
