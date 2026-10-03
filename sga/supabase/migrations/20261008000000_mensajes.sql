-- =====================================================================
-- Usuario → Mensajes.
--
-- Un mensaje tiene un remitente y uno o más destinatarios
-- (mensaje_destinatario, con su fecha de lectura). Se envía solo con las
-- funciones de abajo, que deciden a quién puede escribirle cada uno:
--
--   - Administración: a todos los usuarios, a los alumnos de una
--     carrera, a los alumnos de una comisión o a una persona (por mail).
--   - Docentes: a los alumnos de las comisiones que dictan, a un alumno
--     de esas comisiones o a otro docente / Administración.
--   - Cualquiera: responder un mensaje recibido (le llega a quien lo
--     mandó).
--
-- Cada uno ve los mensajes que envió y los que recibió; nadie lee
-- mensajes ajenos (tampoco Administración).
--
-- La tabla mensaje existía de uno a uno y sin uso: pasa a ser el envío y
-- los receptores van a mensaje_destinatario.
-- =====================================================================

DROP POLICY mensaje_select_propio ON sga.mensaje;
DROP POLICY mensaje_insert_propio ON sga.mensaje;
DROP POLICY mensaje_update_receptor ON sga.mensaje;

ALTER TABLE sga.mensaje DROP COLUMN persona_receptor_id;
ALTER TABLE sga.mensaje DROP COLUMN leido;
ALTER TABLE sga.mensaje ALTER COLUMN asunto SET NOT NULL;
ALTER TABLE sga.mensaje ALTER COLUMN asunto TYPE VARCHAR(150);
ALTER TABLE sga.mensaje ALTER COLUMN fecha TYPE TIMESTAMPTZ USING fecha AT TIME ZONE 'UTC';
ALTER TABLE sga.mensaje
    ADD COLUMN destino_descripcion VARCHAR NOT NULL,
    ADD COLUMN respuesta_a_id INTEGER REFERENCES sga.mensaje (id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_mensaje_asunto CHECK (btrim(asunto) <> ''),
    ADD CONSTRAINT ck_mensaje_cuerpo CHECK (btrim(cuerpo) <> '' AND length(cuerpo) <= 5000);

CREATE TABLE sga.mensaje_destinatario (
    mensaje_id INTEGER NOT NULL REFERENCES sga.mensaje (id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL REFERENCES sga.persona (id) ON DELETE CASCADE,
    leido_en TIMESTAMPTZ,

    PRIMARY KEY (mensaje_id, persona_id)
);

CREATE INDEX ix_mensaje_destinatario_persona_id ON sga.mensaje_destinatario (persona_id);

-- ---------------------------------------------------------------------
-- Permisos de lectura
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.es_remitente_mensaje(p_mensaje_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM sga.mensaje
        WHERE id = p_mensaje_id AND persona_emisor_id = sga.persona_actual_id());
$$;

CREATE FUNCTION sga.es_destinatario_mensaje(p_mensaje_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM sga.mensaje_destinatario
        WHERE mensaje_id = p_mensaje_id AND persona_id = sga.persona_actual_id());
$$;

CREATE POLICY mensaje_select_remitente_o_destinatario ON sga.mensaje
    FOR SELECT TO authenticated
    USING (persona_emisor_id = sga.persona_actual_id() OR sga.es_destinatario_mensaje(id));

ALTER TABLE sga.mensaje_destinatario ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.mensaje_destinatario FORCE ROW LEVEL SECURITY;
CREATE POLICY mensaje_destinatario_select ON sga.mensaje_destinatario
    FOR SELECT TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_remitente_mensaje(mensaje_id));

GRANT SELECT ON sga.mensaje_destinatario TO authenticated;

-- ---------------------------------------------------------------------
-- Envío
-- ---------------------------------------------------------------------

-- Inserta el mensaje y sus destinatarios (sin el propio remitente).
-- Devuelve el id del mensaje.
CREATE FUNCTION sga.crear_mensaje(
    p_asunto TEXT,
    p_cuerpo TEXT,
    p_destino TEXT,
    p_destinatarios INTEGER[],
    p_respuesta_a INTEGER DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_yo INTEGER := sga.persona_actual_id();
    v_id INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM unnest(p_destinatarios) AS d (id) WHERE d.id IS DISTINCT FROM v_yo) THEN
        RAISE EXCEPTION 'No hay destinatarios para ese envío' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO sga.mensaje (persona_emisor_id, asunto, cuerpo, destino_descripcion, respuesta_a_id)
    VALUES (v_yo, btrim(p_asunto), btrim(p_cuerpo), p_destino, p_respuesta_a)
    RETURNING id INTO v_id;

    INSERT INTO sga.mensaje_destinatario (mensaje_id, persona_id)
    SELECT DISTINCT v_id, d.id FROM unnest(p_destinatarios) AS d (id)
    WHERE d.id IS NOT NULL AND d.id <> v_yo;

    RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION sga.crear_mensaje(TEXT, TEXT, TEXT, INTEGER[], INTEGER) FROM PUBLIC, anon, authenticated;

-- p_destino_tipo: TODOS | CARRERA (p_destino_id = carrera) |
-- COMISION (p_destino_id = comisión) | PERSONA (p_mail).
CREATE FUNCTION sga.enviar_mensaje(
    p_asunto TEXT,
    p_cuerpo TEXT,
    p_destino_tipo TEXT,
    p_destino_id INTEGER DEFAULT NULL,
    p_mail TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin BOOLEAN := sga.es_admin();
    v_docente INTEGER := sga.docente_actual_id();
    v_destino TEXT;
    v_ids INTEGER[];
    v_persona sga.persona%ROWTYPE;
BEGIN
    IF sga.persona_actual_id() IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene una persona asociada' USING ERRCODE = '42501';
    END IF;
    IF NULLIF(btrim(p_asunto), '') IS NULL OR NULLIF(btrim(p_cuerpo), '') IS NULL THEN
        RAISE EXCEPTION 'Completá el asunto y el mensaje' USING ERRCODE = '23514';
    END IF;

    IF p_destino_tipo = 'TODOS' THEN
        IF NOT v_admin THEN
            RAISE EXCEPTION 'Solo Administración puede escribir a todos los usuarios' USING ERRCODE = '42501';
        END IF;
        v_destino := 'Todos los usuarios';
        SELECT array_agg(DISTINCT pr.persona_id) INTO v_ids
        FROM sga.persona_rol pr WHERE pr.activo;

    ELSIF p_destino_tipo = 'CARRERA' THEN
        IF NOT v_admin THEN
            RAISE EXCEPTION 'Solo Administración puede escribir a una carrera' USING ERRCODE = '42501';
        END IF;
        SELECT 'Alumnos de ' || ca.nombre INTO v_destino FROM sga.carrera ca WHERE ca.id = p_destino_id;
        SELECT array_agg(l.persona_id) INTO v_ids
        FROM sga.legajo l JOIN sga.plan_estudio pl ON pl.id = l.plan_estudio_id
        WHERE pl.carrera_id = p_destino_id;

    ELSIF p_destino_tipo = 'COMISION' THEN
        IF NOT (v_admin OR sga.es_docente_de_comision(p_destino_id)) THEN
            RAISE EXCEPTION 'Solo podés escribir a las comisiones que dictás' USING ERRCODE = '42501';
        END IF;
        SELECT format('Alumnos de %s - %s, comisión %s', m.codigo, m.nombre, co.nombre) INTO v_destino
        FROM sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
        WHERE co.id = p_destino_id;
        SELECT array_agg(l.persona_id) INTO v_ids
        FROM sga.inscripcion_curso ic JOIN sga.legajo l ON l.id = ic.legajo_id
        WHERE ic.comision_id = p_destino_id AND ic.estado <> 'ABANDONADA';

    ELSIF p_destino_tipo = 'PERSONA' THEN
        SELECT * INTO v_persona FROM sga.persona
        WHERE lower(mail_institucional) = lower(btrim(p_mail));
        IF NOT FOUND THEN
            RAISE EXCEPTION 'No hay ninguna persona con el mail %', btrim(p_mail) USING ERRCODE = 'P0002';
        END IF;
        IF NOT v_admin AND NOT (
            v_docente IS NOT NULL AND (
                -- otro docente o Administración
                EXISTS (SELECT 1 FROM sga.persona_rol pr
                        WHERE pr.persona_id = v_persona.id AND pr.activo
                          AND pr.rol IN ('DOCENTE', 'AYUDANTE', 'ADMINISTRATIVO'))
                -- o un alumno de alguna de sus comisiones
                OR EXISTS (SELECT 1 FROM sga.inscripcion_curso ic
                           JOIN sga.legajo l ON l.id = ic.legajo_id
                           JOIN sga.docente_comision dc ON dc.comision_id = ic.comision_id
                           WHERE l.persona_id = v_persona.id AND dc.docente_id = v_docente
                             AND ic.estado <> 'ABANDONADA'))) THEN
            RAISE EXCEPTION 'No podés escribirle a esa persona' USING ERRCODE = '42501';
        END IF;
        v_destino := v_persona.apellido || ', ' || v_persona.nombre;
        v_ids := ARRAY[v_persona.id];

    ELSE
        RAISE EXCEPTION 'Destino inválido: %', p_destino_tipo USING ERRCODE = '22023';
    END IF;

    IF v_destino IS NULL THEN
        RAISE EXCEPTION 'El destino elegido no existe' USING ERRCODE = 'P0002';
    END IF;

    RETURN sga.crear_mensaje(p_asunto, p_cuerpo, v_destino, v_ids);
END;
$$;

-- Responde un mensaje recibido: le llega solo a quien lo mandó.
CREATE FUNCTION sga.responder_mensaje(p_mensaje_id INTEGER, p_cuerpo TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_original sga.mensaje%ROWTYPE;
    v_remitente sga.persona%ROWTYPE;
BEGIN
    IF NOT sga.es_destinatario_mensaje(p_mensaje_id) THEN
        RAISE EXCEPTION 'Solo podés responder mensajes que recibiste' USING ERRCODE = '42501';
    END IF;
    IF NULLIF(btrim(p_cuerpo), '') IS NULL THEN
        RAISE EXCEPTION 'Escribí la respuesta' USING ERRCODE = '23514';
    END IF;

    SELECT * INTO v_original FROM sga.mensaje WHERE id = p_mensaje_id;
    SELECT * INTO v_remitente FROM sga.persona WHERE id = v_original.persona_emisor_id;

    RETURN sga.crear_mensaje(
        CASE WHEN v_original.asunto ILIKE 'Re:%' THEN v_original.asunto ELSE left('Re: ' || v_original.asunto, 150) END,
        p_cuerpo,
        v_remitente.apellido || ', ' || v_remitente.nombre,
        ARRAY[v_remitente.id],
        p_mensaje_id);
END;
$$;

CREATE FUNCTION sga.marcar_mensaje_leido(p_mensaje_id INTEGER)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
    UPDATE sga.mensaje_destinatario
    SET leido_en = now()
    WHERE mensaje_id = p_mensaje_id AND persona_id = sga.persona_actual_id() AND leido_en IS NULL;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.es_remitente_mensaje(INTEGER),
    sga.es_destinatario_mensaje(INTEGER),
    sga.enviar_mensaje(TEXT, TEXT, TEXT, INTEGER, TEXT),
    sga.responder_mensaje(INTEGER, TEXT),
    sga.marcar_mensaje_leido(INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.es_remitente_mensaje(INTEGER),
    sga.es_destinatario_mensaje(INTEGER),
    sga.enviar_mensaje(TEXT, TEXT, TEXT, INTEGER, TEXT),
    sga.responder_mensaje(INTEGER, TEXT),
    sga.marcar_mensaje_leido(INTEGER)
TO authenticated;

-- ---------------------------------------------------------------------
-- Bandejas de la persona logueada (corren con permisos de su dueño para
-- mostrar el nombre del remitente)
-- ---------------------------------------------------------------------

CREATE VIEW sga.mensaje_recibido AS
SELECT
    m.id,
    m.asunto,
    m.cuerpo,
    m.fecha,
    m.destino_descripcion,
    m.respuesta_a_id,
    p.apellido AS remitente_apellido,
    p.nombre AS remitente_nombre,
    d.leido_en
FROM sga.mensaje_destinatario d
JOIN sga.mensaje m ON m.id = d.mensaje_id
JOIN sga.persona p ON p.id = m.persona_emisor_id
WHERE d.persona_id = sga.persona_actual_id();

CREATE VIEW sga.mensaje_enviado AS
SELECT
    m.id,
    m.asunto,
    m.cuerpo,
    m.fecha,
    m.destino_descripcion,
    m.respuesta_a_id,
    (SELECT count(*) FROM sga.mensaje_destinatario d WHERE d.mensaje_id = m.id)::INTEGER AS destinatarios,
    (SELECT count(*) FROM sga.mensaje_destinatario d WHERE d.mensaje_id = m.id AND d.leido_en IS NOT NULL)::INTEGER AS leidos
FROM sga.mensaje m
WHERE m.persona_emisor_id = sga.persona_actual_id();

REVOKE ALL ON sga.mensaje_recibido, sga.mensaje_enviado FROM anon;
GRANT SELECT ON sga.mensaje_recibido, sga.mensaje_enviado TO authenticated;
