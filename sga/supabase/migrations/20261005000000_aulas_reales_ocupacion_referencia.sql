-- =====================================================================
-- Aulas reales del SGA actual y su ocupación semanal de referencia.
--
--   - aula.capacidad pasa a admitir NULL: varios espacios del SGA figuran
--     con capacidad 0 o sin capacidad (CIC, CIDEI, CAFiBiS, etc.).
--   - aula_ocupacion_referencia: qué franjas ocupa cada aula cada día de
--     la semana según el SGA actual, por tipo (curso, evento o
--     superposición), con el período en que vale. Sirve para ver la
--     ocupación real antes de tener cargados todos los cursos con sus
--     horarios. No dice qué materia ocupa el aula (el SGA no lo expone en
--     la grilla).
--   - ocupacion_aulas(fecha) suma esa referencia a lo cargado en el SGA.
-- =====================================================================

ALTER TABLE sga.aula ALTER COLUMN capacidad DROP NOT NULL;
ALTER TABLE sga.aula DROP CONSTRAINT ck_aula_capacidad_positiva;
ALTER TABLE sga.aula
    ADD CONSTRAINT ck_aula_capacidad_positiva CHECK (capacidad IS NULL OR capacidad > 0);

CREATE TABLE sga.aula_ocupacion_referencia (
    id SERIAL PRIMARY KEY,
    aula_id INTEGER NOT NULL
        REFERENCES sga.aula (id) ON DELETE CASCADE,
    dia_semana sga.dia_semana NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    tipo VARCHAR NOT NULL,
    vigencia_desde DATE NOT NULL,
    vigencia_hasta DATE NOT NULL,
    fuente VARCHAR NOT NULL,

    CONSTRAINT uq_aula_ocupacion_referencia
        UNIQUE (aula_id, dia_semana, hora_inicio, vigencia_desde),
    CONSTRAINT ck_aula_ocupacion_referencia_tipo
        CHECK (tipo IN ('CURSO', 'EVENTO', 'SUPERPOSICION')),
    CONSTRAINT ck_aula_ocupacion_referencia_horario
        CHECK (hora_fin > hora_inicio),
    CONSTRAINT ck_aula_ocupacion_referencia_vigencia
        CHECK (vigencia_hasta >= vigencia_desde)
);

CREATE INDEX ix_aula_ocupacion_referencia_aula_id ON sga.aula_ocupacion_referencia (aula_id);

ALTER TABLE sga.aula_ocupacion_referencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.aula_ocupacion_referencia FORCE ROW LEVEL SECURITY;

CREATE POLICY aula_ocupacion_referencia_select_autenticados ON sga.aula_ocupacion_referencia
    FOR SELECT TO authenticated USING (true);
CREATE POLICY aula_ocupacion_referencia_admin_all ON sga.aula_ocupacion_referencia
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- Misma función, más la ocupación de referencia vigente para esa fecha
-- (tipos REF_CURSO, REF_EVENTO y REF_SUPERPOSICION).
CREATE OR REPLACE FUNCTION sga.ocupacion_aulas(p_fecha DATE)
RETURNS TABLE (
    aula_id INTEGER,
    tipo TEXT,
    descripcion TEXT,
    hora_inicio TIME,
    hora_fin TIME,
    inscriptos INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT hc.aula_id,
           'CURSO',
           m.codigo || ' - ' || m.nombre || ' (Com. ' || co.nombre || ')',
           hc.hora_inicio,
           hc.hora_fin,
           (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.comision_id = co.id)::INTEGER
    FROM sga.horario_comision hc
    JOIN sga.comision co ON co.id = hc.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE hc.aula_id IS NOT NULL
      AND c.activo
      AND p_fecha BETWEEN c.fecha_inicio AND c.fecha_fin
      AND hc.dia_semana = (ARRAY['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO']::sga.dia_semana[])
                          [EXTRACT(ISODOW FROM p_fecha)::INTEGER]

    UNION ALL

    SELECT e.aula_id, 'EVENTO', e.nombre, e.hora_inicio, e.hora_fin, NULL
    FROM sga.evento_academico e
    WHERE e.aula_id IS NOT NULL AND e.fecha = p_fecha

    UNION ALL

    SELECT ef.aula_id,
           'EXAMEN',
           'Final ' || m.codigo || ' - ' || m.nombre,
           ef.hora_inicio,
           ef.hora_fin,
           (SELECT count(*) FROM sga.inscripcion_examen_final ief WHERE ief.examen_final_id = ef.id)::INTEGER
    FROM sga.examen_final ef
    JOIN sga.curso c ON c.id = ef.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE ef.aula_id IS NOT NULL AND ef.fecha = p_fecha

    UNION ALL

    SELECT r.aula_id,
           'REF_' || r.tipo,
           'Ocupación según el SGA actual (' || r.fuente || ')',
           r.hora_inicio,
           r.hora_fin,
           NULL
    FROM sga.aula_ocupacion_referencia r
    WHERE p_fecha BETWEEN r.vigencia_desde AND r.vigencia_hasta
      AND r.dia_semana = (ARRAY['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO']::sga.dia_semana[])
                         [EXTRACT(ISODOW FROM p_fecha)::INTEGER];
$$;
