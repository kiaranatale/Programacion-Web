-- =====================================================================
-- Inscripción a cursadas de ejemplo: 1er cuatrimestre 2027 (correr
-- DESPUÉS de seed_docencia.sql).
--
-- Primera inscripción (solicitudes) del 01/10 al 20/10/2026, para poder
-- probarla ahora; asignación de Administración después; segunda
-- inscripción del 02/11 al 06/11/2026. Las fechas se cambian desde
-- Administración → Inscripción a cursadas.
-- Cursos de materias del plan A22 con comisiones, horarios y cupos que
-- muestran los distintos casos para la alumna demo:
--   - 61.81 Microeconomía y 82.15 Matemática Aplicada: puede inscribirse.
--   - 61.82 Macroeconomía: se superpone con Microeconomía A.
--   - 71.20 Informática General: comisión A sin vacantes (cupo 1, ocupado
--     por un alumno ficticio), comisión B libre.
--   - 11.67 Estadística Aplicada: le falta la correlativa 93.36.
--   - 71.45: ya tiene la cursada aprobada.
--   - 82.15 Matemática Aplicada A tiene cupo 2 y ya la solicitaron tres
--     alumnos ficticios, para probar la asignación.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.periodo_inscripcion_cursada (anio, periodo, desde, hasta, segunda_desde, segunda_hasta)
VALUES (2027, '1C', DATE '2026-10-01', DATE '2026-10-20', DATE '2026-11-02', DATE '2026-11-06')
ON CONFLICT (anio, periodo) DO UPDATE
SET desde = EXCLUDED.desde, hasta = EXCLUDED.hasta, segunda_desde = EXCLUDED.segunda_desde, segunda_hasta = EXCLUDED.segunda_hasta
WHERE sga.periodo_inscripcion_cursada.segunda_desde IS NULL;

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

-- 82.15 A con cupo 2 y tres solicitudes de alumnos ficticios
UPDATE sga.comision co SET cupo = 2
FROM sga.curso c, sga.materia m
WHERE c.id = co.curso_id AND m.id = c.materia_id AND m.codigo = '82.15' AND c.anio = 2027 AND c.periodo = '1C'
  AND co.nombre = 'A' AND co.cupo <> 2;

INSERT INTO sga.solicitud_cursada (legajo_id, curso_id, comision_id, fecha)
SELECT l.id, c.id, co.id, x.fecha
FROM (VALUES ('DEMO-011', TIMESTAMPTZ '2026-10-02 10:00-03'),
             ('DEMO-012', TIMESTAMPTZ '2026-10-01 09:00-03'),
             ('DEMO-013', TIMESTAMPTZ '2026-10-03 18:30-03')) AS x (legajo, fecha)
JOIN sga.legajo l ON l.numero_legajo = x.legajo
JOIN sga.materia m ON m.codigo = '82.15'
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2027 AND c.periodo = '1C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

COMMIT;

SELECT m.codigo, co.nombre AS comision, co.cupo,
       (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.comision_id = co.id) AS inscriptos,
       (SELECT count(*) FROM sga.solicitud_cursada s WHERE s.comision_id = co.id) AS solicitudes
FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id AND c.anio = 2027 AND c.periodo = '1C'
JOIN sga.materia m ON m.id = c.materia_id
ORDER BY m.codigo, co.nombre;
