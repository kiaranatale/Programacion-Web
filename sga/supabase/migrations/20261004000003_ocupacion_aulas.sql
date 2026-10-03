-- =====================================================================
-- Ocupación de aulas (Administración → Ocupación de Aulas).
-- Devuelve, para una fecha, qué ocupa cada aula y en qué horario:
-- clases de los cursos vigentes ese día de la semana, eventos académicos
-- y exámenes finales, con la cantidad de inscriptos para detectar aulas
-- que quedan chicas. Solo expone catálogo y cantidades (ningún dato de
-- alumnos); corre con permisos del dueño para poder contar inscripciones.
-- =====================================================================

CREATE FUNCTION sga.ocupacion_aulas(p_fecha DATE)
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
    -- Clases: cursos vigentes en la fecha, según el día de la semana
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
    WHERE ef.aula_id IS NOT NULL AND ef.fecha = p_fecha;
$$;

REVOKE EXECUTE ON FUNCTION sga.ocupacion_aulas(DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION sga.ocupacion_aulas(DATE) TO authenticated;
