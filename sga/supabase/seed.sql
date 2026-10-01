-- =====================================================================
-- Datos de prueba para desarrollo (catálogos: escuela, carrera, plan,
-- materias, aulas, cursos y comisiones). No incluye personas ni usuarios
-- de Auth: esos se crean en el Paso 1 (login).
--
-- Se puede correr más de una vez: cada INSERT ignora lo que ya existe.
-- Con Supabase en la nube: pegarlo completo en el SQL Editor y ejecutar.
-- =====================================================================

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES
    ('Escuela de Ingeniería y Tecnología')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.departamento (nombre) VALUES
    ('Ciencias Básicas'),
    ('Informática')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'INF', 'Ingeniería en Informática', id
FROM sga.escuela WHERE nombre = 'Escuela de Ingeniería y Tecnología'
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'INF-2023', 240, DATE '2023-01-01'
FROM sga.carrera WHERE codigo = 'INF'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM (VALUES
    ('93.58', 'Análisis Matemático I',           'Ciencias Básicas', 6),
    ('93.59', 'Álgebra',                         'Ciencias Básicas', 6),
    ('72.31', 'Introducción a la Programación',  'Informática',      6),
    ('72.40', 'Programación Web',                'Informática',      3)
) AS m (codigo, nombre, departamento, creditos)
JOIN sga.departamento d ON d.nombre = m.departamento
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO sga.plan_materia (plan_id, materia_id, anio_sugerido, cuatrimestre_sugerido)
SELECT p.id, m.id, x.anio, x.cuatri
FROM (VALUES
    ('93.58', 1, 1),
    ('93.59', 1, 1),
    ('72.31', 1, 2),
    ('72.40', 2, 2)
) AS x (codigo, anio, cuatri)
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.plan_estudio p ON p.codigo = 'INF-2023'
ON CONFLICT (plan_id, materia_id) DO NOTHING;

INSERT INTO sga.edificio (codigo, nombre, direccion) VALUES
    ('SEDE-DM', 'Sede Distrito Financiero', 'Av. Eduardo Madero 399, CABA'),
    ('SEDE-PT', 'Sede Puerto',              'Lavardén 389, CABA')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO sga.aula (edificio_id, codigo, capacidad)
SELECT e.id, a.codigo, a.capacidad
FROM (VALUES
    ('SEDE-DM', '101',    40),
    ('SEDE-DM', '304',    60),
    ('SEDE-DM', 'LAB-2',  30),
    ('SEDE-PT', '108',    80)
) AS a (edificio, codigo, capacidad)
JOIN sga.edificio e ON e.codigo = a.edificio
ON CONFLICT (edificio_id, codigo) DO NOTHING;

INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, '2C', DATE '2026-08-10', DATE '2026-12-04'
FROM sga.materia WHERE codigo IN ('93.58', '72.31', '72.40')
ON CONFLICT (materia_id, anio, periodo) DO NOTHING;

INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, x.nombre, x.cupo
FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id
CROSS JOIN (VALUES ('A', 40), ('B', 30)) AS x (nombre, cupo)
WHERE c.anio = 2026 AND c.periodo = '2C'
ON CONFLICT (curso_id, nombre) DO NOTHING;

-- horario_comision no tiene clave única: solo se cargan horarios para
-- las comisiones que todavía no tienen ninguno.
INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id)
SELECT co.id, h.dia::sga.dia_semana, h.inicio::time, h.fin::time, a.id
FROM (VALUES
    ('93.58', 'A', 'LUNES',     '09:00', '12:00', 'SEDE-DM', '304'),
    ('93.58', 'B', 'MARTES',    '09:00', '12:00', 'SEDE-PT', '108'),
    ('72.31', 'A', 'MIERCOLES', '11:30', '14:30', 'SEDE-DM', 'LAB-2'),
    ('72.31', 'B', 'JUEVES',    '11:30', '14:30', 'SEDE-DM', 'LAB-2'),
    ('72.40', 'A', 'VIERNES',   '14:00', '17:00', 'SEDE-DM', '101'),
    ('72.40', 'B', 'VIERNES',   '18:00', '21:00', 'SEDE-DM', '101')
) AS h (materia, comision, dia, inicio, fin, edificio, aula)
JOIN sga.materia m   ON m.codigo = h.materia
JOIN sga.curso c     ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = h.comision
JOIN sga.edificio e  ON e.codigo = h.edificio
JOIN sga.aula a      ON a.edificio_id = e.id AND a.codigo = h.aula
WHERE NOT EXISTS (
    SELECT 1 FROM sga.horario_comision hc WHERE hc.comision_id = co.id
);

COMMIT;

SELECT
    (SELECT count(*) FROM sga.materia)          AS materias,
    (SELECT count(*) FROM sga.aula)             AS aulas,
    (SELECT count(*) FROM sga.curso)            AS cursos,
    (SELECT count(*) FROM sga.comision)         AS comisiones,
    (SELECT count(*) FROM sga.horario_comision) AS horarios;
