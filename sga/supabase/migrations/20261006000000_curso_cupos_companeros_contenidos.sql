-- =====================================================================
-- Detalle del curso:
--   - Vista comision_inscriptos: cuántos alumnos ocupan el cupo de cada
--     comisión (para mostrar "1/40"). La ve cualquier usuario con sesión;
--     expone solo el conteo, no quiénes son.
--   - companeros_comision(comision): apellido y nombre de los inscriptos
--     de una comisión. Solo para alumnos de esa comisión, sus docentes y
--     Administración. No expone mail, documento ni legajo.
--   - actualizar_contenidos_minimos(curso, texto): el responsable del
--     curso (jefe de cátedra) o Administración editan los contenidos
--     mínimos de la materia.
-- No cuentan en el cupo ni figuran en el listado las inscripciones
-- ABANDONADA.
-- =====================================================================

CREATE VIEW sga.comision_inscriptos AS
SELECT
    co.id AS comision_id,
    co.curso_id,
    (SELECT count(*)
        FROM sga.inscripcion_curso ic
        WHERE ic.comision_id = co.id AND ic.estado <> 'ABANDONADA')::INTEGER AS inscriptos
FROM sga.comision co;

REVOKE ALL ON sga.comision_inscriptos FROM anon;
GRANT SELECT ON sga.comision_inscriptos TO authenticated;

CREATE FUNCTION sga.puede_ver_inscriptos(p_comision_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT sga.es_admin()
        OR sga.es_docente_de_comision(p_comision_id)
        OR EXISTS (
            SELECT 1 FROM sga.inscripcion_curso ic
            WHERE ic.comision_id = p_comision_id
              AND ic.legajo_id = sga.legajo_actual_id()
              AND ic.estado <> 'ABANDONADA');
$$;

CREATE FUNCTION sga.companeros_comision(p_comision_id INTEGER)
RETURNS TABLE (apellido TEXT, nombre TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.puede_ver_inscriptos(p_comision_id) THEN
        RAISE EXCEPTION 'Solo los inscriptos y docentes de la comisión pueden ver el listado' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT p.apellido::TEXT, p.nombre::TEXT
    FROM sga.inscripcion_curso ic
    JOIN sga.legajo l ON l.id = ic.legajo_id
    JOIN sga.persona p ON p.id = l.persona_id
    WHERE ic.comision_id = p_comision_id AND ic.estado <> 'ABANDONADA'
    ORDER BY p.apellido, p.nombre;
END;
$$;

CREATE FUNCTION sga.puede_editar_contenidos(p_curso_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT sga.es_admin()
        OR EXISTS (
            SELECT 1 FROM sga.curso c
            WHERE c.id = p_curso_id
              AND c.responsable_docente_id = sga.docente_actual_id());
$$;

CREATE FUNCTION sga.actualizar_contenidos_minimos(p_curso_id INTEGER, p_contenidos TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.puede_editar_contenidos(p_curso_id) THEN
        RAISE EXCEPTION 'Solo el responsable del curso puede editar los contenidos mínimos' USING ERRCODE = '42501';
    END IF;

    UPDATE sga.materia m
    SET contenidos_minimos = NULLIF(btrim(p_contenidos), '')
    FROM sga.curso c
    WHERE c.id = p_curso_id AND m.id = c.materia_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.puede_ver_inscriptos(INTEGER),
    sga.companeros_comision(INTEGER),
    sga.puede_editar_contenidos(INTEGER),
    sga.actualizar_contenidos_minimos(INTEGER, TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.puede_ver_inscriptos(INTEGER),
    sga.companeros_comision(INTEGER),
    sga.puede_editar_contenidos(INTEGER),
    sga.actualizar_contenidos_minimos(INTEGER, TEXT)
TO authenticated;
