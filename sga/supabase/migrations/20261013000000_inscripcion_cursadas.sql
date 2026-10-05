-- =====================================================================
-- Inscripción a cursadas.
--
--   - periodo_inscripcion_cursada: para cada cuatrimestre (año + período
--     del curso), el rango de fechas en que los alumnos se inscriben.
--   - inscribirse_cursada(): el alumno elige una comisión de un curso de
--     ese cuatrimestre si
--       · la inscripción del cuatrimestre está abierta,
--       · la materia es de su plan y no la aprobó ni tiene la cursada
--         aprobada (le falta solo el final),
--       · no la está cursando ni está inscripto en otra comisión del curso,
--       · cumple las correlativas "para cursar" (REGULAR: cursada aprobada
--         o materia aprobada; APROBADA: materia aprobada),
--       · la comisión tiene cupo (se toma por orden de llegada),
--       · sus horarios no se superponen con otra comisión en la que ya
--         está inscripto ese cuatrimestre.
--   - desinscribirse_cursada(): mientras la inscripción esté abierta y no
--     tenga nota (para cambiar de comisión: baja y nueva inscripción).
-- =====================================================================

CREATE TABLE sga.periodo_inscripcion_cursada (
    id SERIAL PRIMARY KEY,
    anio INTEGER NOT NULL,
    periodo VARCHAR NOT NULL,
    desde DATE NOT NULL,
    hasta DATE NOT NULL,

    CONSTRAINT uq_periodo_inscripcion_cursada UNIQUE (anio, periodo),
    CONSTRAINT ck_periodo_inscripcion_cursada_fechas CHECK (hasta >= desde)
);

ALTER TABLE sga.periodo_inscripcion_cursada ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.periodo_inscripcion_cursada FORCE ROW LEVEL SECURITY;
CREATE POLICY periodo_inscripcion_cursada_select ON sga.periodo_inscripcion_cursada FOR SELECT TO authenticated USING (true);
CREATE POLICY periodo_inscripcion_cursada_admin_all ON sga.periodo_inscripcion_cursada
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.periodo_inscripcion_cursada TO authenticated;
GRANT USAGE ON SEQUENCE sga.periodo_inscripcion_cursada_id_seq TO authenticated;

-- Por qué el alumno no puede inscribirse en la comisión; NULL si puede.
CREATE FUNCTION sga.motivo_no_inscripcion_cursada(p_comision_id INTEGER, p_legajo_id INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_co sga.comision%ROWTYPE;
    v_curso sga.curso%ROWTYPE;
    v_periodo sga.periodo_inscripcion_cursada%ROWTYPE;
    v_plan INTEGER;
    v_actual RECORD;
    v_faltan TEXT;
    v_choque TEXT;
BEGIN
    SELECT * INTO v_co FROM sga.comision WHERE id = p_comision_id;
    IF NOT FOUND THEN RETURN 'La comisión no existe'; END IF;
    SELECT * INTO v_curso FROM sga.curso WHERE id = v_co.curso_id;
    SELECT plan_estudio_id INTO v_plan FROM sga.legajo WHERE id = p_legajo_id;

    SELECT * INTO v_periodo FROM sga.periodo_inscripcion_cursada
    WHERE anio = v_curso.anio AND periodo = v_curso.periodo;
    IF NOT FOUND THEN RETURN 'No hay inscripción abierta para este cuatrimestre'; END IF;
    IF sga.hoy() < v_periodo.desde THEN
        RETURN format('La inscripción abre el %s', to_char(v_periodo.desde, 'DD/MM/YYYY'));
    END IF;
    IF sga.hoy() > v_periodo.hasta THEN
        RETURN format('La inscripción cerró el %s', to_char(v_periodo.hasta, 'DD/MM/YYYY'));
    END IF;
    IF NOT v_curso.activo THEN RETURN 'El curso no está activo'; END IF;

    IF NOT EXISTS (SELECT 1 FROM sga.plan_materia WHERE plan_id = v_plan AND materia_id = v_curso.materia_id) THEN
        RETURN 'La materia no es de tu plan';
    END IF;

    -- Situación actual del alumno en la materia
    SELECT ic.estado, ic.curso_id, co.nombre AS comision INTO v_actual
    FROM sga.inscripcion_curso ic
    JOIN sga.curso c ON c.id = ic.curso_id
    JOIN sga.comision co ON co.id = ic.comision_id
    WHERE ic.legajo_id = p_legajo_id AND c.materia_id = v_curso.materia_id
      AND ic.estado IN ('APROBADA', 'CURSADA_APROBADA', 'CURSANDO')
    ORDER BY (ic.estado = 'APROBADA') DESC, (ic.estado = 'CURSADA_APROBADA') DESC, c.fecha_inicio DESC
    LIMIT 1;
    IF FOUND THEN
        IF v_actual.estado = 'APROBADA' THEN RETURN 'Ya aprobaste esta materia'; END IF;
        IF v_actual.estado = 'CURSADA_APROBADA' THEN RETURN 'Ya tenés la cursada aprobada: te falta el final'; END IF;
        IF v_actual.curso_id = v_curso.id THEN
            IF v_actual.comision = v_co.nombre THEN RETURN 'Ya estás inscripto en esta comisión'; END IF;
            RETURN format('Ya estás inscripto en la comisión %s (date de baja para cambiar)', v_actual.comision);
        END IF;
        RETURN 'Ya estás cursando esta materia';
    END IF;

    SELECT string_agg(req.codigo, ', ' ORDER BY req.codigo) INTO v_faltan
    FROM sga.correlativa cr
    JOIN sga.materia req ON req.id = cr.materia_requerida_id
    WHERE cr.materia_id = v_curso.materia_id AND cr.tipo_requisito = 'PARA_CURSAR'
      AND (cr.plan_id IS NULL OR cr.plan_id = v_plan)
      AND NOT EXISTS (
          SELECT 1 FROM sga.inscripcion_curso x JOIN sga.curso cx ON cx.id = x.curso_id
          WHERE x.legajo_id = p_legajo_id AND cx.materia_id = cr.materia_requerida_id
            AND (x.estado = 'APROBADA' OR (cr.estado_requerido = 'REGULAR' AND x.estado = 'CURSADA_APROBADA')));
    IF v_faltan IS NOT NULL THEN
        RETURN 'Te faltan correlativas: ' || v_faltan;
    END IF;

    IF v_co.cupo IS NOT NULL AND (
        SELECT count(*) FROM sga.inscripcion_curso WHERE comision_id = v_co.id AND estado <> 'ABANDONADA') >= v_co.cupo THEN
        RETURN 'No quedan vacantes en esta comisión';
    END IF;

    -- Superposición con las comisiones en las que ya está inscripto ese
    -- cuatrimestre
    SELECT string_agg(DISTINCT m2.codigo, ', ') INTO v_choque
    FROM sga.horario_comision h
    JOIN sga.horario_comision h2 ON h2.dia_semana = h.dia_semana
         AND h2.hora_inicio < h.hora_fin AND h.hora_inicio < h2.hora_fin
    JOIN sga.inscripcion_curso ic2 ON ic2.comision_id = h2.comision_id
         AND ic2.legajo_id = p_legajo_id AND ic2.estado = 'CURSANDO'
    JOIN sga.curso c2 ON c2.id = ic2.curso_id AND c2.anio = v_curso.anio AND c2.periodo = v_curso.periodo
    JOIN sga.materia m2 ON m2.id = c2.materia_id
    WHERE h.comision_id = v_co.id;
    IF v_choque IS NOT NULL THEN
        RETURN 'Se superpone con el horario de ' || v_choque;
    END IF;

    RETURN NULL;
END;
$$;

-- Comisiones de los cuatrimestres con inscripción abierta o próxima, de
-- las materias del plan del alumno.
CREATE FUNCTION sga.cursadas_para_mi()
RETURNS TABLE (
    comision_id INTEGER,
    curso_id INTEGER,
    anio INTEGER,
    periodo TEXT,
    inscripcion_desde DATE,
    inscripcion_hasta DATE,
    codigo TEXT,
    materia TEXT,
    creditos INTEGER,
    comision TEXT,
    cupo INTEGER,
    inscriptos INTEGER,
    inscripcion_id INTEGER,
    motivo TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    WITH yo AS (SELECT l.id AS legajo, l.plan_estudio_id AS plan FROM sga.legajo l WHERE l.id = sga.legajo_actual_id())
    SELECT co.id, c.id, c.anio, c.periodo::TEXT, p.desde, p.hasta, m.codigo::TEXT, m.nombre::TEXT, m.creditos,
           co.nombre::TEXT, co.cupo,
           (SELECT count(*) FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.estado <> 'ABANDONADA')::INTEGER,
           (SELECT x.id FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.legajo_id = yo.legajo AND x.estado = 'CURSANDO'),
           sga.motivo_no_inscripcion_cursada(co.id, yo.legajo)
    FROM yo
    JOIN sga.periodo_inscripcion_cursada p ON p.hasta >= sga.hoy() - 7
    JOIN sga.curso c ON c.anio = p.anio AND c.periodo = p.periodo AND c.activo
    JOIN sga.plan_materia pm ON pm.plan_id = yo.plan AND pm.materia_id = c.materia_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.comision co ON co.curso_id = c.id
    ORDER BY c.anio, c.periodo, m.codigo, co.nombre;
$$;

CREATE FUNCTION sga.inscribirse_cursada(p_comision_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_motivo TEXT;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    -- El cupo se toma por orden de llegada: se bloquea la comisión (y el
    -- legajo, para las superposiciones) mientras se verifica e inscribe.
    PERFORM 1 FROM sga.comision WHERE id = p_comision_id FOR UPDATE;
    PERFORM 1 FROM sga.legajo WHERE id = v_legajo FOR UPDATE;
    v_motivo := sga.motivo_no_inscripcion_cursada(p_comision_id, v_legajo);
    IF v_motivo IS NOT NULL THEN
        RAISE EXCEPTION '%', v_motivo USING ERRCODE = '23514';
    END IF;

    INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
    SELECT v_legajo, curso_id, id FROM sga.comision WHERE id = p_comision_id;
END;
$$;

CREATE FUNCTION sga.desinscribirse_cursada(p_inscripcion_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ic sga.inscripcion_curso%ROWTYPE;
    v_curso sga.curso%ROWTYPE;
BEGIN
    SELECT * INTO v_ic FROM sga.inscripcion_curso WHERE id = p_inscripcion_id AND legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No estás inscripto en esa cursada' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_curso FROM sga.curso WHERE id = v_ic.curso_id;
    IF v_ic.estado <> 'CURSANDO' OR v_ic.nota_cursada IS NOT NULL OR NOT EXISTS (
        SELECT 1 FROM sga.periodo_inscripcion_cursada p
        WHERE p.anio = v_curso.anio AND p.periodo = v_curso.periodo AND sga.hoy() BETWEEN p.desde AND p.hasta) THEN
        RAISE EXCEPTION 'Ya no te podés dar de baja: la inscripción del cuatrimestre está cerrada' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.inscripcion_curso WHERE id = v_ic.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.motivo_no_inscripcion_cursada(INTEGER, INTEGER),
    sga.cursadas_para_mi(),
    sga.inscribirse_cursada(INTEGER),
    sga.desinscribirse_cursada(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.cursadas_para_mi(),
    sga.inscribirse_cursada(INTEGER),
    sga.desinscribirse_cursada(INTEGER)
TO authenticated;
