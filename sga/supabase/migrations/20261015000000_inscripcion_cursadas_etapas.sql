-- =====================================================================
-- Inscripción a cursadas en tres etapas (reemplaza el "orden de
-- llegada" de 20261013000000):
--
--   1. PRIMERA inscripción (desde .. hasta): el alumno SOLICITA una
--      comisión por materia. No se controla el cupo; sí plan, situación
--      en la materia, correlativas para cursar y superposición.
--   2. ASIGNACIÓN (entre las dos inscripciones): Administración decide,
--      por comisión, quién se queda con las vacantes (automático según
--      pautas y/o a mano) y confirma: los asignados quedan inscriptos.
--   3. SEGUNDA inscripción (segunda_desde .. segunda_hasta): el alumno ve
--      dónde quedó y hace cambios (baja, cambio de comisión, materias
--      nuevas) solo donde quedan vacantes.
--
-- Pautas de la asignación automática: más créditos aprobados (avance en
-- la carrera), mejor rendimiento académico, solicitud más antigua.
-- =====================================================================

ALTER TABLE sga.periodo_inscripcion_cursada
    ADD COLUMN segunda_desde DATE,
    ADD COLUMN segunda_hasta DATE,
    ADD COLUMN asignacion_confirmada BOOLEAN NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT ck_periodo_inscripcion_cursada_segunda CHECK (
        (segunda_desde IS NULL AND segunda_hasta IS NULL)
        OR (segunda_desde > hasta AND segunda_hasta >= segunda_desde));

CREATE TABLE sga.solicitud_cursada (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL REFERENCES sga.legajo (id) ON DELETE CASCADE,
    curso_id INTEGER NOT NULL REFERENCES sga.curso (id) ON DELETE CASCADE,
    comision_id INTEGER NOT NULL REFERENCES sga.comision (id) ON DELETE CASCADE,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado VARCHAR NOT NULL DEFAULT 'PENDIENTE',

    CONSTRAINT uq_solicitud_cursada UNIQUE (legajo_id, curso_id),
    CONSTRAINT ck_solicitud_cursada_estado CHECK (estado IN ('PENDIENTE', 'ASIGNADA', 'NO_ASIGNADA'))
);

CREATE INDEX ix_solicitud_cursada_comision_id ON sga.solicitud_cursada (comision_id);

ALTER TABLE sga.solicitud_cursada ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.solicitud_cursada FORCE ROW LEVEL SECURITY;
CREATE POLICY solicitud_cursada_select ON sga.solicitud_cursada
    FOR SELECT TO authenticated USING (legajo_id = sga.legajo_actual_id() OR sga.es_admin());
GRANT SELECT ON sga.solicitud_cursada TO authenticated;

-- ---------------------------------------------------------------------
-- Etapa
-- ---------------------------------------------------------------------

-- PROXIMA, PRIMERA, ASIGNACION, SEGUNDA o CERRADA
CREATE FUNCTION sga.etapa_inscripcion_cursada(p sga.periodo_inscripcion_cursada)
RETURNS TEXT
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
    SELECT CASE
        WHEN p.id IS NULL THEN 'CERRADA'
        WHEN sga.hoy() < p.desde THEN 'PROXIMA'
        WHEN sga.hoy() <= p.hasta THEN 'PRIMERA'
        WHEN p.segunda_desde IS NOT NULL AND sga.hoy() < p.segunda_desde THEN 'ASIGNACION'
        WHEN p.segunda_desde IS NOT NULL AND sga.hoy() <= p.segunda_hasta THEN 'SEGUNDA'
        ELSE 'CERRADA'
    END;
$$;

CREATE FUNCTION sga.creditos_aprobados(p_legajo_id INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT COALESCE(sum(m.creditos), 0)::INTEGER
    FROM sga.inscripcion_curso ic
    JOIN sga.curso c ON c.id = ic.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE ic.legajo_id = p_legajo_id AND ic.estado = 'APROBADA';
$$;

-- ---------------------------------------------------------------------
-- Alumno
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sga.motivo_no_inscripcion_cursada(p_comision_id INTEGER, p_legajo_id INTEGER)
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
    v_etapa TEXT;
    v_plan INTEGER;
    v_actual RECORD;
    v_solicitud RECORD;
    v_faltan TEXT;
    v_choque TEXT;
BEGIN
    SELECT * INTO v_co FROM sga.comision WHERE id = p_comision_id;
    IF NOT FOUND THEN RETURN 'La comisión no existe'; END IF;
    SELECT * INTO v_curso FROM sga.curso WHERE id = v_co.curso_id;
    SELECT plan_estudio_id INTO v_plan FROM sga.legajo WHERE id = p_legajo_id;

    SELECT * INTO v_periodo FROM sga.periodo_inscripcion_cursada WHERE anio = v_curso.anio AND periodo = v_curso.periodo;
    v_etapa := sga.etapa_inscripcion_cursada(v_periodo);
    IF v_etapa = 'PROXIMA' THEN
        RETURN format('La inscripción abre el %s', to_char(v_periodo.desde, 'DD/MM/YYYY'));
    ELSIF v_etapa = 'ASIGNACION' THEN
        RETURN format('Asignación de vacantes en curso; la segunda inscripción abre el %s', to_char(v_periodo.segunda_desde, 'DD/MM/YYYY'));
    ELSIF v_etapa = 'CERRADA' THEN
        RETURN 'La inscripción de este cuatrimestre está cerrada';
    END IF;
    IF NOT v_curso.activo THEN RETURN 'El curso no está activo'; END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.plan_materia WHERE plan_id = v_plan AND materia_id = v_curso.materia_id) THEN
        RETURN 'La materia no es de tu plan';
    END IF;

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

    IF v_etapa = 'PRIMERA' THEN
        SELECT s.comision_id, co.nombre AS comision INTO v_solicitud
        FROM sga.solicitud_cursada s JOIN sga.comision co ON co.id = s.comision_id
        WHERE s.legajo_id = p_legajo_id AND s.curso_id = v_curso.id;
        IF FOUND THEN
            IF v_solicitud.comision_id = v_co.id THEN RETURN 'Ya solicitaste esta comisión'; END IF;
            RETURN format('Ya solicitaste la comisión %s (retirá la solicitud para cambiar)', v_solicitud.comision);
        END IF;
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

    -- El cupo solo se controla en la segunda inscripción
    IF v_etapa = 'SEGUNDA' AND v_co.cupo IS NOT NULL AND (
        SELECT count(*) FROM sga.inscripcion_curso WHERE comision_id = v_co.id AND estado <> 'ABANDONADA') >= v_co.cupo THEN
        RETURN 'No quedan vacantes en esta comisión';
    END IF;

    -- Superposición con lo que ya tiene ese cuatrimestre: inscripciones y,
    -- en la primera etapa, solicitudes
    SELECT string_agg(DISTINCT m2.codigo, ', ') INTO v_choque
    FROM sga.horario_comision h
    JOIN sga.horario_comision h2 ON h2.dia_semana = h.dia_semana
         AND h2.hora_inicio < h.hora_fin AND h.hora_inicio < h2.hora_fin
    JOIN sga.comision co2 ON co2.id = h2.comision_id
    JOIN sga.curso c2 ON c2.id = co2.curso_id AND c2.anio = v_curso.anio AND c2.periodo = v_curso.periodo AND c2.id <> v_curso.id
    JOIN sga.materia m2 ON m2.id = c2.materia_id
    WHERE h.comision_id = v_co.id
      AND (EXISTS (SELECT 1 FROM sga.inscripcion_curso ic2
                   WHERE ic2.comision_id = co2.id AND ic2.legajo_id = p_legajo_id AND ic2.estado = 'CURSANDO')
           OR (v_etapa = 'PRIMERA' AND EXISTS (SELECT 1 FROM sga.solicitud_cursada s2
                   WHERE s2.comision_id = co2.id AND s2.legajo_id = p_legajo_id)));
    IF v_choque IS NOT NULL THEN
        RETURN 'Se superpone con el horario de ' || v_choque;
    END IF;

    RETURN NULL;
END;
$$;

DROP FUNCTION sga.cursadas_para_mi();
CREATE FUNCTION sga.cursadas_para_mi()
RETURNS TABLE (
    comision_id INTEGER,
    curso_id INTEGER,
    anio INTEGER,
    periodo TEXT,
    etapa TEXT,
    inscripcion_desde DATE,
    inscripcion_hasta DATE,
    segunda_desde DATE,
    segunda_hasta DATE,
    asignacion_confirmada BOOLEAN,
    codigo TEXT,
    materia TEXT,
    creditos INTEGER,
    comision TEXT,
    cupo INTEGER,
    inscriptos INTEGER,
    inscripcion_id INTEGER,
    solicitud_id INTEGER,
    solicitud_estado TEXT,
    motivo TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    WITH yo AS (SELECT l.id AS legajo, l.plan_estudio_id AS plan FROM sga.legajo l WHERE l.id = sga.legajo_actual_id())
    SELECT co.id, c.id, c.anio, c.periodo::TEXT, sga.etapa_inscripcion_cursada(p),
           p.desde, p.hasta, p.segunda_desde, p.segunda_hasta, p.asignacion_confirmada,
           m.codigo::TEXT, m.nombre::TEXT, m.creditos, co.nombre::TEXT, co.cupo,
           (SELECT count(*) FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.estado <> 'ABANDONADA')::INTEGER,
           (SELECT x.id FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.legajo_id = yo.legajo AND x.estado = 'CURSANDO'),
           s.id, s.estado::TEXT,
           sga.motivo_no_inscripcion_cursada(co.id, yo.legajo)
    FROM yo
    JOIN sga.periodo_inscripcion_cursada p ON COALESCE(p.segunda_hasta, p.hasta) >= sga.hoy() - 7
    JOIN sga.curso c ON c.anio = p.anio AND c.periodo = p.periodo AND c.activo
    JOIN sga.plan_materia pm ON pm.plan_id = yo.plan AND pm.materia_id = c.materia_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.comision co ON co.curso_id = c.id
    LEFT JOIN sga.solicitud_cursada s ON s.legajo_id = yo.legajo AND s.comision_id = co.id
    ORDER BY c.anio, c.periodo, m.codigo, co.nombre;
$$;

-- Primera inscripción: registra la solicitud. Segunda: inscribe si hay
-- vacante (se bloquea la comisión mientras se verifica).
CREATE OR REPLACE FUNCTION sga.inscribirse_cursada(p_comision_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_motivo TEXT;
    v_etapa TEXT;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    PERFORM 1 FROM sga.comision WHERE id = p_comision_id FOR UPDATE;
    PERFORM 1 FROM sga.legajo WHERE id = v_legajo FOR UPDATE;
    v_motivo := sga.motivo_no_inscripcion_cursada(p_comision_id, v_legajo);
    IF v_motivo IS NOT NULL THEN
        RAISE EXCEPTION '%', v_motivo USING ERRCODE = '23514';
    END IF;

    SELECT sga.etapa_inscripcion_cursada(p) INTO v_etapa
    FROM sga.comision co JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo
    WHERE co.id = p_comision_id;

    IF v_etapa = 'PRIMERA' THEN
        INSERT INTO sga.solicitud_cursada (legajo_id, curso_id, comision_id)
        SELECT v_legajo, curso_id, id FROM sga.comision WHERE id = p_comision_id;
    ELSE
        INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
        SELECT v_legajo, curso_id, id FROM sga.comision WHERE id = p_comision_id;
    END IF;
END;
$$;

CREATE FUNCTION sga.retirar_solicitud_cursada(p_solicitud_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_etapa TEXT;
BEGIN
    SELECT sga.etapa_inscripcion_cursada(p) INTO v_etapa
    FROM sga.solicitud_cursada s JOIN sga.curso c ON c.id = s.curso_id
    JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo
    WHERE s.id = p_solicitud_id AND s.legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés esa solicitud' USING ERRCODE = '42501';
    END IF;
    IF v_etapa <> 'PRIMERA' THEN
        RAISE EXCEPTION 'La primera inscripción ya cerró: la solicitud no se puede retirar' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.solicitud_cursada WHERE id = p_solicitud_id;
END;
$$;

-- Baja de una cursada: solo en la segunda inscripción
CREATE OR REPLACE FUNCTION sga.desinscribirse_cursada(p_inscripcion_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ic sga.inscripcion_curso%ROWTYPE;
    v_etapa TEXT;
BEGIN
    SELECT * INTO v_ic FROM sga.inscripcion_curso WHERE id = p_inscripcion_id AND legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No estás inscripto en esa cursada' USING ERRCODE = '42501';
    END IF;
    SELECT sga.etapa_inscripcion_cursada(p) INTO v_etapa
    FROM sga.curso c LEFT JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo
    WHERE c.id = v_ic.curso_id;
    IF v_ic.estado <> 'CURSANDO' OR v_ic.nota_cursada IS NOT NULL OR v_etapa IS DISTINCT FROM 'SEGUNDA' THEN
        RAISE EXCEPTION 'Solo te podés dar de baja durante la segunda inscripción' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.inscripcion_curso WHERE id = v_ic.id;
END;
$$;

-- ---------------------------------------------------------------------
-- Administración
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.solicitudes_cursada(p_periodo_id INTEGER)
RETURNS TABLE (
    solicitud_id INTEGER,
    comision_id INTEGER,
    codigo TEXT,
    materia TEXT,
    comision TEXT,
    cupo INTEGER,
    ya_inscriptos INTEGER,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    creditos_aprobados INTEGER,
    rendimiento NUMERIC,
    fecha TIMESTAMPTZ,
    estado TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración ve las solicitudes' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT s.id, co.id, m.codigo::TEXT, m.nombre::TEXT, co.nombre::TEXT, co.cupo,
           (SELECT count(*) FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.estado <> 'ABANDONADA'
              AND NOT EXISTS (SELECT 1 FROM sga.solicitud_cursada s3 WHERE s3.legajo_id = x.legajo_id AND s3.comision_id = co.id))::INTEGER,
           pe.apellido::TEXT, pe.nombre::TEXT, l.numero_legajo::TEXT,
           sga.creditos_aprobados(l.id), l.rendimiento_academico, s.fecha, s.estado::TEXT
    FROM sga.periodo_inscripcion_cursada p
    JOIN sga.curso c ON c.anio = p.anio AND c.periodo = p.periodo
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.comision co ON co.curso_id = c.id
    JOIN sga.solicitud_cursada s ON s.comision_id = co.id
    JOIN sga.legajo l ON l.id = s.legajo_id
    JOIN sga.persona pe ON pe.id = l.persona_id
    WHERE p.id = p_periodo_id
    ORDER BY m.codigo, co.nombre, sga.creditos_aprobados(l.id) DESC, l.rendimiento_academico DESC NULLS LAST, s.fecha;
END;
$$;

CREATE FUNCTION sga.validar_asignacion_editable(p_periodo_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_p sga.periodo_inscripcion_cursada%ROWTYPE;
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración asigna vacantes' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_p FROM sga.periodo_inscripcion_cursada WHERE id = p_periodo_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El período no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_p.asignacion_confirmada THEN
        RAISE EXCEPTION 'La asignación de este cuatrimestre ya está confirmada' USING ERRCODE = '23514';
    END IF;
    IF sga.etapa_inscripcion_cursada(v_p) IN ('PROXIMA', 'PRIMERA') THEN
        RAISE EXCEPTION 'La asignación se hace cuando termina la primera inscripción (el %)', to_char(v_p.hasta, 'DD/MM/YYYY')
            USING ERRCODE = '23514';
    END IF;
END;
$$;

-- Asigna las vacantes de cada comisión según las pautas. Devuelve
-- cuántas solicitudes quedaron asignadas.
CREATE FUNCTION sga.asignar_vacantes_automaticamente(p_periodo_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_asignadas INTEGER;
BEGIN
    PERFORM sga.validar_asignacion_editable(p_periodo_id);

    WITH ranking AS (
        SELECT s.id, co.cupo,
               (SELECT count(*) FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.estado <> 'ABANDONADA') AS ocupadas,
               row_number() OVER (
                   PARTITION BY s.comision_id
                   ORDER BY sga.creditos_aprobados(s.legajo_id) DESC, l.rendimiento_academico DESC NULLS LAST, s.fecha, s.id
               ) AS puesto
        FROM sga.solicitud_cursada s
        JOIN sga.comision co ON co.id = s.comision_id
        JOIN sga.curso c ON c.id = co.curso_id
        JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo AND p.id = p_periodo_id
        JOIN sga.legajo l ON l.id = s.legajo_id
    )
    UPDATE sga.solicitud_cursada s
    SET estado = CASE WHEN r.cupo IS NULL OR r.puesto <= r.cupo - r.ocupadas THEN 'ASIGNADA' ELSE 'NO_ASIGNADA' END
    FROM ranking r
    WHERE r.id = s.id;

    SELECT count(*) INTO v_asignadas
    FROM sga.solicitud_cursada s JOIN sga.curso c ON c.id = s.curso_id
    JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo AND p.id = p_periodo_id
    WHERE s.estado = 'ASIGNADA';
    RETURN v_asignadas;
END;
$$;

CREATE FUNCTION sga.marcar_solicitud_cursada(p_solicitud_id INTEGER, p_asignada BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_asignacion_editable(
        (SELECT p.id FROM sga.solicitud_cursada s JOIN sga.curso c ON c.id = s.curso_id
         JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo WHERE s.id = p_solicitud_id));
    UPDATE sga.solicitud_cursada SET estado = CASE WHEN p_asignada THEN 'ASIGNADA' ELSE 'NO_ASIGNADA' END
    WHERE id = p_solicitud_id;
END;
$$;

-- Confirma: los asignados quedan inscriptos y el resto no asignado.
-- Devuelve cuántas inscripciones creó.
CREATE FUNCTION sga.confirmar_asignacion_cursadas(p_periodo_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_excedida TEXT;
    v_creadas INTEGER;
BEGIN
    PERFORM sga.validar_asignacion_editable(p_periodo_id);

    SELECT string_agg(m.codigo || ' ' || co.nombre, ', ') INTO v_excedida
    FROM sga.comision co
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo AND p.id = p_periodo_id
    WHERE co.cupo IS NOT NULL
      AND (SELECT count(*) FROM sga.solicitud_cursada s WHERE s.comision_id = co.id AND s.estado = 'ASIGNADA')
        + (SELECT count(*) FROM sga.inscripcion_curso x WHERE x.comision_id = co.id AND x.estado <> 'ABANDONADA') > co.cupo;
    IF v_excedida IS NOT NULL THEN
        RAISE EXCEPTION 'Hay más asignados que vacantes en: %', v_excedida USING ERRCODE = '23514';
    END IF;

    INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
    SELECT s.legajo_id, s.curso_id, s.comision_id
    FROM sga.solicitud_cursada s JOIN sga.curso c ON c.id = s.curso_id
    JOIN sga.periodo_inscripcion_cursada p ON p.anio = c.anio AND p.periodo = c.periodo AND p.id = p_periodo_id
    WHERE s.estado = 'ASIGNADA'
    ON CONFLICT (legajo_id, curso_id) DO NOTHING;
    GET DIAGNOSTICS v_creadas = ROW_COUNT;

    UPDATE sga.solicitud_cursada s SET estado = 'NO_ASIGNADA'
    FROM sga.curso c, sga.periodo_inscripcion_cursada p
    WHERE c.id = s.curso_id AND p.anio = c.anio AND p.periodo = c.periodo AND p.id = p_periodo_id AND s.estado = 'PENDIENTE';

    UPDATE sga.periodo_inscripcion_cursada SET asignacion_confirmada = TRUE WHERE id = p_periodo_id;
    RETURN v_creadas;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.creditos_aprobados(INTEGER),
    sga.retirar_solicitud_cursada(INTEGER),
    sga.cursadas_para_mi(),
    sga.solicitudes_cursada(INTEGER),
    sga.validar_asignacion_editable(INTEGER),
    sga.asignar_vacantes_automaticamente(INTEGER),
    sga.marcar_solicitud_cursada(INTEGER, BOOLEAN),
    sga.confirmar_asignacion_cursadas(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.retirar_solicitud_cursada(INTEGER),
    sga.cursadas_para_mi(),
    sga.solicitudes_cursada(INTEGER),
    sga.asignar_vacantes_automaticamente(INTEGER),
    sga.marcar_solicitud_cursada(INTEGER, BOOLEAN),
    sga.confirmar_asignacion_cursadas(INTEGER)
TO authenticated;
