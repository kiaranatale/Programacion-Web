-- =====================================================================
-- Ajustes para cargar los cursos reales del SGA actual:
--   - Una materia puede tener varios cursos en el mismo período, en
--     fechas distintas (cursos bimestrales, p. ej. 81.73 tiene tres en
--     el segundo cuatrimestre). La unicidad pasa a incluir la fecha de
--     inicio.
--   - Los créditos de una materia pueden ser desconocidos (el listado de
--     cursos no los trae): NULL en vez de un número inventado.
--   - Vista curso_listado para "Académica → Cursos": datos del curso más
--     la cantidad de alumnos inscriptos. La cantidad es un agregado que
--     no expone a ningún alumno; la vista corre con permisos de su dueño
--     para poder contar inscripciones que RLS no le muestra a cada uno.
-- =====================================================================

ALTER TABLE sga.curso DROP CONSTRAINT uq_curso_materia_periodo;
ALTER TABLE sga.curso
    ADD CONSTRAINT uq_curso_materia_periodo
    UNIQUE (materia_id, anio, periodo, fecha_inicio);

ALTER TABLE sga.materia ALTER COLUMN creditos DROP NOT NULL;

CREATE VIEW sga.curso_listado AS
SELECT
    c.id,
    m.codigo,
    m.nombre AS materia,
    d.nombre AS departamento,
    c.anio,
    c.periodo,
    c.fecha_inicio,
    c.fecha_fin,
    c.activo,
    (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.curso_id = c.id)::INTEGER AS alumnos
FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id
JOIN sga.departamento d ON d.id = m.departamento_id;

REVOKE ALL ON sga.curso_listado FROM anon;
GRANT SELECT ON sga.curso_listado TO authenticated;
