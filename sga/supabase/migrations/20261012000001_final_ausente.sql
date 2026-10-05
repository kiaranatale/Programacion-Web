-- =====================================================================
-- Ausente en un final: queda registrado y CUENTA COMO INTENTO.
--
--   - inscripcion_examen_final.ausente: el docente lo marca en lugar de
--     la nota (antes "Ausente" borraba la inscripción).
--   - Si el ausente es en el 3er intento, la cursada queda DESAPROBADA
--     (igual que un 3er final desaprobado).
--   - Una inscripción con ausente ya no está "pendiente de nota".
-- =====================================================================

ALTER TABLE sga.inscripcion_examen_final ADD COLUMN ausente BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE sga.inscripcion_examen_final
    ADD CONSTRAINT ck_inscripcion_examen_final_ausente_sin_nota CHECK (NOT ausente OR nota_final IS NULL);

-- Regla 1 ampliada: el ausente en el 3er intento desaprueba la cursada.
CREATE OR REPLACE FUNCTION sga.procesar_nota_final()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
DECLARE
    v_nota_cursada NUMERIC(5, 2);
BEGIN
    IF NEW.nota_final IS NULL AND NOT NEW.ausente THEN
        RETURN NEW;
    END IF;

    IF NEW.nota_final >= 4 THEN
        SELECT nota_cursada INTO v_nota_cursada FROM sga.inscripcion_curso WHERE id = NEW.inscripcion_curso_id;
        UPDATE sga.inscripcion_curso
        SET nota_definitiva = ROUND((v_nota_cursada + NEW.nota_final) / 2, 2),
            estado = 'APROBADA'
        WHERE id = NEW.inscripcion_curso_id;
    ELSIF NEW.numero_intento = 3 THEN
        UPDATE sga.inscripcion_curso SET estado = 'DESAPROBADA' WHERE id = NEW.inscripcion_curso_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER trg_procesar_nota_final ON sga.inscripcion_examen_final;
CREATE TRIGGER trg_procesar_nota_final
AFTER INSERT OR UPDATE OF nota_final, ausente
ON sga.inscripcion_examen_final
FOR EACH ROW
EXECUTE FUNCTION sga.procesar_nota_final();

-- Docente: nota o ausente, una sola vez, solo a anotados a la fecha.
CREATE OR REPLACE FUNCTION sga.cargar_nota_final(p_inscripcion_examen_final_id INTEGER, p_nota NUMERIC, p_ausente BOOLEAN DEFAULT FALSE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ief sga.inscripcion_examen_final%ROWTYPE;
    v_ef sga.examen_final%ROWTYPE;
    v_materia INTEGER;
BEGIN
    SELECT * INTO v_ief FROM sga.inscripcion_examen_final WHERE id = p_inscripcion_examen_final_id FOR UPDATE;
    SELECT * INTO v_ef FROM sga.examen_final WHERE id = v_ief.examen_final_id;
    SELECT materia_id INTO v_materia FROM sga.curso WHERE id = v_ef.curso_id;
    IF v_ief.id IS NULL OR NOT sga.es_docente_de_materia(v_materia) THEN
        RAISE EXCEPTION 'Solo los docentes de la materia cargan notas de final' USING ERRCODE = '42501';
    END IF;
    IF v_ef.fecha > sga.hoy() THEN
        RAISE EXCEPTION 'El examen todavía no se tomó (es el %)', to_char(v_ef.fecha, 'DD/MM/YYYY') USING ERRCODE = '23514';
    END IF;
    IF v_ief.nota_final IS NOT NULL OR v_ief.ausente THEN
        RAISE EXCEPTION 'La nota ya está cargada; para corregirla pedíselo a Administración' USING ERRCODE = '23514';
    END IF;
    IF NOT p_ausente AND (p_nota IS NULL OR p_nota < 0 OR p_nota > 10) THEN
        RAISE EXCEPTION 'La nota tiene que estar entre 0 y 10' USING ERRCODE = '23514';
    END IF;

    UPDATE sga.inscripcion_examen_final
    SET nota_final = CASE WHEN p_ausente THEN NULL ELSE round(p_nota, 2) END,
        ausente = p_ausente,
        fecha_carga_final = now(),
        docente_id = sga.docente_actual_id()
    WHERE id = v_ief.id;
END;
$$;

-- Pendiente de nota = sin nota y sin ausente
CREATE OR REPLACE FUNCTION sga.mesas_de_final_docente()
RETURNS TABLE (
    examen_final_id INTEGER,
    curso_id INTEGER,
    codigo TEXT,
    materia TEXT,
    turno TEXT,
    fecha DATE,
    hora_inicio TIME,
    inscriptos INTEGER,
    sin_nota INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT ef.id, c.id, m.codigo::TEXT, m.nombre::TEXT, t.nombre::TEXT, ef.fecha, ef.hora_inicio,
           count(ief.id)::INTEGER,
           count(ief.id) FILTER (WHERE ief.nota_final IS NULL AND NOT ief.ausente)::INTEGER
    FROM sga.examen_final ef
    JOIN sga.curso c ON c.id = ef.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    LEFT JOIN sga.turno_examen t ON t.id = ef.turno_id
    LEFT JOIN sga.inscripcion_examen_final ief ON ief.examen_final_id = ef.id
    WHERE sga.es_docente_de_materia(c.materia_id)
    GROUP BY ef.id, c.id, m.codigo, m.nombre, t.nombre
    ORDER BY ef.fecha DESC, m.codigo;
$$;

DROP FUNCTION sga.inscriptos_fecha_final(INTEGER);
CREATE FUNCTION sga.inscriptos_fecha_final(p_examen_final_id INTEGER)
RETURNS TABLE (
    inscripcion_id INTEGER,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    comision TEXT,
    periodo_cursada TEXT,
    numero_intento SMALLINT,
    nota_cursada NUMERIC,
    nota_final NUMERIC,
    ausente BOOLEAN,
    nota_definitiva NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT (sga.es_admin() OR sga.es_docente_de_materia(
            (SELECT c.materia_id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id WHERE ef.id = p_examen_final_id))) THEN
        RAISE EXCEPTION 'Solo los docentes de la materia ven los inscriptos' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT ief.id, p.apellido::TEXT, p.nombre::TEXT, l.numero_legajo::TEXT, co.nombre::TEXT,
           c.periodo || ' ' || c.anio, ief.numero_intento, ic.nota_cursada, ief.nota_final, ief.ausente, ic.nota_definitiva
    FROM sga.inscripcion_examen_final ief
    JOIN sga.inscripcion_curso ic ON ic.id = ief.inscripcion_curso_id
    JOIN sga.comision co ON co.id = ic.comision_id
    JOIN sga.curso c ON c.id = ic.curso_id
    JOIN sga.legajo l ON l.id = ic.legajo_id
    JOIN sga.persona p ON p.id = l.persona_id
    WHERE ief.examen_final_id = p_examen_final_id
    ORDER BY p.apellido, p.nombre;
END;
$$;

REVOKE EXECUTE ON FUNCTION sga.inscriptos_fecha_final(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sga.inscriptos_fecha_final(INTEGER) TO authenticated;

-- Un ausente no deja la nota pendiente (sí cuenta como intento).
CREATE OR REPLACE FUNCTION sga.motivo_no_inscripcion_final(p_examen_final_id INTEGER, p_legajo_id INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ef sga.examen_final%ROWTYPE;
    v_turno sga.turno_examen%ROWTYPE;
    v_materia INTEGER;
    v_plan INTEGER;
    v_ic sga.inscripcion_curso%ROWTYPE;
    v_faltan TEXT;
    v_pendiente DATE;
BEGIN
    SELECT * INTO v_ef FROM sga.examen_final WHERE id = p_examen_final_id;
    IF NOT FOUND THEN RETURN 'La fecha de final no existe'; END IF;
    SELECT * INTO v_turno FROM sga.turno_examen WHERE id = v_ef.turno_id;
    IF NOT FOUND THEN RETURN 'La fecha no pertenece a un turno con inscripción'; END IF;
    SELECT materia_id INTO v_materia FROM sga.curso WHERE id = v_ef.curso_id;
    SELECT plan_estudio_id INTO v_plan FROM sga.legajo WHERE id = p_legajo_id;

    IF EXISTS (SELECT 1 FROM sga.inscripcion_examen_final ief
               JOIN sga.inscripcion_curso ic ON ic.id = ief.inscripcion_curso_id
               WHERE ief.examen_final_id = v_ef.id AND ic.legajo_id = p_legajo_id) THEN
        RETURN 'Ya estás anotado a esta fecha';
    END IF;
    IF sga.hoy() < v_turno.inscripcion_desde THEN
        RETURN format('La inscripción al turno %s abre el %s', v_turno.nombre, to_char(v_turno.inscripcion_desde, 'DD/MM/YYYY'));
    END IF;
    IF sga.hoy() > v_turno.inscripcion_hasta THEN
        RETURN format('La inscripción al turno %s cerró el %s', v_turno.nombre, to_char(v_turno.inscripcion_hasta, 'DD/MM/YYYY'));
    END IF;
    IF now() >= sga.cierre_inscripcion_final(v_ef.fecha, v_ef.hora_inicio) THEN
        RETURN 'La inscripción a esta fecha cerró (48 h antes del examen)';
    END IF;

    -- Cursada aprobada más reciente de la materia
    SELECT ic.* INTO v_ic
    FROM sga.inscripcion_curso ic JOIN sga.curso c ON c.id = ic.curso_id
    WHERE ic.legajo_id = p_legajo_id AND c.materia_id = v_materia
    ORDER BY (ic.estado = 'APROBADA') DESC, c.fecha_inicio DESC
    LIMIT 1;
    IF NOT FOUND THEN RETURN 'No cursaste esta materia'; END IF;
    IF v_ic.estado = 'APROBADA' THEN RETURN 'Ya aprobaste esta materia'; END IF;
    IF v_ic.estado <> 'CURSADA_APROBADA' THEN RETURN 'Necesitás tener la cursada aprobada'; END IF;
    IF (SELECT count(*) FROM sga.inscripcion_examen_final WHERE inscripcion_curso_id = v_ic.id) >= 3 THEN
        RETURN 'Ya usaste los 3 intentos de final de esta cursada';
    END IF;

    IF EXISTS (SELECT 1 FROM sga.inscripcion_examen_final ief JOIN sga.examen_final ef ON ef.id = ief.examen_final_id
               WHERE ief.inscripcion_curso_id = v_ic.id AND ef.turno_id = v_ef.turno_id) THEN
        RETURN format('Ya te anotaste a otra fecha de esta materia en el turno %s', v_turno.nombre);
    END IF;

    SELECT ef.fecha INTO v_pendiente
    FROM sga.inscripcion_examen_final ief JOIN sga.examen_final ef ON ef.id = ief.examen_final_id
    WHERE ief.inscripcion_curso_id = v_ic.id AND ief.nota_final IS NULL AND NOT ief.ausente
    ORDER BY ef.fecha LIMIT 1;
    IF v_pendiente IS NOT NULL AND v_pendiente >= sga.hoy() THEN
        RETURN format('Ya estás anotado a la fecha del %s de esta materia', to_char(v_pendiente, 'DD/MM/YYYY'));
    ELSIF v_pendiente IS NOT NULL THEN
        RETURN format('Todavía no está cargada la nota de tu final del %s', to_char(v_pendiente, 'DD/MM/YYYY'));
    END IF;

    SELECT string_agg(req.codigo, ', ' ORDER BY req.codigo) INTO v_faltan
    FROM sga.correlativa co
    JOIN sga.materia req ON req.id = co.materia_requerida_id
    WHERE co.materia_id = v_materia AND co.tipo_requisito = 'PARA_RENDIR'
      AND (co.plan_id IS NULL OR co.plan_id = v_plan)
      AND NOT EXISTS (
          SELECT 1 FROM sga.inscripcion_curso x JOIN sga.curso cx ON cx.id = x.curso_id
          WHERE x.legajo_id = p_legajo_id AND cx.materia_id = co.materia_requerida_id
            AND (x.estado = 'APROBADA' OR (co.estado_requerido = 'REGULAR' AND x.estado = 'CURSADA_APROBADA')));
    IF v_faltan IS NOT NULL THEN
        RETURN 'Te faltan correlativas para rendir: ' || v_faltan;
    END IF;

    RETURN NULL;
END;
$$;
