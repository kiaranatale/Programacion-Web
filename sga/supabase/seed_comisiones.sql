-- =====================================================================
-- Comisiones del SGA actual: 34 comisiones de 19 materias,
-- 76 bloques de horario (2C 2026).
-- Generado con sga/scripts/csv_a_seed_comisiones.py. Correr después de
-- seed_cursos.sql y seed_aulas.sql. Se puede correr más de una vez:
-- actualiza cupo e inscriptos y reemplaza los horarios de esas comisiones.
-- No incluye profesores (datos de personas reales).
-- =====================================================================

BEGIN;

CREATE TEMP TABLE csv_comision (codigo TEXT, anio INTEGER, periodo TEXT, inicio DATE, fin DATE,
    nombre TEXT, cupo INTEGER, inscriptos INTEGER) ON COMMIT DROP;
INSERT INTO csv_comision VALUES
    ('10.23', 2026, '2C', NULL, NULL, 'A', 48, 47),
    ('15.09', 2026, '2C', NULL, NULL, 'A', 15, 13),
    ('15.12', 2026, '2C', NULL, NULL, 'A', 20, 21),
    ('16.93', 2026, '2C', NULL, NULL, 'A', NULL, 3),
    ('17.20', 2026, '2C', NULL, NULL, 'A', NULL, 2),
    ('23.05', 2026, '2C', NULL, NULL, 'K', 9, 3),
    ('25.03', 2026, '2C', NULL, NULL, 'A', 30, 23),
    ('25.20', 2026, '2C', NULL, NULL, 'K', 24, 17),
    ('25.66', 2026, '2C', NULL, NULL, 'K', 9, 0),
    ('30.28', 2026, '2C', NULL, NULL, 'A', 24, 3),
    ('31.73', 2026, '2C', NULL, NULL, 'M', NULL, 2),
    ('61.27', 2026, '2C', NULL, NULL, 'A', 48, 41),
    ('61.27', 2026, '2C', NULL, NULL, 'B', 24, 24),
    ('61.27', 2026, '2C', NULL, NULL, 'C', 48, 48),
    ('61.27', 2026, '2C', NULL, NULL, 'D', 41, 33),
    ('67.08', 2026, '2C', NULL, NULL, 'A', 6, 3),
    ('73.67', 2026, '2C', NULL, NULL, 'A', 18, 3),
    ('73.70', 2026, '2C', NULL, NULL, 'A', 10, 6),
    ('93.18', 2026, '2C', NULL, NULL, 'A', 48, 47),
    ('93.18', 2026, '2C', NULL, NULL, 'B', 49, 48),
    ('93.18', 2026, '2C', NULL, NULL, 'C', 48, 31),
    ('93.18', 2026, '2C', NULL, NULL, 'D', 48, 10),
    ('93.18', 2026, '2C', NULL, NULL, 'E', 49, 49),
    ('93.18', 2026, '2C', NULL, NULL, 'F', 49, 49),
    ('93.18', 2026, '2C', NULL, NULL, 'G', 49, 49),
    ('93.18', 2026, '2C', NULL, NULL, 'H', 50, 47),
    ('93.18', 2026, '2C', NULL, NULL, 'K', 60, 59),
    ('93.21', 2026, '2C', NULL, NULL, 'A', 24, 17),
    ('93.21', 2026, '2C', NULL, NULL, 'B', 24, 14),
    ('93.58', 2026, '2C', NULL, NULL, 'A', 60, 49),
    ('93.58', 2026, '2C', NULL, NULL, 'B', 30, 13),
    ('93.58', 2026, '2C', NULL, NULL, 'C', 30, 25),
    ('94.27', 2026, '2C', NULL, NULL, 'A', 48, 48),
    ('94.27', 2026, '2C', NULL, NULL, 'B', 24, 23);

CREATE TEMP TABLE csv_horario (codigo TEXT, anio INTEGER, periodo TEXT, inicio DATE, comision TEXT,
    dia sga.dia_semana, desde TIME, hasta TIME, modalidad sga.modalidad_horario, aula TEXT, sede TEXT) ON COMMIT DROP;
INSERT INTO csv_horario VALUES
    ('10.23', 2026, '2C', NULL, 'A', 'MARTES', '16:00', '19:00', 'PRESENCIAL', '601F', 'Sede Distrito Financiero'),
    ('15.09', 2026, '2C', NULL, 'A', 'VIERNES', '18:00', '21:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('15.12', 2026, '2C', NULL, 'A', 'JUEVES', '09:00', '12:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('16.93', 2026, '2C', NULL, 'A', 'LUNES', '16:00', '19:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('17.20', 2026, '2C', NULL, 'A', 'VIERNES', '18:30', '22:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('23.05', 2026, '2C', NULL, 'K', 'JUEVES', '16:00', '19:00', 'PRESENCIAL', '604F', 'Sede Distrito Financiero'),
    ('25.03', 2026, '2C', NULL, 'A', 'LUNES', '18:00', '21:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('25.20', 2026, '2C', NULL, 'K', 'MIERCOLES', '15:00', '18:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('25.20', 2026, '2C', NULL, 'K', 'VIERNES', '19:00', '22:00', 'PRESENCIAL', '102T', 'SDT'),
    ('25.66', 2026, '2C', NULL, 'K', 'JUEVES', '16:00', '19:00', 'PRESENCIAL', '604F', 'Sede Distrito Financiero'),
    ('30.28', 2026, '2C', NULL, 'A', 'JUEVES', '19:00', '22:00', 'PRESENCIAL', '003T', 'SDT'),
    ('30.28', 2026, '2C', NULL, 'A', 'VIERNES', '19:00', '22:00', 'PRESENCIAL', '004T', 'SDT'),
    ('31.73', 2026, '2C', NULL, 'M', 'MIERCOLES', '16:00', '19:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('31.73', 2026, '2C', NULL, 'M', 'VIERNES', '16:00', '19:00', 'VIRTUAL_SINCRONICO', NULL, NULL),
    ('61.27', 2026, '2C', NULL, 'A', 'DOMINGO', '13:00', '14:00', 'VIRTUAL_ASINCRONICO', NULL, NULL),
    ('61.27', 2026, '2C', NULL, 'A', 'MIERCOLES', '19:00', '21:00', 'PRESENCIAL', '801F', 'Sede Distrito Financiero'),
    ('61.27', 2026, '2C', NULL, 'B', 'DOMINGO', '12:00', '13:00', 'VIRTUAL_ASINCRONICO', NULL, NULL),
    ('61.27', 2026, '2C', NULL, 'B', 'JUEVES', '19:00', '21:00', 'PRESENCIAL', '702F', 'Sede Distrito Financiero'),
    ('61.27', 2026, '2C', NULL, 'C', 'DOMINGO', '14:00', '15:00', 'VIRTUAL_ASINCRONICO', NULL, NULL),
    ('61.27', 2026, '2C', NULL, 'C', 'JUEVES', '16:00', '18:00', 'PRESENCIAL', '401F', 'Sede Distrito Financiero'),
    ('61.27', 2026, '2C', NULL, 'D', 'DOMINGO', '12:00', '13:00', 'VIRTUAL_ASINCRONICO', NULL, NULL),
    ('61.27', 2026, '2C', NULL, 'D', 'MIERCOLES', '16:00', '18:00', 'PRESENCIAL', '301F', 'Sede Distrito Financiero'),
    ('67.08', 2026, '2C', NULL, 'A', 'MIERCOLES', '13:00', '17:00', 'PRESENCIAL', 'S101T', 'SDT'),
    ('73.67', 2026, '2C', NULL, 'A', 'JUEVES', '10:00', '13:00', 'PRESENCIAL', '204R', 'Sede Rectorado'),
    ('73.70', 2026, '2C', NULL, 'A', 'VIERNES', '13:00', '16:00', 'PRESENCIAL', '004R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'A', 'LUNES', '14:00', '16:00', 'PRESENCIAL', '001R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'A', 'MIERCOLES', '14:00', '16:00', 'PRESENCIAL', '201T', 'SDT'),
    ('93.18', 2026, '2C', NULL, 'A', 'JUEVES', '14:00', '16:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'B', 'LUNES', '12:00', '14:00', 'PRESENCIAL', '007R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'B', 'MIERCOLES', '10:00', '12:00', 'PRESENCIAL', '003T', 'SDT'),
    ('93.18', 2026, '2C', NULL, 'B', 'MIERCOLES', '10:00', '12:00', 'PRESENCIAL', '004T', 'SDT'),
    ('93.18', 2026, '2C', NULL, 'B', 'JUEVES', '12:00', '14:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'C', 'LUNES', '10:00', '12:00', 'PRESENCIAL', '108R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'C', 'JUEVES', '11:00', '13:00', 'PRESENCIAL', '007R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'C', 'VIERNES', '10:00', '12:00', 'PRESENCIAL', '101R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'D', 'LUNES', '10:00', '12:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'D', 'MIERCOLES', '10:00', '12:00', 'PRESENCIAL', '009R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'D', 'JUEVES', '10:00', '12:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'E', 'MARTES', '14:00', '16:00', 'PRESENCIAL', '003R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'E', 'JUEVES', '08:00', '10:00', 'PRESENCIAL', '003R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'E', 'VIERNES', '12:00', '14:00', 'PRESENCIAL', '003R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'F', 'LUNES', '08:00', '10:00', 'PRESENCIAL', '002R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'F', 'MARTES', '10:00', '12:00', 'PRESENCIAL', '006R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'F', 'VIERNES', '10:00', '12:00', 'PRESENCIAL', '110R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'G', 'MARTES', '14:00', '16:00', 'PRESENCIAL', '201R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'G', 'JUEVES', '12:00', '14:00', 'PRESENCIAL', '109R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'G', 'VIERNES', '12:00', '14:00', 'PRESENCIAL', '006R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'H', 'LUNES', '14:00', '16:00', 'PRESENCIAL', '102R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'H', 'MARTES', '14:00', '16:00', 'PRESENCIAL', '002R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'H', 'JUEVES', '11:00', '13:00', 'PRESENCIAL', '006R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'LUNES', '08:00', '10:00', 'PRESENCIAL', '202R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'LUNES', '08:00', '10:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'MARTES', '12:00', '14:00', 'PRESENCIAL', '002R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'MARTES', '12:00', '14:00', 'PRESENCIAL', '003R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'JUEVES', '08:00', '10:00', 'PRESENCIAL', '202R', 'Sede Rectorado'),
    ('93.18', 2026, '2C', NULL, 'K', 'JUEVES', '08:00', '10:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.21', 2026, '2C', NULL, 'A', 'JUEVES', '16:00', '19:00', 'PRESENCIAL', '001T', 'SDT'),
    ('93.21', 2026, '2C', NULL, 'A', 'VIERNES', '08:00', '11:00', 'PRESENCIAL', '001T', 'SDT'),
    ('93.21', 2026, '2C', NULL, 'B', 'VIERNES', '08:00', '11:00', 'PRESENCIAL', '002T', 'SDT'),
    ('93.21', 2026, '2C', NULL, 'B', 'VIERNES', '11:00', '14:00', 'PRESENCIAL', '002T', 'SDT'),
    ('93.58', 2026, '2C', NULL, 'A', 'MARTES', '10:00', '12:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'A', 'MARTES', '12:00', '14:00', 'PRESENCIAL', '203R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'A', 'JUEVES', '11:00', '14:00', 'PRESENCIAL', '003R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'A', 'VIERNES', '14:00', '16:00', 'PRESENCIAL', '109R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'B', 'MARTES', '11:00', '13:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'B', 'MARTES', '13:00', '15:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'B', 'JUEVES', '11:00', '14:00', 'PRESENCIAL', '005R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'B', 'VIERNES', '12:00', '14:00', 'PRESENCIAL', '005R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'C', 'MARTES', '15:00', '17:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'C', 'JUEVES', '14:00', '16:00', 'PRESENCIAL', '005R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'C', 'JUEVES', '16:00', '18:00', 'PRESENCIAL', '005R', 'Sede Rectorado'),
    ('93.58', 2026, '2C', NULL, 'C', 'VIERNES', '14:00', '17:00', 'PRESENCIAL', '104R', 'Sede Rectorado'),
    ('94.27', 2026, '2C', NULL, 'A', 'MIERCOLES', '16:00', '18:00', 'PRESENCIAL', '501F', 'Sede Distrito Financiero'),
    ('94.27', 2026, '2C', NULL, 'A', 'SABADO', '19:00', '20:00', 'VIRTUAL_ASINCRONICO', NULL, NULL),
    ('94.27', 2026, '2C', NULL, 'B', 'JUEVES', '16:00', '18:00', 'PRESENCIAL', '603F', 'Sede Distrito Financiero'),
    ('94.27', 2026, '2C', NULL, 'B', 'SABADO', '19:00', '20:00', 'VIRTUAL_ASINCRONICO', NULL, NULL);

-- Curso de cada comisión: el de esa fecha de inicio o, sin fecha, el
-- primero del período. Los que no existen se crean (sin fechas en el CSV:
-- 1C del 01/03 al 15/07, 2C del 26/07 al 31/12).
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT DISTINCT m.id, x.anio, x.periodo,
    COALESCE(x.inicio, make_date(x.anio, 1, 1) + (CASE x.periodo WHEN '1C' THEN '2 months' ELSE '6 months 25 days' END)::INTERVAL),
    COALESCE(x.fin, make_date(x.anio, 1, 1) + (CASE x.periodo WHEN '1C' THEN '6 months 14 days' ELSE '11 months 30 days' END)::INTERVAL)
FROM csv_comision x
JOIN sga.materia m ON m.codigo = x.codigo
WHERE NOT EXISTS (
    SELECT 1 FROM sga.curso c
    WHERE c.materia_id = m.id AND c.anio = x.anio AND c.periodo = x.periodo
      AND (x.inicio IS NULL OR c.fecha_inicio = x.inicio))
ON CONFLICT (materia_id, anio, periodo, fecha_inicio) DO NOTHING;

CREATE TEMP TABLE csv_curso ON COMMIT DROP AS
SELECT DISTINCT ON (x.codigo, x.anio, x.periodo, x.inicio, x.nombre)
    x.*, c.id AS curso_id
FROM csv_comision x
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = x.anio AND c.periodo = x.periodo
    AND (x.inicio IS NULL OR c.fecha_inicio = x.inicio)
ORDER BY x.codigo, x.anio, x.periodo, x.inicio, x.nombre, c.fecha_inicio, c.id;

INSERT INTO sga.comision (curso_id, nombre, cupo, inscriptos_sga)
SELECT curso_id, nombre, cupo, inscriptos FROM csv_curso
ON CONFLICT (curso_id, nombre) DO UPDATE
SET cupo = EXCLUDED.cupo, inscriptos_sga = EXCLUDED.inscriptos_sga;

-- Aulas que no están en seed_aulas.sql, en el edificio de su sede
INSERT INTO sga.aula (edificio_id, codigo, capacidad)
SELECT DISTINCT ON (h.aula) e.id, h.aula, NULL::INTEGER
FROM csv_horario h
JOIN sga.edificio e ON e.codigo = CASE h.sede WHEN 'Sede Distrito Financiero' THEN 'SEDE-DM' WHEN 'Sede Rectorado' THEN 'SEDE-RE' ELSE 'SIN-EDIF' END
WHERE h.aula IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sga.aula a WHERE a.codigo = h.aula)
ORDER BY h.aula
ON CONFLICT (edificio_id, codigo) DO NOTHING;

-- Horarios: se reemplazan los de las comisiones del CSV
DELETE FROM sga.horario_comision hc
USING csv_curso x JOIN sga.comision co ON co.curso_id = x.curso_id AND co.nombre = x.nombre
WHERE hc.comision_id = co.id;

INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id, modalidad)
SELECT co.id, h.dia, h.desde, h.hasta,
    (SELECT a.id FROM sga.aula a WHERE a.codigo = h.aula ORDER BY a.id LIMIT 1), h.modalidad
FROM csv_horario h
JOIN csv_curso x ON x.codigo = h.codigo AND x.anio = h.anio AND x.periodo = h.periodo
    AND x.inicio IS NOT DISTINCT FROM h.inicio AND x.nombre = h.comision
JOIN sga.comision co ON co.curso_id = x.curso_id AND co.nombre = x.nombre;

COMMIT;

SELECT
    34 AS comisiones_csv,
    (SELECT count(*) FROM sga.comision WHERE inscriptos_sga IS NOT NULL) AS comisiones_cargadas,
    (SELECT count(*) FROM sga.horario_comision hc JOIN sga.comision co ON co.id = hc.comision_id
        WHERE co.inscriptos_sga IS NOT NULL) AS horarios_cargados;
