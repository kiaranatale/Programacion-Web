-- =====================================================================
-- Turnos de examen y fechas de final de ejemplo (correr DESPUÉS de
-- seed_docencia.sql).
--
--   - Julio 2026 (cerrado): la fecha del 03/08 de Programación web que
--     crea seed_docencia.sql queda en este turno, más la del 27/07.
--   - Diciembre 2026: dos fechas de Programación web (71.38) y de
--     Estructura de Datos y Programación (71.45). La inscripción se abre
--     desde el 01/10 para poder probarla ahora.
--   - Febrero 2027: una fecha de cada una.
--
-- Las fechas se cargan en el curso más reciente de la materia (cualquier
-- alumno que la haya cursado rinde en ellas). Se puede correr más de una
-- vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.turno_examen (nombre, inscripcion_desde, inscripcion_hasta)
VALUES
    ('Julio 2026',     DATE '2026-07-01', DATE '2026-07-24'),
    ('Diciembre 2026', DATE '2026-10-01', DATE '2026-12-11'),
    ('Febrero 2027',   DATE '2027-02-01', DATE '2027-02-12')
ON CONFLICT (nombre) DO NOTHING;

-- La fecha del 03/08 de seed_docencia.sql pasa al turno de julio
UPDATE sga.examen_final ef SET turno_id = t.id
FROM sga.turno_examen t, sga.curso c, sga.materia m
WHERE t.nombre = 'Julio 2026' AND c.id = ef.curso_id AND m.id = c.materia_id
  AND m.codigo = '71.38' AND ef.fecha = DATE '2026-08-03' AND ef.turno_id IS NULL;

INSERT INTO sga.examen_final (curso_id, turno_id, fecha, hora_inicio, hora_fin)
SELECT (SELECT c.id FROM sga.curso c WHERE c.materia_id = m.id ORDER BY c.fecha_inicio DESC LIMIT 1),
       t.id, x.fecha, x.desde, x.hasta
FROM (VALUES
    ('71.38', 'Julio 2026',     DATE '2026-07-27', TIME '09:00', TIME '12:00'),
    ('71.38', 'Diciembre 2026', DATE '2026-12-07', TIME '09:00', TIME '12:00'),
    ('71.38', 'Diciembre 2026', DATE '2026-12-14', TIME '09:00', TIME '12:00'),
    ('71.45', 'Diciembre 2026', DATE '2026-12-09', TIME '14:00', TIME '17:00'),
    ('71.45', 'Diciembre 2026', DATE '2026-12-16', TIME '14:00', TIME '17:00'),
    ('71.38', 'Febrero 2027',   DATE '2027-02-22', TIME '09:00', TIME '12:00'),
    ('71.45', 'Febrero 2027',   DATE '2027-02-24', TIME '14:00', TIME '17:00')
) AS x (codigo, turno, fecha, desde, hasta)
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.turno_examen t ON t.nombre = x.turno
WHERE NOT EXISTS (
    SELECT 1 FROM sga.examen_final ef JOIN sga.curso c ON c.id = ef.curso_id
    WHERE c.materia_id = m.id AND ef.fecha = x.fecha);

COMMIT;

SELECT t.nombre AS turno, m.codigo, to_char(ef.fecha, 'DD/MM/YYYY') AS fecha, ef.hora_inicio
FROM sga.examen_final ef
JOIN sga.turno_examen t ON t.id = ef.turno_id
JOIN sga.curso c ON c.id = ef.curso_id
JOIN sga.materia m ON m.id = c.materia_id
ORDER BY ef.fecha;
