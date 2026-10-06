-- =====================================================================
-- Inscripción a cursadas de ejemplo: 1er cuatrimestre 2027 (correr
-- DESPUÉS de seed_docencia.sql).
--
-- La inscripción se abre desde el 01/10/2026 para poder probarla ahora.
-- Cursos de materias del plan A22 con comisiones, horarios y cupos que
-- muestran los distintos casos para la alumna demo:
--   - 61.81 Microeconomía y 82.15 Matemática Aplicada: puede inscribirse.
--   - 61.82 Macroeconomía: se superpone con Microeconomía A.
--   - 71.20 Informática General: comisión A sin vacantes (cupo 1, ocupado
--     por un alumno ficticio), comisión B libre.
--   - 11.67 Estadística Aplicada: le falta la correlativa 93.36.
--   - 71.45: ya tiene la cursada aprobada.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.periodo_inscripcion_cursada (anio, periodo, desde, hasta)
VALUES (2027, '1C', DATE '2026-10-01', DATE '2027-03-05')
ON CONFLICT (anio, periodo) DO NOTHING;

INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT m.id, 2027, '1C', DATE '2027-03-08', DATE '2027-07-03'
FROM sga.materia m
WHERE m.codigo IN ('61.81', '61.82', '82.15', '71.20', '11.67', '71.45')
ON CONFLICT DO NOTHING;

INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, x.comision, x.cupo
FROM (VALUES
    ('61.81', 'A', 40), ('61.82', 'A', 40), ('82.15', 'A', 35),
    ('71.20', 'A', 1), ('71.20', 'B', 30), ('11.67', 'A', 40), ('71.45', 'A', 30)
) AS x (codigo, comision, cupo)
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2027 AND c.periodo = '1C'
WHERE NOT EXISTS (SELECT 1 FROM sga.comision co WHERE co.curso_id = c.id AND co.nombre = x.comision);

INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id)
SELECT co.id, x.dia::sga.dia_semana, x.desde, x.hasta, (SELECT a.id FROM sga.aula a WHERE a.codigo = x.aula LIMIT 1)
FROM (VALUES
    ('61.81', 'A', 'MARTES',    TIME '14:00', TIME '17:00', '101'),
    ('61.82', 'A', 'MARTES',    TIME '15:00', TIME '18:00', '304'),
    ('82.15', 'A', 'JUEVES',    TIME '09:00', TIME '12:00', '304'),
    ('71.20', 'A', 'LUNES',     TIME '09:00', TIME '12:00', 'LAB-2'),
    ('71.20', 'B', 'MIERCOLES', TIME '18:00', TIME '21:00', 'LAB-2'),
    ('11.67', 'A', 'VIERNES',   TIME '09:00', TIME '12:00', '101'),
    ('71.45', 'A', 'VIERNES',   TIME '14:00', TIME '17:00', 'LAB-2')
) AS x (codigo, comision, dia, desde, hasta, aula)
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2027 AND c.periodo = '1C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = x.comision
WHERE NOT EXISTS (SELECT 1 FROM sga.horario_comision h WHERE h.comision_id = co.id);

-- Un alumno ficticio ocupa la única vacante de 71.20 A
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, c.id, co.id
FROM sga.legajo l
JOIN sga.materia m ON m.codigo = '71.20'
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2027 AND c.periodo = '1C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
WHERE l.numero_legajo = 'DEMO-014'
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

COMMIT;

SELECT m.codigo, co.nombre AS comision, co.cupo,
       (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.comision_id = co.id) AS inscriptos
FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id AND c.anio = 2027 AND c.periodo = '1C'
JOIN sga.materia m ON m.id = c.materia_id
ORDER BY m.codigo, co.nombre;
