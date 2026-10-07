-- =====================================================================
-- Administración → Oferta de cursos: armar los cursos de un cuatrimestre
-- sin tocar SQL.
--
--   - crear_curso(): curso de una materia (por código) en un cuatrimestre.
--   - crear_comision() / cambiar_cupo_comision() / borrar_comision().
--   - agregar_horario() / borrar_horario(): horarios de una comisión. Un
--     horario presencial necesita aula, y el aula no puede estar ocupada
--     por otra comisión el mismo día a la misma hora en un curso cuyas
--     fechas se superpongan.
--   - borrar_curso(): solo si nadie se inscribió.
--
-- Las tablas ya dejan escribir a Administración (RLS); las funciones dan
-- los mensajes claros y los controles que una fila sola no puede hacer.
-- =====================================================================

-- validar_admin() ya no es solo de Personas: mensaje genérico.
CREATE OR REPLACE FUNCTION sga.validar_admin()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración puede hacer esto' USING ERRCODE = '42501';
    END IF;
END;
$$;

CREATE FUNCTION sga.crear_curso(p_codigo TEXT, p_anio INTEGER, p_periodo TEXT, p_desde DATE, p_hasta DATE)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_materia INTEGER;
    v_id INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    SELECT id INTO v_materia FROM sga.materia WHERE codigo = btrim(p_codigo);
    IF v_materia IS NULL THEN
        RAISE EXCEPTION 'No existe la materia %', btrim(p_codigo) USING ERRCODE = '23514';
    END IF;
    IF p_periodo NOT IN ('1C', '2C') OR p_anio IS NULL THEN
        RAISE EXCEPTION 'Elegí el cuatrimestre' USING ERRCODE = '23514';
    END IF;
    IF p_desde IS NULL OR p_hasta IS NULL OR p_hasta <= p_desde THEN
        RAISE EXCEPTION 'Las fechas del curso no son válidas' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.curso WHERE materia_id = v_materia AND anio = p_anio AND periodo = p_periodo AND activo) THEN
        RAISE EXCEPTION 'La materia % ya tiene curso en ese cuatrimestre', btrim(p_codigo) USING ERRCODE = '23505';
    END IF;
    INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
    VALUES (v_materia, p_anio, p_periodo, p_desde, p_hasta) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.borrar_curso(p_curso_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    IF EXISTS (SELECT 1 FROM sga.inscripcion_curso WHERE curso_id = p_curso_id)
       OR EXISTS (SELECT 1 FROM sga.solicitud_cursada WHERE curso_id = p_curso_id) THEN
        RAISE EXCEPTION 'No se puede borrar: el curso ya tiene inscripciones o solicitudes' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.horario_comision WHERE comision_id IN (SELECT id FROM sga.comision WHERE curso_id = p_curso_id);
    DELETE FROM sga.comision WHERE curso_id = p_curso_id;
    DELETE FROM sga.curso WHERE id = p_curso_id;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'No se puede borrar: el curso tiene datos asociados (docentes, finales o encuestas)' USING ERRCODE = '23503';
END;
$$;

CREATE FUNCTION sga.crear_comision(p_curso_id INTEGER, p_nombre TEXT, p_cupo INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_nombre TEXT := upper(btrim(coalesce(p_nombre, '')));
    v_id INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    IF v_nombre = '' THEN
        RAISE EXCEPTION 'Indicá el nombre de la comisión' USING ERRCODE = '23514';
    END IF;
    IF p_cupo IS NOT NULL AND p_cupo <= 0 THEN
        RAISE EXCEPTION 'El cupo tiene que ser mayor que cero' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.curso WHERE id = p_curso_id) THEN
        RAISE EXCEPTION 'El curso no existe' USING ERRCODE = 'P0002';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.comision WHERE curso_id = p_curso_id AND nombre = v_nombre) THEN
        RAISE EXCEPTION 'Ya hay una comisión %', v_nombre USING ERRCODE = '23505';
    END IF;
    INSERT INTO sga.comision (curso_id, nombre, cupo) VALUES (p_curso_id, v_nombre, p_cupo) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.cambiar_cupo_comision(p_comision_id INTEGER, p_cupo INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_inscriptos INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    IF p_cupo IS NOT NULL AND p_cupo <= 0 THEN
        RAISE EXCEPTION 'El cupo tiene que ser mayor que cero' USING ERRCODE = '23514';
    END IF;
    SELECT count(*) INTO v_inscriptos FROM sga.inscripcion_curso WHERE comision_id = p_comision_id AND estado <> 'ABANDONADA';
    IF p_cupo IS NOT NULL AND p_cupo < v_inscriptos THEN
        RAISE EXCEPTION 'Ya hay % inscriptos: el cupo no puede ser menor', v_inscriptos USING ERRCODE = '23514';
    END IF;
    UPDATE sga.comision SET cupo = p_cupo WHERE id = p_comision_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La comisión no existe' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

CREATE FUNCTION sga.borrar_comision(p_comision_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    IF EXISTS (SELECT 1 FROM sga.inscripcion_curso WHERE comision_id = p_comision_id)
       OR EXISTS (SELECT 1 FROM sga.solicitud_cursada WHERE comision_id = p_comision_id) THEN
        RAISE EXCEPTION 'No se puede borrar: la comisión ya tiene inscripciones o solicitudes' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.horario_comision WHERE comision_id = p_comision_id;
    DELETE FROM sga.comision WHERE id = p_comision_id;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'No se puede borrar: la comisión tiene docentes asignados o encuestas' USING ERRCODE = '23503';
END;
$$;

-- p_aula: código del aula (el edificio se toma por p_edificio_id).
CREATE FUNCTION sga.agregar_horario(
    p_comision_id INTEGER, p_dia sga.dia_semana, p_desde TIME, p_hasta TIME,
    p_modalidad sga.modalidad_horario, p_edificio_id INTEGER, p_aula TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_curso sga.curso%ROWTYPE;
    v_aula INTEGER;
    v_choque TEXT;
    v_id INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    SELECT c.* INTO v_curso FROM sga.comision co JOIN sga.curso c ON c.id = co.curso_id WHERE co.id = p_comision_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La comisión no existe' USING ERRCODE = 'P0002';
    END IF;
    IF p_desde IS NULL OR p_hasta IS NULL OR p_hasta <= p_desde THEN
        RAISE EXCEPTION 'El horario no es válido' USING ERRCODE = '23514';
    END IF;
    IF NULLIF(btrim(p_aula), '') IS NOT NULL THEN
        SELECT id INTO v_aula FROM sga.aula WHERE edificio_id = p_edificio_id AND codigo = btrim(p_aula);
        IF v_aula IS NULL THEN
            RAISE EXCEPTION 'No existe el aula % en esa sede', btrim(p_aula) USING ERRCODE = '23514';
        END IF;
    END IF;
    IF p_modalidad = 'PRESENCIAL' AND v_aula IS NULL THEN
        RAISE EXCEPTION 'Un horario presencial necesita aula' USING ERRCODE = '23514';
    END IF;

    IF v_aula IS NOT NULL THEN
        SELECT m.codigo || ' comisión ' || co.nombre || ' (' || to_char(h.hora_inicio, 'HH24:MI') || ' a ' || to_char(h.hora_fin, 'HH24:MI') || ')'
        INTO v_choque
        FROM sga.horario_comision h
        JOIN sga.comision co ON co.id = h.comision_id
        JOIN sga.curso c ON c.id = co.curso_id
        JOIN sga.materia m ON m.id = c.materia_id
        WHERE h.aula_id = v_aula AND h.dia_semana = p_dia AND c.activo
          AND h.hora_inicio < p_hasta AND p_desde < h.hora_fin
          AND c.fecha_inicio <= v_curso.fecha_fin AND v_curso.fecha_inicio <= c.fecha_fin
        LIMIT 1;
        IF v_choque IS NOT NULL THEN
            RAISE EXCEPTION 'El aula ya está ocupada a esa hora por %', v_choque USING ERRCODE = '23514';
        END IF;
    END IF;

    INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id, modalidad)
    VALUES (p_comision_id, p_dia, p_desde, p_hasta, v_aula, p_modalidad) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.borrar_horario(p_horario_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    DELETE FROM sga.horario_comision WHERE id = p_horario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El horario no existe' USING ERRCODE = 'P0002';
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.crear_curso(TEXT, INTEGER, TEXT, DATE, DATE),
    sga.borrar_curso(INTEGER),
    sga.crear_comision(INTEGER, TEXT, INTEGER),
    sga.cambiar_cupo_comision(INTEGER, INTEGER),
    sga.borrar_comision(INTEGER),
    sga.agregar_horario(INTEGER, sga.dia_semana, TIME, TIME, sga.modalidad_horario, INTEGER, TEXT),
    sga.borrar_horario(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.crear_curso(TEXT, INTEGER, TEXT, DATE, DATE),
    sga.borrar_curso(INTEGER),
    sga.crear_comision(INTEGER, TEXT, INTEGER),
    sga.cambiar_cupo_comision(INTEGER, INTEGER),
    sga.borrar_comision(INTEGER),
    sga.agregar_horario(INTEGER, sga.dia_semana, TIME, TIME, sga.modalidad_horario, INTEGER, TEXT),
    sga.borrar_horario(INTEGER)
TO authenticated;
