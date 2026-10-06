-- =====================================================================
-- Intercambios: Inicio → Trámites → "Ver intercambio/s".
--
--   - convocatoria_intercambio: Administración publica plazas en
--     universidades socias para un cuatrimestre, con vacantes, requisitos
--     (créditos aprobados y promedio mínimos) y período de postulación.
--   - postulacion_intercambio: el alumno que cumple los requisitos se
--     postula con una carta de motivación mientras la convocatoria está
--     abierta (y puede retirarse). Al cerrar, Administración marca a los
--     seleccionados y publica los resultados: los no marcados quedan no
--     seleccionados y todos reciben una notificación.
--   - El alumno ve el resultado recién cuando se publica.
-- =====================================================================

CREATE TABLE sga.convocatoria_intercambio (
    id SERIAL PRIMARY KEY,
    universidad TEXT NOT NULL,
    pais TEXT NOT NULL,
    ciudad TEXT,
    anio INTEGER NOT NULL,
    periodo TEXT NOT NULL,
    vacantes INTEGER NOT NULL,
    creditos_minimos INTEGER NOT NULL DEFAULT 0,
    promedio_minimo NUMERIC(4, 2),
    descripcion TEXT,
    postulacion_desde DATE NOT NULL,
    postulacion_hasta DATE NOT NULL,
    resultados_publicados BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT ck_convocatoria_intercambio_vacantes CHECK (vacantes > 0),
    CONSTRAINT ck_convocatoria_intercambio_creditos CHECK (creditos_minimos >= 0),
    CONSTRAINT ck_convocatoria_intercambio_promedio CHECK (promedio_minimo IS NULL OR promedio_minimo BETWEEN 0 AND 10),
    CONSTRAINT ck_convocatoria_intercambio_fechas CHECK (postulacion_hasta >= postulacion_desde),
    CONSTRAINT ck_convocatoria_intercambio_textos CHECK (length(btrim(universidad)) > 0 AND length(btrim(pais)) > 0)
);

ALTER TABLE sga.convocatoria_intercambio ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.convocatoria_intercambio FORCE ROW LEVEL SECURITY;
CREATE POLICY convocatoria_intercambio_select ON sga.convocatoria_intercambio FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY convocatoria_intercambio_admin_all ON sga.convocatoria_intercambio
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.convocatoria_intercambio TO authenticated;

CREATE TABLE sga.postulacion_intercambio (
    id SERIAL PRIMARY KEY,
    convocatoria_id INTEGER NOT NULL REFERENCES sga.convocatoria_intercambio (id) ON DELETE CASCADE,
    legajo_id INTEGER NOT NULL REFERENCES sga.legajo (id) ON DELETE CASCADE,
    motivacion TEXT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado TEXT NOT NULL DEFAULT 'PENDIENTE',

    CONSTRAINT uq_postulacion_intercambio UNIQUE (convocatoria_id, legajo_id),
    CONSTRAINT ck_postulacion_intercambio_estado CHECK (estado IN ('PENDIENTE', 'SELECCIONADA', 'NO_SELECCIONADA'))
);

CREATE INDEX ix_postulacion_intercambio_legajo_id ON sga.postulacion_intercambio (legajo_id);

-- El alumno no lee la tabla (vería la selección antes de que se
-- publique): usa intercambios_para_mi(). Administración ve todo.
ALTER TABLE sga.postulacion_intercambio ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.postulacion_intercambio FORCE ROW LEVEL SECURITY;
CREATE POLICY postulacion_intercambio_admin ON sga.postulacion_intercambio
    FOR SELECT TO authenticated USING (sga.es_admin());
GRANT SELECT ON sga.postulacion_intercambio TO authenticated;

-- Por qué el alumno no se puede postular (NULL si puede).
CREATE FUNCTION sga.motivo_no_postulacion_intercambio(p_convocatoria_id INTEGER, p_legajo_id INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_c sga.convocatoria_intercambio%ROWTYPE;
    v_creditos INTEGER;
    v_promedio NUMERIC;
BEGIN
    SELECT * INTO v_c FROM sga.convocatoria_intercambio WHERE id = p_convocatoria_id;
    IF NOT FOUND THEN
        RETURN 'La convocatoria no existe';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.postulacion_intercambio WHERE convocatoria_id = v_c.id AND legajo_id = p_legajo_id) THEN
        RETURN 'Ya te postulaste';
    END IF;
    IF sga.hoy() < v_c.postulacion_desde THEN
        RETURN format('La postulación abre el %s', to_char(v_c.postulacion_desde, 'DD/MM/YYYY'));
    END IF;
    IF sga.hoy() > v_c.postulacion_hasta OR v_c.resultados_publicados THEN
        RETURN 'La postulación cerró';
    END IF;
    v_creditos := sga.creditos_aprobados(p_legajo_id);
    IF v_creditos < v_c.creditos_minimos THEN
        RETURN format('Pide %s créditos aprobados (tenés %s)', v_c.creditos_minimos, v_creditos);
    END IF;
    SELECT rendimiento_academico INTO v_promedio FROM sga.legajo WHERE id = p_legajo_id;
    IF v_c.promedio_minimo IS NOT NULL AND coalesce(v_promedio, 0) < v_c.promedio_minimo THEN
        RETURN format('Pide promedio %s (tenés %s)', v_c.promedio_minimo, coalesce(v_promedio::TEXT, 'sin promedio'));
    END IF;
    RETURN NULL;
END;
$$;

-- Convocatorias vigentes (o en las que me postulé), con mi postulación.
-- El estado SELECCIONADA / NO_SELECCIONADA solo aparece publicado.
CREATE FUNCTION sga.intercambios_para_mi()
RETURNS TABLE (
    convocatoria_id INTEGER,
    universidad TEXT,
    pais TEXT,
    ciudad TEXT,
    anio INTEGER,
    periodo TEXT,
    vacantes INTEGER,
    creditos_minimos INTEGER,
    promedio_minimo NUMERIC,
    descripcion TEXT,
    postulacion_desde DATE,
    postulacion_hasta DATE,
    resultados_publicados BOOLEAN,
    postulantes INTEGER,
    postulacion_id INTEGER,
    postulacion_fecha TIMESTAMPTZ,
    resultado TEXT,
    motivo TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    WITH yo AS (SELECT sga.legajo_actual_id() AS legajo)
    SELECT c.id, c.universidad, c.pais, c.ciudad, c.anio, c.periodo, c.vacantes, c.creditos_minimos, c.promedio_minimo,
           c.descripcion, c.postulacion_desde, c.postulacion_hasta, c.resultados_publicados,
           (SELECT count(*) FROM sga.postulacion_intercambio x WHERE x.convocatoria_id = c.id)::INTEGER,
           p.id, p.fecha,
           CASE WHEN p.id IS NULL THEN NULL WHEN c.resultados_publicados THEN p.estado ELSE 'PENDIENTE' END,
           CASE WHEN yo.legajo IS NULL THEN 'Tu usuario no tiene un legajo de alumno'
                ELSE sga.motivo_no_postulacion_intercambio(c.id, yo.legajo) END
    FROM sga.convocatoria_intercambio c
    CROSS JOIN yo
    LEFT JOIN sga.postulacion_intercambio p ON p.convocatoria_id = c.id AND p.legajo_id = yo.legajo
    WHERE p.id IS NOT NULL OR c.postulacion_hasta >= sga.hoy() - 30
    ORDER BY c.postulacion_hasta DESC, c.universidad;
$$;

CREATE FUNCTION sga.postular_intercambio(p_convocatoria_id INTEGER, p_motivacion TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_texto TEXT := btrim(coalesce(p_motivacion, ''));
    v_motivo TEXT;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    v_motivo := sga.motivo_no_postulacion_intercambio(p_convocatoria_id, v_legajo);
    IF v_motivo IS NOT NULL THEN
        RAISE EXCEPTION '%', v_motivo USING ERRCODE = '23514';
    END IF;
    IF length(v_texto) < 50 THEN
        RAISE EXCEPTION 'Contá en al menos 50 caracteres por qué querés hacer el intercambio' USING ERRCODE = '23514';
    END IF;
    IF length(v_texto) > 4000 THEN
        RAISE EXCEPTION 'La carta de motivación puede tener hasta 4000 caracteres' USING ERRCODE = '23514';
    END IF;
    INSERT INTO sga.postulacion_intercambio (convocatoria_id, legajo_id, motivacion) VALUES (p_convocatoria_id, v_legajo, v_texto);
END;
$$;

-- Retirarse mientras la postulación siga abierta.
CREATE FUNCTION sga.retirar_postulacion_intercambio(p_postulacion_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_c sga.convocatoria_intercambio%ROWTYPE;
BEGIN
    SELECT c.* INTO v_c FROM sga.postulacion_intercambio p JOIN sga.convocatoria_intercambio c ON c.id = p.convocatoria_id
    WHERE p.id = p_postulacion_id AND p.legajo_id = sga.legajo_actual_id();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés esa postulación' USING ERRCODE = '42501';
    END IF;
    IF sga.hoy() > v_c.postulacion_hasta OR v_c.resultados_publicados THEN
        RAISE EXCEPTION 'La postulación ya cerró: no te podés retirar' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.postulacion_intercambio WHERE id = p_postulacion_id;
END;
$$;

-- Administración: postulantes con sus antecedentes.
CREATE FUNCTION sga.postulantes_intercambio(p_convocatoria_id INTEGER)
RETURNS TABLE (
    postulacion_id INTEGER,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    carrera TEXT,
    creditos_aprobados INTEGER,
    rendimiento NUMERIC,
    motivacion TEXT,
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
        RAISE EXCEPTION 'Solo Administración ve los postulantes' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT p.id, pe.apellido::TEXT, pe.nombre::TEXT, l.numero_legajo::TEXT, ca.nombre_oficial::TEXT,
           sga.creditos_aprobados(l.id), l.rendimiento_academico, p.motivacion, p.fecha, p.estado
    FROM sga.postulacion_intercambio p
    JOIN sga.legajo l ON l.id = p.legajo_id
    JOIN sga.persona pe ON pe.id = l.persona_id
    LEFT JOIN sga.plan_estudio pl ON pl.id = l.plan_estudio_id
    LEFT JOIN sga.carrera ca ON ca.id = pl.carrera_id
    WHERE p.convocatoria_id = p_convocatoria_id
    ORDER BY l.rendimiento_academico DESC NULLS LAST, sga.creditos_aprobados(l.id) DESC, p.fecha;
END;
$$;

-- Administración: marca o desmarca un seleccionado (antes de publicar).
CREATE FUNCTION sga.marcar_postulacion_intercambio(p_postulacion_id INTEGER, p_seleccionada BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_c sga.convocatoria_intercambio%ROWTYPE;
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración selecciona postulantes' USING ERRCODE = '42501';
    END IF;
    SELECT c.* INTO v_c FROM sga.postulacion_intercambio p JOIN sga.convocatoria_intercambio c ON c.id = p.convocatoria_id
    WHERE p.id = p_postulacion_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La postulación no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_c.resultados_publicados THEN
        RAISE EXCEPTION 'Los resultados ya están publicados' USING ERRCODE = '23514';
    END IF;
    IF sga.hoy() <= v_c.postulacion_hasta THEN
        RAISE EXCEPTION 'La selección se hace cuando cierra la postulación (el %)', to_char(v_c.postulacion_hasta, 'DD/MM/YYYY')
            USING ERRCODE = '23514';
    END IF;
    UPDATE sga.postulacion_intercambio SET estado = CASE WHEN p_seleccionada THEN 'SELECCIONADA' ELSE 'NO_SELECCIONADA' END
    WHERE id = p_postulacion_id;
END;
$$;

-- Administración: publica los resultados. Devuelve cuántos quedaron
-- seleccionados.
CREATE FUNCTION sga.publicar_resultados_intercambio(p_convocatoria_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_c sga.convocatoria_intercambio%ROWTYPE;
    v_seleccionados INTEGER;
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración publica resultados' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_c FROM sga.convocatoria_intercambio WHERE id = p_convocatoria_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La convocatoria no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_c.resultados_publicados THEN
        RAISE EXCEPTION 'Los resultados ya están publicados' USING ERRCODE = '23514';
    END IF;
    IF sga.hoy() <= v_c.postulacion_hasta THEN
        RAISE EXCEPTION 'Los resultados se publican cuando cierra la postulación (el %)', to_char(v_c.postulacion_hasta, 'DD/MM/YYYY')
            USING ERRCODE = '23514';
    END IF;
    SELECT count(*) INTO v_seleccionados FROM sga.postulacion_intercambio WHERE convocatoria_id = v_c.id AND estado = 'SELECCIONADA';
    IF v_seleccionados > v_c.vacantes THEN
        RAISE EXCEPTION 'Hay % seleccionados y % vacantes', v_seleccionados, v_c.vacantes USING ERRCODE = '23514';
    END IF;

    UPDATE sga.postulacion_intercambio SET estado = 'NO_SELECCIONADA' WHERE convocatoria_id = v_c.id AND estado = 'PENDIENTE';
    UPDATE sga.convocatoria_intercambio SET resultados_publicados = TRUE WHERE id = v_c.id;
    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    SELECT l.persona_id, 'INTERCAMBIO',
           CASE WHEN p.estado = 'SELECCIONADA'
               THEN format('¡Quedaste seleccionado/a para el intercambio en %s!', v_c.universidad)
               ELSE format('Se publicaron los resultados del intercambio en %s', v_c.universidad)
           END
    FROM sga.postulacion_intercambio p JOIN sga.legajo l ON l.id = p.legajo_id
    WHERE p.convocatoria_id = v_c.id;
    RETURN v_seleccionados;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.motivo_no_postulacion_intercambio(INTEGER, INTEGER),
    sga.intercambios_para_mi(),
    sga.postular_intercambio(INTEGER, TEXT),
    sga.retirar_postulacion_intercambio(INTEGER),
    sga.postulantes_intercambio(INTEGER),
    sga.marcar_postulacion_intercambio(INTEGER, BOOLEAN),
    sga.publicar_resultados_intercambio(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.intercambios_para_mi(),
    sga.postular_intercambio(INTEGER, TEXT),
    sga.retirar_postulacion_intercambio(INTEGER),
    sga.postulantes_intercambio(INTEGER),
    sga.marcar_postulacion_intercambio(INTEGER, BOOLEAN),
    sga.publicar_resultados_intercambio(INTEGER)
TO authenticated;
