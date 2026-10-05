-- =====================================================================
-- Docencia → Mis comisiones y Carga de notas.
--
--   - mis_comisiones(): comisiones que dicta el docente logueado, con
--     inscriptos y notas de cursada pendientes.
--   - cargar_nota_cursada(): nota de 0 a 10 de un alumno de una comisión
--     propia. Con 4 o más la cursada queda CURSADA_APROBADA; con menos,
--     DESAPROBADA (hay que recursar). Sin nota vuelve a CURSANDO. No se
--     puede cambiar si el alumno ya rindió algún final.
--   - mesas_de_final_docente(): mesas de final de los cursos donde dicta,
--     con sus inscriptos de las comisiones propias.
--   - cargar_nota_final(): nota de un inscripto a una mesa ya tomada. Se
--     carga una sola vez (las correcciones las hace Administración); las
--     reglas existentes calculan la nota definitiva, el estado y el
--     rendimiento académico.
-- =====================================================================

CREATE FUNCTION sga.mis_comisiones()
RETURNS TABLE (
    comision_id INTEGER,
    curso_id INTEGER,
    codigo TEXT,
    materia TEXT,
    comision TEXT,
    anio INTEGER,
    periodo TEXT,
    activo BOOLEAN,
    cargo TEXT,
    responsable BOOLEAN,
    inscriptos INTEGER,
    sin_nota INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT co.id, c.id, m.codigo::TEXT, m.nombre::TEXT, co.nombre::TEXT, c.anio, c.periodo::TEXT, c.activo,
           dc.cargo::TEXT, c.responsable_docente_id = dc.docente_id,
           (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.comision_id = co.id AND ic.estado <> 'ABANDONADA')::INTEGER,
           (SELECT count(*) FROM sga.inscripcion_curso ic
            WHERE ic.comision_id = co.id AND ic.estado = 'CURSANDO' AND ic.nota_cursada IS NULL)::INTEGER
    FROM sga.docente_comision dc
    JOIN sga.comision co ON co.id = dc.comision_id
    JOIN sga.curso c ON c.id = co.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    WHERE dc.docente_id = sga.docente_actual_id()
    ORDER BY c.activo DESC, c.anio DESC, c.periodo DESC, m.codigo, co.nombre;
$$;

CREATE FUNCTION sga.cargar_nota_cursada(p_inscripcion_id INTEGER, p_nota NUMERIC)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ic sga.inscripcion_curso%ROWTYPE;
BEGIN
    SELECT * INTO v_ic FROM sga.inscripcion_curso WHERE id = p_inscripcion_id FOR UPDATE;
    IF NOT FOUND OR NOT sga.es_docente_de_comision(v_ic.comision_id) THEN
        RAISE EXCEPTION 'Solo podés cargar notas de las comisiones que dictás' USING ERRCODE = '42501';
    END IF;
    IF p_nota IS NOT NULL AND (p_nota < 0 OR p_nota > 10) THEN
        RAISE EXCEPTION 'La nota tiene que estar entre 0 y 10' USING ERRCODE = '23514';
    END IF;
    IF v_ic.estado IN ('APROBADA', 'ABANDONADA')
        OR EXISTS (SELECT 1 FROM sga.inscripcion_examen_final WHERE inscripcion_curso_id = v_ic.id) THEN
        RAISE EXCEPTION 'La nota de cursada ya no se puede cambiar: el alumno rindió finales o dejó la materia' USING ERRCODE = '23514';
    END IF;

    UPDATE sga.inscripcion_curso
    SET nota_cursada = round(p_nota, 2),
        fecha_carga_cursada = CASE WHEN p_nota IS NULL THEN NULL ELSE now() END,
        docente_id = CASE WHEN p_nota IS NULL THEN NULL ELSE sga.docente_actual_id() END,
        estado = CASE
            WHEN p_nota IS NULL THEN 'CURSANDO'
            WHEN p_nota >= 4 THEN 'CURSADA_APROBADA'
            ELSE 'DESAPROBADA'
        END::sga.estado_inscripcion_curso
    WHERE id = v_ic.id;
END;
$$;

CREATE FUNCTION sga.mesas_de_final_docente()
RETURNS TABLE (
    examen_final_id INTEGER,
    curso_id INTEGER,
    codigo TEXT,
    materia TEXT,
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
    SELECT ef.id, c.id, m.codigo::TEXT, m.nombre::TEXT, ef.fecha, ef.hora_inicio,
           count(ief.id)::INTEGER,
           count(ief.id) FILTER (WHERE ief.nota_final IS NULL)::INTEGER
    FROM sga.examen_final ef
    JOIN sga.curso c ON c.id = ef.curso_id
    JOIN sga.materia m ON m.id = c.materia_id
    LEFT JOIN sga.inscripcion_examen_final ief ON ief.examen_final_id = ef.id
        AND EXISTS (SELECT 1 FROM sga.inscripcion_curso ic
                    WHERE ic.id = ief.inscripcion_curso_id AND sga.es_docente_de_comision(ic.comision_id))
    WHERE EXISTS (SELECT 1 FROM sga.comision co
                  JOIN sga.docente_comision dc ON dc.comision_id = co.id
                  WHERE co.curso_id = c.id AND dc.docente_id = sga.docente_actual_id())
    GROUP BY ef.id, c.id, m.codigo, m.nombre
    ORDER BY ef.fecha DESC, m.codigo;
$$;

CREATE FUNCTION sga.cargar_nota_final(p_inscripcion_examen_final_id INTEGER, p_nota NUMERIC)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ief sga.inscripcion_examen_final%ROWTYPE;
    v_comision INTEGER;
    v_fecha DATE;
BEGIN
    SELECT * INTO v_ief FROM sga.inscripcion_examen_final WHERE id = p_inscripcion_examen_final_id FOR UPDATE;
    SELECT ic.comision_id INTO v_comision FROM sga.inscripcion_curso ic WHERE ic.id = v_ief.inscripcion_curso_id;
    IF v_ief.id IS NULL OR NOT sga.es_docente_de_comision(v_comision) THEN
        RAISE EXCEPTION 'Solo podés cargar notas de alumnos de tus comisiones' USING ERRCODE = '42501';
    END IF;
    IF p_nota IS NULL OR p_nota < 0 OR p_nota > 10 THEN
        RAISE EXCEPTION 'La nota tiene que estar entre 0 y 10' USING ERRCODE = '23514';
    END IF;
    SELECT fecha INTO v_fecha FROM sga.examen_final WHERE id = v_ief.examen_final_id;
    IF v_fecha > sga.hoy() THEN
        RAISE EXCEPTION 'La mesa todavía no se tomó (es el %)', to_char(v_fecha, 'DD/MM/YYYY') USING ERRCODE = '23514';
    END IF;
    IF v_ief.nota_final IS NOT NULL THEN
        RAISE EXCEPTION 'La nota ya está cargada; para corregirla pedíselo a Administración' USING ERRCODE = '23514';
    END IF;

    UPDATE sga.inscripcion_examen_final
    SET nota_final = round(p_nota, 2), fecha_carga_final = now(), docente_id = sga.docente_actual_id()
    WHERE id = v_ief.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.mis_comisiones(),
    sga.cargar_nota_cursada(INTEGER, NUMERIC),
    sga.mesas_de_final_docente(),
    sga.cargar_nota_final(INTEGER, NUMERIC)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.mis_comisiones(),
    sga.cargar_nota_cursada(INTEGER, NUMERIC),
    sga.mesas_de_final_docente(),
    sga.cargar_nota_final(INTEGER, NUMERIC)
TO authenticated;
