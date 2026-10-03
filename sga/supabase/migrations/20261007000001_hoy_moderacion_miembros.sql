-- =====================================================================
-- Hoy en el ITBA: los miembros de una organización moderan los
-- comentarios de las publicaciones de su organización (además del autor
-- del comentario y Administración).
-- =====================================================================

CREATE FUNCTION sga.puede_borrar_comentario(p_comentario_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM sga.publicacion_comentario c
        JOIN sga.publicacion p ON p.id = c.publicacion_id
        WHERE c.id = p_comentario_id
          AND (c.autor_persona_id = sga.persona_actual_id()
               OR sga.es_miembro_organizacion(p.organizacion_id)
               OR sga.es_admin()));
$$;

REVOKE EXECUTE ON FUNCTION sga.puede_borrar_comentario(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sga.puede_borrar_comentario(INTEGER) TO authenticated;

DROP POLICY publicacion_comentario_delete_autor_o_admin ON sga.publicacion_comentario;
CREATE POLICY publicacion_comentario_delete_autor_miembro_o_admin ON sga.publicacion_comentario
    FOR DELETE TO authenticated
    USING (sga.puede_borrar_comentario(id));

CREATE OR REPLACE VIEW sga.comentario_listado AS
SELECT
    c.id,
    c.publicacion_id,
    c.cuerpo,
    c.creado,
    pe.apellido AS autor_apellido,
    pe.nombre AS autor_nombre,
    sga.puede_borrar_comentario(c.id) AS puede_borrar
FROM sga.publicacion_comentario c
LEFT JOIN sga.persona pe ON pe.id = c.autor_persona_id;
