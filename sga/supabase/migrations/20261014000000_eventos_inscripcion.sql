-- =====================================================================
-- Inscripción a eventos académicos (charlas, jornadas, talleres).
--
--   - evento_academico gana descripción, cupo (opcional) y si tiene
--     inscripción, con su cierre (por defecto, el comienzo del evento).
--   - evento_inscripcion: quién se anotó. Cada uno ve las suyas;
--     Administración ve todas (para la lista de asistentes).
--   - inscribirse_evento() / desinscribirse_evento(): cualquier usuario
--     con sesión, hasta el cierre y mientras haya cupo.
-- =====================================================================

ALTER TABLE sga.evento_academico
    ADD COLUMN descripcion TEXT,
    ADD COLUMN cupo INTEGER,
    ADD COLUMN con_inscripcion BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN inscripcion_hasta TIMESTAMPTZ,
    ADD CONSTRAINT ck_evento_academico_cupo CHECK (cupo IS NULL OR cupo > 0);

CREATE TABLE sga.evento_inscripcion (
    evento_id INTEGER NOT NULL REFERENCES sga.evento_academico (id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL REFERENCES sga.persona (id) ON DELETE CASCADE,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (evento_id, persona_id)
);

CREATE INDEX ix_evento_inscripcion_persona_id ON sga.evento_inscripcion (persona_id);

ALTER TABLE sga.evento_inscripcion ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.evento_inscripcion FORCE ROW LEVEL SECURITY;
CREATE POLICY evento_inscripcion_select_propia ON sga.evento_inscripcion
    FOR SELECT TO authenticated USING (persona_id = sga.persona_actual_id() OR sga.es_admin());
CREATE POLICY evento_inscripcion_admin_all ON sga.evento_inscripcion
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.evento_inscripcion TO authenticated;

-- Cierre de la inscripción: el indicado o el comienzo del evento (hora
-- de Buenos Aires).
CREATE FUNCTION sga.cierre_inscripcion_evento(p_evento sga.evento_academico)
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
    SELECT COALESCE(p_evento.inscripcion_hasta,
                    (p_evento.fecha + p_evento.hora_inicio) AT TIME ZONE 'America/Argentina/Buenos_Aires');
$$;

-- Eventos próximos con inscripción, con lugares y si estoy anotado.
CREATE FUNCTION sga.eventos_para_mi()
RETURNS TABLE (
    evento_id INTEGER,
    nombre TEXT,
    tipo TEXT,
    descripcion TEXT,
    fecha DATE,
    hora_inicio TIME,
    hora_fin TIME,
    aula TEXT,
    edificio TEXT,
    cupo INTEGER,
    inscriptos INTEGER,
    cierre TIMESTAMPTZ,
    inscripto BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT e.id, e.nombre::TEXT, e.tipo::TEXT, e.descripcion, e.fecha, e.hora_inicio, e.hora_fin,
           a.codigo::TEXT, ed.nombre::TEXT, e.cupo,
           (SELECT count(*) FROM sga.evento_inscripcion i WHERE i.evento_id = e.id)::INTEGER,
           sga.cierre_inscripcion_evento(e),
           EXISTS (SELECT 1 FROM sga.evento_inscripcion i WHERE i.evento_id = e.id AND i.persona_id = sga.persona_actual_id())
    FROM sga.evento_academico e
    LEFT JOIN sga.aula a ON a.id = e.aula_id
    LEFT JOIN sga.edificio ed ON ed.id = a.edificio_id
    WHERE e.con_inscripcion AND e.fecha >= sga.hoy()
    ORDER BY e.fecha, e.hora_inicio;
$$;

CREATE FUNCTION sga.inscribirse_evento(p_evento_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_yo INTEGER := sga.persona_actual_id();
    v_evento sga.evento_academico%ROWTYPE;
BEGIN
    IF v_yo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene una persona asociada' USING ERRCODE = '42501';
    END IF;
    -- Bloquea el evento: el cupo se toma por orden de llegada
    SELECT * INTO v_evento FROM sga.evento_academico WHERE id = p_evento_id FOR UPDATE;
    IF NOT FOUND OR NOT v_evento.con_inscripcion THEN
        RAISE EXCEPTION 'El evento no tiene inscripción' USING ERRCODE = '23514';
    END IF;
    IF now() >= sga.cierre_inscripcion_evento(v_evento) THEN
        RAISE EXCEPTION 'La inscripción a este evento ya cerró' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.evento_inscripcion WHERE evento_id = v_evento.id AND persona_id = v_yo) THEN
        RAISE EXCEPTION 'Ya estás anotado a este evento' USING ERRCODE = '23505';
    END IF;
    IF v_evento.cupo IS NOT NULL AND (SELECT count(*) FROM sga.evento_inscripcion WHERE evento_id = v_evento.id) >= v_evento.cupo THEN
        RAISE EXCEPTION 'No quedan lugares para este evento' USING ERRCODE = '23514';
    END IF;
    INSERT INTO sga.evento_inscripcion (evento_id, persona_id) VALUES (v_evento.id, v_yo);
END;
$$;

CREATE FUNCTION sga.desinscribirse_evento(p_evento_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_evento sga.evento_academico%ROWTYPE;
BEGIN
    SELECT * INTO v_evento FROM sga.evento_academico WHERE id = p_evento_id;
    IF NOT EXISTS (SELECT 1 FROM sga.evento_inscripcion WHERE evento_id = p_evento_id AND persona_id = sga.persona_actual_id()) THEN
        RAISE EXCEPTION 'No estás anotado a este evento' USING ERRCODE = '42501';
    END IF;
    IF now() >= sga.cierre_inscripcion_evento(v_evento) THEN
        RAISE EXCEPTION 'La inscripción ya cerró: no te podés dar de baja' USING ERRCODE = '23514';
    END IF;
    DELETE FROM sga.evento_inscripcion WHERE evento_id = p_evento_id AND persona_id = sga.persona_actual_id();
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.eventos_para_mi(),
    sga.inscribirse_evento(INTEGER),
    sga.desinscribirse_evento(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.eventos_para_mi(),
    sga.inscribirse_evento(INTEGER),
    sga.desinscribirse_evento(INTEGER)
TO authenticated;
