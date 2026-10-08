-- =====================================================================
-- Ausencias docentes.
--
--   - El docente informa que va a faltar (tipo, fechas, motivo y qué
--     comisiones suyas afecta). A los alumnos que cursan esas comisiones
--     les llega un aviso y lo ven en su calendario semanal.
--   - Puede cancelarla mientras no haya empezado (también se avisa).
--   - Administración la marca como JUSTIFICADA o NO_JUSTIFICADA, con
--     observaciones. Estados: INFORMADA → JUSTIFICADA | NO_JUSTIFICADA;
--     INFORMADA → CANCELADA (el docente, antes de empezar).
--
-- La tabla ausencia_docente ya existía (con sus políticas); se agregan
-- las comisiones afectadas, la fecha de carga y los controles.
-- =====================================================================

ALTER TABLE sga.ausencia_docente
    ADD COLUMN fecha_carga TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN fecha_revision TIMESTAMPTZ;
UPDATE sga.ausencia_docente SET estado = 'INFORMADA' WHERE estado IS NULL;
ALTER TABLE sga.ausencia_docente
    ALTER COLUMN estado SET DEFAULT 'INFORMADA',
    ADD CONSTRAINT ck_ausencia_docente_estado
        CHECK (estado IN ('INFORMADA', 'JUSTIFICADA', 'NO_JUSTIFICADA', 'CANCELADA')),
    ADD CONSTRAINT ck_ausencia_docente_tipo
        CHECK (tipo_ausencia IS NULL OR tipo_ausencia IN ('ENFERMEDAD', 'PERSONAL', 'CONGRESO', 'CAPACITACION', 'OTRO'));

CREATE TABLE sga.ausencia_docente_comision (
    ausencia_id INTEGER NOT NULL REFERENCES sga.ausencia_docente (id) ON DELETE CASCADE,
    comision_id INTEGER NOT NULL REFERENCES sga.comision (id) ON DELETE CASCADE,
    PRIMARY KEY (ausencia_id, comision_id)
);
CREATE INDEX ix_ausencia_docente_comision_comision_id ON sga.ausencia_docente_comision (comision_id);

ALTER TABLE sga.ausencia_docente_comision ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.ausencia_docente_comision FORCE ROW LEVEL SECURITY;
CREATE POLICY ausencia_docente_comision_select ON sga.ausencia_docente_comision
    FOR SELECT TO authenticated USING (
        sga.es_admin()
        OR EXISTS (SELECT 1 FROM sga.ausencia_docente a WHERE a.id = ausencia_id AND a.docente_id = sga.docente_actual_id())
    );
GRANT SELECT ON sga.ausencia_docente_comision TO authenticated;

-- Las ausencias se cargan y cambian solo con las funciones de abajo
DROP POLICY ausencia_docente_insert_propia ON sga.ausencia_docente;

-- Texto de una ausencia para los avisos: "71.38 comisión A del 12/10/2026" o "... del 12/10 al 14/10/2026"
CREATE FUNCTION sga.texto_fechas(p_desde DATE, p_hasta DATE)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT CASE WHEN p_hasta IS NULL OR p_hasta = p_desde THEN 'el ' || to_char(p_desde, 'DD/MM/YYYY')
                ELSE 'del ' || to_char(p_desde, 'DD/MM') || ' al ' || to_char(p_hasta, 'DD/MM/YYYY') END;
$$;

CREATE FUNCTION sga.informar_ausencia(p_tipo TEXT, p_desde DATE, p_hasta DATE, p_motivo TEXT, p_comisiones INTEGER[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_docente INTEGER := sga.docente_actual_id();
    v_id INTEGER;
BEGIN
    IF v_docente IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no es docente' USING ERRCODE = '42501';
    END IF;
    IF p_tipo IS NULL OR p_tipo NOT IN ('ENFERMEDAD', 'PERSONAL', 'CONGRESO', 'CAPACITACION', 'OTRO') THEN
        RAISE EXCEPTION 'Elegí el tipo de ausencia' USING ERRCODE = '23514';
    END IF;
    IF p_desde IS NULL OR p_hasta IS NULL OR p_hasta < p_desde THEN
        RAISE EXCEPTION 'Las fechas no son válidas' USING ERRCODE = '23514';
    END IF;
    IF p_hasta < sga.hoy() THEN
        RAISE EXCEPTION 'No se puede informar una ausencia que ya pasó' USING ERRCODE = '23514';
    END IF;
    IF p_hasta - p_desde > 60 THEN
        RAISE EXCEPTION 'Una ausencia puede durar hasta 60 días; para más, hablá con Administración' USING ERRCODE = '23514';
    END IF;
    IF coalesce(array_length(p_comisiones, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Elegí al menos una comisión' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT 1 FROM unnest(p_comisiones) AS x (id)
        WHERE NOT EXISTS (SELECT 1 FROM sga.docente_comision dc WHERE dc.docente_id = v_docente AND dc.comision_id = x.id)
    ) THEN
        RAISE EXCEPTION 'Solo podés informar ausencias en comisiones que dictás' USING ERRCODE = '42501';
    END IF;

    INSERT INTO sga.ausencia_docente (docente_id, tipo_ausencia, fecha_inicio, fecha_fin, motivo, estado)
    VALUES (v_docente, p_tipo, p_desde, p_hasta, NULLIF(btrim(p_motivo), ''), 'INFORMADA')
    RETURNING id INTO v_id;
    INSERT INTO sga.ausencia_docente_comision (ausencia_id, comision_id)
    SELECT DISTINCT v_id, x.id FROM unnest(p_comisiones) AS x (id);

    -- Aviso a quienes cursan esas comisiones
    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    SELECT DISTINCT l.persona_id, 'AUSENCIA',
           format('Sin clase de %s (comisión %s) %s: el docente no va a estar', m.codigo, co.nombre, sga.texto_fechas(p_desde, p_hasta))
    FROM unnest(p_comisiones) AS x (id)
    JOIN sga.comision co ON co.id = x.id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.inscripcion_curso ic ON ic.comision_id = co.id AND ic.estado = 'CURSANDO'
    JOIN sga.legajo l ON l.id = ic.legajo_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.cancelar_ausencia(p_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_a sga.ausencia_docente%ROWTYPE;
BEGIN
    SELECT * INTO v_a FROM sga.ausencia_docente WHERE id = p_id AND docente_id = sga.docente_actual_id() FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés esa ausencia' USING ERRCODE = '42501';
    END IF;
    IF v_a.estado <> 'INFORMADA' OR v_a.fecha_inicio <= sga.hoy() THEN
        RAISE EXCEPTION 'Solo se puede cancelar una ausencia informada que todavía no empezó' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.ausencia_docente SET estado = 'CANCELADA' WHERE id = p_id;
    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    SELECT DISTINCT l.persona_id, 'AUSENCIA',
           format('Hay clase de %s (comisión %s) %s: el docente canceló su ausencia', m.codigo, co.nombre, sga.texto_fechas(v_a.fecha_inicio, v_a.fecha_fin))
    FROM sga.ausencia_docente_comision adc
    JOIN sga.comision co ON co.id = adc.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.inscripcion_curso ic ON ic.comision_id = co.id AND ic.estado = 'CURSANDO'
    JOIN sga.legajo l ON l.id = ic.legajo_id
    WHERE adc.ausencia_id = p_id;
END;
$$;

CREATE FUNCTION sga.revisar_ausencia(p_id INTEGER, p_justificada BOOLEAN, p_observaciones TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_estado TEXT;
BEGIN
    PERFORM sga.validar_admin();
    SELECT estado INTO v_estado FROM sga.ausencia_docente WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La ausencia no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado = 'CANCELADA' THEN
        RAISE EXCEPTION 'La ausencia fue cancelada por el docente' USING ERRCODE = '23514';
    END IF;
    IF NOT p_justificada AND NULLIF(btrim(p_observaciones), '') IS NULL THEN
        RAISE EXCEPTION 'Indicá por qué no se justifica' USING ERRCODE = '23514';
    END IF;
    UPDATE sga.ausencia_docente
    SET estado = CASE WHEN p_justificada THEN 'JUSTIFICADA' ELSE 'NO_JUSTIFICADA' END,
        observaciones = NULLIF(btrim(p_observaciones), ''), fecha_revision = now()
    WHERE id = p_id;
END;
$$;

-- Docente: sus ausencias con las comisiones.
-- Administración: todas, con el docente.
CREATE FUNCTION sga.ausencias_docentes(p_solo_mias BOOLEAN)
RETURNS TABLE (
    id INTEGER,
    apellido TEXT,
    nombre TEXT,
    tipo TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    motivo TEXT,
    estado TEXT,
    observaciones TEXT,
    fecha_carga TIMESTAMPTZ,
    comisiones TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT p_solo_mias THEN
        PERFORM sga.validar_admin();
    END IF;
    RETURN QUERY
    SELECT a.id, p.apellido::TEXT, p.nombre::TEXT, a.tipo_ausencia::TEXT, a.fecha_inicio, a.fecha_fin, a.motivo,
           a.estado::TEXT, a.observaciones, a.fecha_carga,
           (SELECT string_agg(m.codigo || ' ' || co.nombre, ', ' ORDER BY m.codigo, co.nombre)
            FROM sga.ausencia_docente_comision adc JOIN sga.comision co ON co.id = adc.comision_id
            JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
            WHERE adc.ausencia_id = a.id)
    FROM sga.ausencia_docente a
    JOIN sga.docente d ON d.id = a.docente_id
    JOIN sga.persona p ON p.id = d.persona_id
    WHERE (NOT p_solo_mias OR a.docente_id = sga.docente_actual_id())
    ORDER BY a.estado <> 'INFORMADA', a.fecha_inicio DESC
    LIMIT 300;
END;
$$;

-- Alumno: clases suspendidas (desde hace una semana) de las comisiones que cursa.
CREATE FUNCTION sga.clases_suspendidas_para_mi()
RETURNS TABLE (
    codigo TEXT,
    materia TEXT,
    comision TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    docente TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT m.codigo::TEXT, m.nombre::TEXT, co.nombre::TEXT, a.fecha_inicio, a.fecha_fin, p.apellido || ', ' || p.nombre
    FROM sga.inscripcion_curso ic
    JOIN sga.ausencia_docente_comision adc ON adc.comision_id = ic.comision_id
    JOIN sga.ausencia_docente a ON a.id = adc.ausencia_id AND a.estado <> 'CANCELADA' AND a.fecha_fin >= sga.hoy() - 7
    JOIN sga.comision co ON co.id = ic.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    JOIN sga.docente d ON d.id = a.docente_id
    JOIN sga.persona p ON p.id = d.persona_id
    WHERE ic.legajo_id = sga.legajo_actual_id() AND ic.estado = 'CURSANDO'
    ORDER BY a.fecha_inicio;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.texto_fechas(DATE, DATE),
    sga.informar_ausencia(TEXT, DATE, DATE, TEXT, INTEGER[]),
    sga.cancelar_ausencia(INTEGER),
    sga.revisar_ausencia(INTEGER, BOOLEAN, TEXT),
    sga.ausencias_docentes(BOOLEAN),
    sga.clases_suspendidas_para_mi()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.informar_ausencia(TEXT, DATE, DATE, TEXT, INTEGER[]),
    sga.cancelar_ausencia(INTEGER),
    sga.revisar_ausencia(INTEGER, BOOLEAN, TEXT),
    sga.ausencias_docentes(BOOLEAN),
    sga.clases_suspendidas_para_mi()
TO authenticated;
