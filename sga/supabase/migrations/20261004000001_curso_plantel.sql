-- =====================================================================
-- Detalle del curso como en el SGA actual:
--   - Responsable del curso y cargo de cada docente (Adjunto, Experto
--     externo, Profesor Instructor, etc.).
--   - Contenidos mínimos de la materia.
--   - Vista curso_plantel: el plantel de cada curso (nombre, cargo y
--     mail institucional de los docentes) lo ve cualquier usuario con
--     sesión, como en el SGA actual. Las políticas de persona/docente no
--     se abren: la vista expone solo esas columnas y corre con permisos
--     de su dueño.
-- =====================================================================

ALTER TABLE sga.docente_comision ADD COLUMN cargo VARCHAR;

ALTER TABLE sga.curso
    ADD COLUMN responsable_docente_id INTEGER
        REFERENCES sga.docente (id) ON DELETE SET NULL;

ALTER TABLE sga.materia ADD COLUMN contenidos_minimos TEXT;

CREATE VIEW sga.curso_plantel AS
SELECT
    c.id AS curso_id,
    d.id AS docente_id,
    p.apellido,
    p.nombre,
    p.mail_institucional,
    (SELECT max(dc.cargo)
        FROM sga.docente_comision dc
        JOIN sga.comision co ON co.id = dc.comision_id
        WHERE co.curso_id = c.id AND dc.docente_id = d.id) AS cargo,
    (c.responsable_docente_id = d.id) AS responsable
FROM sga.curso c
JOIN sga.docente d
  ON d.id = c.responsable_docente_id
  OR d.id IN (
      SELECT dc.docente_id
      FROM sga.docente_comision dc
      JOIN sga.comision co ON co.id = dc.comision_id
      WHERE co.curso_id = c.id)
JOIN sga.persona p ON p.id = d.persona_id;

REVOKE ALL ON sga.curso_plantel FROM anon;
GRANT SELECT ON sga.curso_plantel TO authenticated;
