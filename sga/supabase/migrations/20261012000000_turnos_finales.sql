-- =====================================================================
-- Exámenes finales por turnos.
--
--   - turno_examen: julio, diciembre, febrero… con su período de
--     inscripción. Cada fecha de final (examen_final) pertenece a un turno
--     (julio y diciembre suelen tener 2 fechas por materia, febrero 1).
--   - Las fechas son de la MATERIA: un alumno que cursó en cualquier
--     cuatrimestre rinde en las fechas de la materia (examen_final.curso_id
--     queda como curso de referencia). Lo corrige el trigger de la regla 4.
--   - inscribirse_final(): el alumno se anota a una fecha si
--       · el turno tiene la inscripción abierta,
--       · faltan más de 48 h para el examen (después queda cerrada),
--       · tiene la cursada aprobada y no aprobó el final,
--       · tiene aprobadas las correlativas "para rendir",
--       · no se anotó a otra fecha de la misma materia en el turno,
--       · no tiene una fecha anterior sin nota (ni ausente) cargada.
--   - desinscribirse_final(): hasta 48 h antes.
--   - Las fechas las ve, y les carga nota, cualquier docente de la
--     materia (la cátedra), no solo el de la comisión del alumno.
--     "Ausente" borra la inscripción: no cuenta como intento.
-- =====================================================================

CREATE TABLE sga.turno_examen (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    inscripcion_desde DATE NOT NULL,
    inscripcion_hasta DATE NOT NULL,

    CONSTRAINT uq_turno_examen_nombre UNIQUE (nombre),
    CONSTRAINT ck_turno_examen_inscripcion CHECK (inscripcion_hasta >= inscripcion_desde)
);

ALTER TABLE sga.turno_examen ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.turno_examen FORCE ROW LEVEL SECURITY;
CREATE POLICY turno_examen_select_autenticados ON sga.turno_examen FOR SELECT TO authenticated USING (true);
CREATE POLICY turno_examen_admin_all ON sga.turno_examen
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.turno_examen TO authenticated;
GRANT USAGE ON SEQUENCE sga.turno_examen_id_seq TO authenticated;

ALTER TABLE sga.examen_final ADD COLUMN turno_id INTEGER REFERENCES sga.turno_examen (id) ON DELETE RESTRICT;
CREATE INDEX ix_examen_final_turno_id ON sga.examen_final (turno_id);

-- Regla 4: la fecha de final tiene que ser de la misma materia que la
-- cursada (antes: del mismo curso).
CREATE OR REPLACE FUNCTION sga.validar_examen_final_pertenece_a_curso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (SELECT c.materia_id FROM sga.inscripcion_curso ic JOIN sga.curso c ON c.id = ic.curso_id WHERE ic.id = NEW.inscripcion_curso_id)
        IS DISTINCT FROM
       (SELECT c.materia_id FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id WHERE ef.id = NEW.examen_final_id) THEN
        RAISE EXCEPTION 'El examen final % no es de la materia de la inscripción %', NEW.examen_final_id, NEW.inscripcion_curso_id
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
-- Ayudas
-- ---------------------------------------------------------------------

-- Momento en que cierra la inscripción a una fecha: 48 h antes del examen
-- (hora de Buenos Aires).
CREATE FUNCTION sga.cierre_inscripcion_final(p_fecha DATE, p_hora TIME)
RETURNS TIMESTAMPTZ
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT ((p_fecha + p_hora) AT TIME ZONE 'America/Argentina/Buenos_Aires') - INTERVAL '48 hours';
$$;

CREATE FUNCTION sga.es_docente_de_materia(p_materia_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM sga.docente_comision dc
        JOIN sga.comision co ON co.id = dc.comision_id
        JOIN sga.curso c ON c.id = co.curso_id
        WHERE c.materia_id = p_materia_id AND dc.docente_id = sga.docente_actual_id());
$$;

-- Por qué el alumno (legajo) no puede anotarse a la fecha; NULL si puede.
CREATE FUNCTION sga.motivo_no_inscripcion_final(p_examen_final_id INTEGER, p_legajo_id INTEGER)
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
    WHERE ief.inscripcion_curso_id = v_ic.id AND ief.nota_final IS NULL
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

-- ---------------------------------------------------------------------
-- Alumno
-- ---------------------------------------------------------------------

-- Fechas de los turnos con inscripción abierta o próxima, para las
-- materias que el alumno tiene pendientes de final (o en las que está
-- anotado).
CREATE FUNCTION sga.finales_para_mi()
RETURNS TABLE (
    examen_final_id INTEGER,
    turno TEXT,
    inscripcion_desde DATE,
    inscripcion_hasta DATE,
    codigo TEXT,
    materia TEXT,
    fecha DATE,
    hora_inicio TIME,
    aula TEXT,
    cierre TIMESTAMPTZ,
    inscripcion_id INTEGER,
    motivo TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    WITH yo AS (SELECT sga.legajo_actual_id() AS legajo),
    materias AS (
        SELECT DISTINCT c.materia_id
        FROM sga.inscripcion_curso ic JOIN sga.curso c ON c.id = ic.curso_id, yo
        WHERE ic.legajo_id = yo.legajo AND ic.estado IN ('CURSADA_APROBADA', 'APROBADA')
    )
    SELECT ef.id, t.nombre::TEXT, t.inscripcion_desde, t.inscripcion_hasta, m.codigo::TEXT, m.nombre::TEXT,
           ef.fecha, ef.hora_inicio, a.codigo::TEXT,
           sga.cierre_inscripcion_final(ef.fecha, ef.hora_inicio),
           (SELECT ief.id FROM sga.inscripcion_examen_final ief JOIN sga.inscripcion_curso ic ON ic.id = ief.inscripcion_curso_id
            WHERE ief.examen_final_id = ef.id AND ic.legajo_id = yo.legajo),
           sga.motivo_no_inscripcion_final(ef.id, yo.legajo)
    FROM sga.examen_final ef
    JOIN sga.turno_examen t ON t.id = ef.turno_id
    JOIN sga.curso c ON c.id = ef.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN materias mm ON mm.materia_id = c.materia_id
    LEFT JOIN sga.aula a ON a.id = ef.aula_id
    CROSS JOIN yo
    WHERE ef.fecha >= sga.hoy() - 30
    ORDER BY t.inscripcion_desde, m.codigo, ef.fecha;
$$;

CREATE FUNCTION sga.inscribirse_final(p_examen_final_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_motivo TEXT;
    v_ic INTEGER;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    -- Serializa las inscripciones del mismo alumno (evita anotarse a dos
    -- fechas a la vez con dos pedidos simultáneos)
    PERFORM 1 FROM sga.legajo WHERE id = v_legajo FOR UPDATE;
    v_motivo := sga.motivo_no_inscripcion_final(p_examen_final_id, v_legajo);
    IF v_motivo IS NOT NULL THEN
        RAISE EXCEPTION '%', v_motivo USING ERRCODE = '23514';
    END IF;

    SELECT ic.id INTO v_ic
    FROM sga.inscripcion_curso ic JOIN sga.curso c ON c.id = ic.curso_id
    WHERE ic.legajo_id = v_legajo AND ic.estado = 'CURSADA_APROBADA'
      AND c.materia_id = (SELECT c2.materia_id FROM sga.examen_final ef JOIN sga.curso c2 ON c2.id = ef.curso_id WHERE ef.id = p_examen_final_id)
    ORDER BY c.fecha_inicio DESC LIMIT 1;

    INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
    VALUES (v_ic, p_examen_final_id,
            (SELECT count(*) + 1 FROM sga.inscripcion_examen_final WHERE inscripcion_curso_id = v_ic));
END;
$$;

CREATE FUNCTION sga.desinscribirse_final(p_inscripcion_examen_final_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ief sga.inscripcion_examen_final%ROWTYPE;
    v_ef sga.examen_final%ROWTYPE;
BEGIN
    SELECT ief.* INTO v_ief
    FROM sga.inscripcion_examen_final ief JOIN sga.inscripcion_curso ic ON ic.id = ief.inscripcion_curso_id
    WHERE ief.id = p_inscripcion_examen_final_id AND ic.legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No estás anotado a esa fecha' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_ef FROM sga.examen_final WHERE id = v_ief.examen_final_id;
    IF v_ief.nota_final IS NOT NULL OR now() >= sga.cierre_inscripcion_final(v_ef.fecha, v_ef.hora_inicio) THEN
        RAISE EXCEPTION 'Ya no te podés dar de baja: faltan menos de 48 h para el examen' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.inscripcion_examen_final WHERE id = v_ief.id;
END;
$$;

-- ---------------------------------------------------------------------
-- Docentes (la cátedra) y Administración
-- ---------------------------------------------------------------------

-- Reemplaza la versión por comisión: fechas de las materias que dicta.
DROP FUNCTION sga.mesas_de_final_docente();
CREATE FUNCTION sga.mesas_de_final_docente()
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
           count(ief.id) FILTER (WHERE ief.nota_final IS NULL)::INTEGER
    FROM sga.examen_final ef
    JOIN sga.curso c ON c.id = ef.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    LEFT JOIN sga.turno_examen t ON t.id = ef.turno_id
    LEFT JOIN sga.inscripcion_examen_final ief ON ief.examen_final_id = ef.id
    WHERE sga.es_docente_de_materia(c.materia_id)
    GROUP BY ef.id, c.id, m.codigo, m.nombre, t.nombre
    ORDER BY ef.fecha DESC, m.codigo;
$$;

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
           c.periodo || ' ' || c.anio, ief.numero_intento, ic.nota_cursada, ief.nota_final, ic.nota_definitiva
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

-- Reemplaza la versión por comisión: la carga cualquier docente de la
-- materia. p_ausente borra la inscripción (no cuenta como intento).
DROP FUNCTION sga.cargar_nota_final(INTEGER, NUMERIC);
CREATE FUNCTION sga.cargar_nota_final(p_inscripcion_examen_final_id INTEGER, p_nota NUMERIC, p_ausente BOOLEAN DEFAULT FALSE)
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
    IF v_ief.nota_final IS NOT NULL THEN
        RAISE EXCEPTION 'La nota ya está cargada; para corregirla pedíselo a Administración' USING ERRCODE = '23514';
    END IF;

    IF p_ausente THEN
        DELETE FROM sga.inscripcion_examen_final WHERE id = v_ief.id;
        RETURN;
    END IF;
    IF p_nota IS NULL OR p_nota < 0 OR p_nota > 10 THEN
        RAISE EXCEPTION 'La nota tiene que estar entre 0 y 10' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.inscripcion_examen_final
    SET nota_final = round(p_nota, 2), fecha_carga_final = now(), docente_id = sga.docente_actual_id()
    WHERE id = v_ief.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.es_docente_de_materia(INTEGER),
    sga.motivo_no_inscripcion_final(INTEGER, INTEGER),
    sga.finales_para_mi(),
    sga.inscribirse_final(INTEGER),
    sga.desinscribirse_final(INTEGER),
    sga.mesas_de_final_docente(),
    sga.inscriptos_fecha_final(INTEGER),
    sga.cargar_nota_final(INTEGER, NUMERIC, BOOLEAN)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.finales_para_mi(),
    sga.inscribirse_final(INTEGER),
    sga.desinscribirse_final(INTEGER),
    sga.mesas_de_final_docente(),
    sga.inscriptos_fecha_final(INTEGER),
    sga.cargar_nota_final(INTEGER, NUMERIC, BOOLEAN)
TO authenticated;
