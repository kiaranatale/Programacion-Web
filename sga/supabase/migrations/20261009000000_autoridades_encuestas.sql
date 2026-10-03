-- =====================================================================
-- Académica → Autoridades y Encuestas → General.
--
-- Autoridades: vista autoridad_listado con el nombre y mail de cada
-- autoridad (las políticas de persona solo dejan ver la propia). Las
-- designa y da de baja Administración (políticas de catálogo existentes).
--
-- Encuestas:
--   - encuesta_pregunta: preguntas de escala (1 a 5) o de texto libre.
--   - Anonimato: encuesta_participacion registra QUIÉN respondió (para
--     no responder dos veces) y encuesta_respuesta QUÉ se respondió, sin
--     persona y solo con la fecha. Nadie lee encuesta_respuesta
--     directamente: los resultados salen agregados de
--     resultados_encuesta.
--   - Responden: las de tipo ALUMNOS, todos los alumnos con legajo; las
--     de DESEMPENO_DOCENTE, los alumnos de esa comisión.
--   - Resultados: Administración siempre; el docente evaluado cuando la
--     encuesta terminó y la respondieron al menos 3 alumnos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Autoridades
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.hoy()
RETURNS DATE
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
    SELECT (now() AT TIME ZONE 'America/Argentina/Buenos_Aires')::DATE;
$$;

CREATE VIEW sga.autoridad_listado AS
SELECT
    a.id,
    c.nombre AS cargo,
    p.apellido,
    p.nombre,
    p.mail_institucional,
    e.nombre AS escuela,
    a.fecha_desde,
    a.fecha_hasta,
    (a.fecha_hasta IS NULL OR a.fecha_hasta >= sga.hoy()) AS vigente
FROM sga.autoridad a
JOIN sga.cargo_institucional c ON c.id = a.cargo_institucional_id
JOIN sga.persona p ON p.id = a.persona_id
LEFT JOIN sga.escuela e ON e.id = a.escuela_id;

REVOKE ALL ON sga.autoridad_listado FROM anon;
GRANT SELECT ON sga.autoridad_listado TO authenticated;

-- ---------------------------------------------------------------------
-- Encuestas: tablas
-- ---------------------------------------------------------------------

ALTER TABLE sga.encuesta ADD COLUMN descripcion TEXT;

CREATE TABLE sga.encuesta_pregunta (
    id SERIAL PRIMARY KEY,
    encuesta_id INTEGER NOT NULL REFERENCES sga.encuesta (id) ON DELETE CASCADE,
    orden INTEGER NOT NULL,
    texto VARCHAR(300) NOT NULL,
    tipo VARCHAR NOT NULL,

    CONSTRAINT uq_encuesta_pregunta_orden UNIQUE (encuesta_id, orden),
    CONSTRAINT ck_encuesta_pregunta_tipo CHECK (tipo IN ('ESCALA', 'TEXTO')),
    CONSTRAINT ck_encuesta_pregunta_texto CHECK (btrim(texto) <> '')
);

ALTER TABLE sga.encuesta_pregunta ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.encuesta_pregunta FORCE ROW LEVEL SECURITY;
CREATE POLICY encuesta_pregunta_select_autenticados ON sga.encuesta_pregunta
    FOR SELECT TO authenticated USING (true);
CREATE POLICY encuesta_pregunta_admin_all ON sga.encuesta_pregunta
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.encuesta_pregunta TO authenticated;
GRANT USAGE ON SEQUENCE sga.encuesta_pregunta_id_seq TO authenticated;

CREATE TABLE sga.encuesta_participacion (
    encuesta_id INTEGER NOT NULL REFERENCES sga.encuesta (id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL REFERENCES sga.persona (id) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT sga.hoy(),

    PRIMARY KEY (encuesta_id, persona_id)
);

ALTER TABLE sga.encuesta_participacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.encuesta_participacion FORCE ROW LEVEL SECURITY;
CREATE POLICY encuesta_participacion_select_propia ON sga.encuesta_participacion
    FOR SELECT TO authenticated USING (persona_id = sga.persona_actual_id());
GRANT SELECT ON sga.encuesta_participacion TO authenticated;

-- encuesta_respuesta deja de guardar la persona (pasa a
-- encuesta_participacion) y la hora.
DROP POLICY encuesta_respuesta_select_propia ON sga.encuesta_respuesta;
DROP POLICY encuesta_respuesta_insert_propia ON sga.encuesta_respuesta;
DROP POLICY encuesta_respuesta_admin_write ON sga.encuesta_respuesta;
ALTER TABLE sga.encuesta_respuesta DROP CONSTRAINT uq_encuesta_respuesta;
ALTER TABLE sga.encuesta_respuesta DROP COLUMN persona_id;
ALTER TABLE sga.encuesta_respuesta ALTER COLUMN fecha_respuesta TYPE DATE;
ALTER TABLE sga.encuesta_respuesta ALTER COLUMN fecha_respuesta SET DEFAULT sga.hoy();
REVOKE ALL ON sga.encuesta_respuesta FROM authenticated, anon;

-- ---------------------------------------------------------------------
-- Encuestas: reglas
-- ---------------------------------------------------------------------

-- PROGRAMADA (todavía no empezó), ACTIVA o FINALIZADA (cerrada a mano o
-- vencida).
CREATE FUNCTION sga.estado_encuesta_actual(p_estado sga.estado_encuesta, p_inicio DATE, p_fin DATE)
RETURNS TEXT
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
    SELECT CASE
        WHEN p_estado = 'FINALIZADA' OR sga.hoy() > p_fin THEN 'FINALIZADA'
        WHEN sga.hoy() < p_inicio THEN 'PROGRAMADA'
        ELSE 'ACTIVA'
    END;
$$;

CREATE FUNCTION sga.es_destinatario_encuesta(p_encuesta_id INTEGER, p_persona_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM sga.encuesta e
        WHERE e.id = p_encuesta_id
          AND (
              (e.tipo = 'ALUMNOS' AND EXISTS (SELECT 1 FROM sga.legajo l WHERE l.persona_id = p_persona_id))
              OR (e.tipo = 'DESEMPENO_DOCENTE' AND EXISTS (
                  SELECT 1
                  FROM sga.docente_comision dc
                  JOIN sga.inscripcion_curso ic ON ic.comision_id = dc.comision_id
                  JOIN sga.legajo l ON l.id = ic.legajo_id
                  WHERE dc.id = e.docente_comision_id
                    AND l.persona_id = p_persona_id
                    AND ic.estado <> 'ABANDONADA'))));
$$;

-- "Pérez, Juan - 71.38 Programación web, comisión A"
CREATE FUNCTION sga.descripcion_docente_comision(p_docente_comision_id INTEGER)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT format('%s, %s - %s %s, comisión %s', p.apellido, p.nombre, m.codigo, m.nombre, co.nombre)
    FROM sga.docente_comision dc
    JOIN sga.docente d ON d.id = dc.docente_id
    JOIN sga.persona p ON p.id = d.persona_id
    JOIN sga.comision co ON co.id = dc.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE dc.id = p_docente_comision_id;
$$;

-- Encuestas que la persona logueada tiene que responder (o ya respondió).
CREATE FUNCTION sga.encuestas_para_mi()
RETURNS TABLE (
    id INTEGER,
    nombre TEXT,
    tipo TEXT,
    sobre TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    estado TEXT,
    respondida BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT e.id, e.nombre::TEXT, e.tipo::TEXT,
           CASE WHEN e.docente_comision_id IS NOT NULL THEN sga.descripcion_docente_comision(e.docente_comision_id) END,
           e.fecha_inicio, e.fecha_fin,
           sga.estado_encuesta_actual(e.estado, e.fecha_inicio, e.fecha_fin),
           EXISTS (SELECT 1 FROM sga.encuesta_participacion ep
                   WHERE ep.encuesta_id = e.id AND ep.persona_id = sga.persona_actual_id())
    FROM sga.encuesta e
    WHERE sga.es_destinatario_encuesta(e.id, sga.persona_actual_id())
    ORDER BY e.fecha_fin DESC, e.id;
$$;

-- Todas las encuestas con su participación. Administración ve todas; un
-- docente, las de desempeño de sus comisiones.
CREATE FUNCTION sga.encuestas_resumen()
RETURNS TABLE (
    id INTEGER,
    nombre TEXT,
    tipo TEXT,
    sobre TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    estado TEXT,
    respuestas INTEGER,
    destinatarios INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT e.id, e.nombre::TEXT, e.tipo::TEXT,
           CASE WHEN e.docente_comision_id IS NOT NULL THEN sga.descripcion_docente_comision(e.docente_comision_id) END,
           e.fecha_inicio, e.fecha_fin,
           sga.estado_encuesta_actual(e.estado, e.fecha_inicio, e.fecha_fin),
           (SELECT count(*) FROM sga.encuesta_participacion ep WHERE ep.encuesta_id = e.id)::INTEGER,
           CASE e.tipo
               WHEN 'ALUMNOS' THEN (SELECT count(*) FROM sga.legajo)
               ELSE (SELECT count(*) FROM sga.docente_comision dc
                     JOIN sga.inscripcion_curso ic ON ic.comision_id = dc.comision_id
                     WHERE dc.id = e.docente_comision_id AND ic.estado <> 'ABANDONADA')
           END::INTEGER
    FROM sga.encuesta e
    LEFT JOIN sga.docente_comision dc ON dc.id = e.docente_comision_id
    WHERE sga.es_admin() OR dc.docente_id = sga.docente_actual_id()
    ORDER BY e.fecha_fin DESC, e.nombre, e.id;
$$;

-- p_respuestas: {"<pregunta_id>": 1..5 | "texto"}. Las de escala son
-- obligatorias; las de texto, opcionales.
CREATE FUNCTION sga.responder_encuesta(p_encuesta_id INTEGER, p_respuestas JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_yo INTEGER := sga.persona_actual_id();
    v_encuesta sga.encuesta%ROWTYPE;
    v_pregunta sga.encuesta_pregunta%ROWTYPE;
    v_valor JSONB;
    v_limpias JSONB := '{}';
    v_suma NUMERIC := 0;
    v_cantidad INTEGER := 0;
BEGIN
    SELECT * INTO v_encuesta FROM sga.encuesta WHERE id = p_encuesta_id;
    IF NOT FOUND OR NOT sga.es_destinatario_encuesta(p_encuesta_id, v_yo) THEN
        RAISE EXCEPTION 'Esta encuesta no es para vos' USING ERRCODE = '42501';
    END IF;
    IF sga.estado_encuesta_actual(v_encuesta.estado, v_encuesta.fecha_inicio, v_encuesta.fecha_fin) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La encuesta no está abierta' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.encuesta_participacion WHERE encuesta_id = p_encuesta_id AND persona_id = v_yo) THEN
        RAISE EXCEPTION 'Ya respondiste esta encuesta' USING ERRCODE = '23505';
    END IF;

    FOR v_pregunta IN SELECT * FROM sga.encuesta_pregunta WHERE encuesta_id = p_encuesta_id ORDER BY orden LOOP
        v_valor := p_respuestas -> v_pregunta.id::TEXT;
        IF v_pregunta.tipo = 'ESCALA' THEN
            IF v_valor IS NULL OR jsonb_typeof(v_valor) <> 'number' OR (v_valor #>> '{}')::NUMERIC NOT IN (1, 2, 3, 4, 5) THEN
                RAISE EXCEPTION 'Respondé todas las preguntas con un valor del 1 al 5' USING ERRCODE = '23514';
            END IF;
            v_suma := v_suma + (v_valor #>> '{}')::NUMERIC;
            v_cantidad := v_cantidad + 1;
            v_limpias := v_limpias || jsonb_build_object(v_pregunta.id::TEXT, (v_valor #>> '{}')::INTEGER);
        ELSIF v_valor IS NOT NULL AND jsonb_typeof(v_valor) = 'string' AND btrim(v_valor #>> '{}') <> '' THEN
            IF length(v_valor #>> '{}') > 1000 THEN
                RAISE EXCEPTION 'Las respuestas de texto pueden tener hasta 1000 caracteres' USING ERRCODE = '23514';
            END IF;
            v_limpias := v_limpias || jsonb_build_object(v_pregunta.id::TEXT, btrim(v_valor #>> '{}'));
        END IF;
    END LOOP;

    INSERT INTO sga.encuesta_participacion (encuesta_id, persona_id) VALUES (p_encuesta_id, v_yo);
    INSERT INTO sga.encuesta_respuesta (encuesta_id, puntaje, respuestas)
    VALUES (p_encuesta_id, CASE WHEN v_cantidad > 0 THEN round(v_suma / v_cantidad, 2) END, v_limpias);
END;
$$;

CREATE FUNCTION sga.puede_ver_resultados_encuesta(p_encuesta_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT sga.es_admin() OR EXISTS (
        SELECT 1
        FROM sga.encuesta e
        JOIN sga.docente_comision dc ON dc.id = e.docente_comision_id
        WHERE e.id = p_encuesta_id
          AND dc.docente_id = sga.docente_actual_id()
          AND sga.estado_encuesta_actual(e.estado, e.fecha_inicio, e.fecha_fin) = 'FINALIZADA'
          AND (SELECT count(*) FROM sga.encuesta_respuesta r WHERE r.encuesta_id = e.id) >= 3);
$$;

-- Resultados agregados por pregunta: promedio y cantidad por valor (1 a
-- 5) para las de escala; las respuestas de texto, mezcladas.
CREATE FUNCTION sga.resultados_encuesta(p_encuesta_id INTEGER)
RETURNS TABLE (
    pregunta_id INTEGER,
    orden INTEGER,
    texto TEXT,
    tipo TEXT,
    respuestas INTEGER,
    promedio NUMERIC,
    distribucion INTEGER[],
    textos TEXT[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.puede_ver_resultados_encuesta(p_encuesta_id) THEN
        RAISE EXCEPTION 'Los resultados todavía no están disponibles' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        q.id, q.orden, q.texto::TEXT, q.tipo::TEXT,
        count(r.respuestas -> q.id::TEXT)::INTEGER,
        round(avg(CASE WHEN q.tipo = 'ESCALA' THEN (r.respuestas ->> q.id::TEXT)::NUMERIC END), 2),
        CASE WHEN q.tipo = 'ESCALA' THEN ARRAY(
            SELECT (SELECT count(*) FROM sga.encuesta_respuesta x
                    WHERE x.encuesta_id = p_encuesta_id AND x.respuestas ->> q.id::TEXT = v::TEXT)::INTEGER
            FROM generate_series(1, 5) AS v
            ORDER BY v) END,
        CASE WHEN q.tipo = 'TEXTO' THEN array_agg(r.respuestas ->> q.id::TEXT ORDER BY md5(r.id::TEXT))
            FILTER (WHERE r.respuestas ? q.id::TEXT) END
    FROM sga.encuesta_pregunta q
    LEFT JOIN sga.encuesta_respuesta r ON r.encuesta_id = q.encuesta_id
    WHERE q.encuesta_id = p_encuesta_id
    GROUP BY q.id, q.orden, q.texto, q.tipo
    ORDER BY q.orden;
END;
$$;

-- Administración: crea una encuesta con sus preguntas
-- (p_preguntas: [{"texto": "...", "tipo": "ESCALA" | "TEXTO"}]).
CREATE FUNCTION sga.crear_encuesta(
    p_nombre TEXT,
    p_descripcion TEXT,
    p_inicio DATE,
    p_fin DATE,
    p_preguntas JSONB,
    p_docente_comision_id INTEGER DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración crea encuestas' USING ERRCODE = '42501';
    END IF;
    IF jsonb_array_length(COALESCE(p_preguntas, '[]')) = 0 THEN
        RAISE EXCEPTION 'La encuesta necesita al menos una pregunta' USING ERRCODE = '23514';
    END IF;

    INSERT INTO sga.encuesta (tipo, nombre, descripcion, docente_comision_id, fecha_inicio, fecha_fin)
    VALUES (CASE WHEN p_docente_comision_id IS NULL THEN 'ALUMNOS' ELSE 'DESEMPENO_DOCENTE' END::sga.tipo_encuesta,
            btrim(p_nombre), NULLIF(btrim(p_descripcion), ''), p_docente_comision_id, p_inicio, p_fin)
    RETURNING id INTO v_id;

    INSERT INTO sga.encuesta_pregunta (encuesta_id, orden, texto, tipo)
    SELECT v_id, x.orden, btrim(x.p ->> 'texto'), x.p ->> 'tipo'
    FROM jsonb_array_elements(p_preguntas) WITH ORDINALITY AS x (p, orden);

    RETURN v_id;
END;
$$;

-- Administración: una encuesta de desempeño por cada docente de cada
-- comisión de los cursos activos (salvo las que ya tienen una con ese
-- nombre). Devuelve cuántas creó.
CREATE FUNCTION sga.crear_encuestas_desempeno(p_nombre TEXT, p_inicio DATE, p_fin DATE)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_dc INTEGER;
    v_creadas INTEGER := 0;
    v_preguntas JSONB := '[
        {"texto": "Explica los temas con claridad", "tipo": "ESCALA"},
        {"texto": "Responde las consultas y está disponible", "tipo": "ESCALA"},
        {"texto": "Cumple con los horarios y el programa de la materia", "tipo": "ESCALA"},
        {"texto": "Las evaluaciones son coherentes con lo dado en clase", "tipo": "ESCALA"},
        {"texto": "Valoración general del docente", "tipo": "ESCALA"},
        {"texto": "Comentarios (opcional)", "tipo": "TEXTO"}
    ]';
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración crea encuestas' USING ERRCODE = '42501';
    END IF;

    FOR v_dc IN
        SELECT dc.id
        FROM sga.docente_comision dc
        JOIN sga.comision co ON co.id = dc.comision_id
        JOIN sga.curso c ON c.id = co.curso_id
        WHERE c.activo
          AND NOT EXISTS (SELECT 1 FROM sga.encuesta e WHERE e.docente_comision_id = dc.id AND e.nombre = btrim(p_nombre))
    LOOP
        PERFORM sga.crear_encuesta(p_nombre, NULL, p_inicio, p_fin, v_preguntas, v_dc);
        v_creadas := v_creadas + 1;
    END LOOP;

    RETURN v_creadas;
END;
$$;

-- Administración cierra una encuesta antes de su fecha de fin. Al
-- cerrarse, las de desempeño actualizan evaluacion_docente (trigger).
CREATE FUNCTION sga.finalizar_encuesta(p_encuesta_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración cierra encuestas' USING ERRCODE = '42501';
    END IF;
    UPDATE sga.encuesta SET estado = 'FINALIZADA' WHERE id = p_encuesta_id AND estado <> 'FINALIZADA';
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.es_destinatario_encuesta(INTEGER, INTEGER),
    sga.descripcion_docente_comision(INTEGER),
    sga.encuestas_para_mi(),
    sga.encuestas_resumen(),
    sga.responder_encuesta(INTEGER, JSONB),
    sga.puede_ver_resultados_encuesta(INTEGER),
    sga.resultados_encuesta(INTEGER),
    sga.crear_encuesta(TEXT, TEXT, DATE, DATE, JSONB, INTEGER),
    sga.crear_encuestas_desempeno(TEXT, DATE, DATE),
    sga.finalizar_encuesta(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.encuestas_para_mi(),
    sga.encuestas_resumen(),
    sga.responder_encuesta(INTEGER, JSONB),
    sga.puede_ver_resultados_encuesta(INTEGER),
    sga.resultados_encuesta(INTEGER),
    sga.crear_encuesta(TEXT, TEXT, DATE, DATE, JSONB, INTEGER),
    sga.crear_encuestas_desempeno(TEXT, DATE, DATE),
    sga.finalizar_encuesta(INTEGER)
TO authenticated;
