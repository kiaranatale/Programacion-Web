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
    ('Escuela de Gestión y Tecnología')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.departamento (nombre) VALUES
    ('Ciencias Exactas y Naturales'),
    ('Sistemas Digitales y Datos')
ON CONFLICT (nombre) DO NOTHING;

-- Bases cargadas con una versión anterior de este seed: Informática tenía
-- el código inventado 'INF' y una escuela inexistente.
UPDATE sga.carrera c
SET codigo = 'S', escuela_id = e.id
FROM sga.escuela e
WHERE c.codigo = 'INF' AND e.nombre = 'Escuela de Gestión y Tecnología';

DELETE FROM sga.escuela e
WHERE e.nombre = 'Escuela de Ingeniería y Tecnología'
  AND NOT EXISTS (SELECT 1 FROM sga.carrera c WHERE c.escuela_id = e.id);

-- Carreras de grado del SGA actual (Académica → Carreras)
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id, nivel, nivel_informatico)
SELECT x.codigo, x.nombre, e.id, 'GRADO', 'Grado'
FROM (VALUES
    ('BIO',  'Bioingeniería'),
    ('AER',  'Ingeniería Aeroespacial'),
    ('C',    'Ingeniería Civil'),
    ('E',    'Ingeniería Electricista'),
    ('K',    'Ingeniería Electrónica'),
    ('B',    'Ingeniería en Biotecnología'),
    ('S',    'Ingeniería en Informática'),
    ('P',    'Ingeniería en Petróleo'),
    ('I',    'Ingeniería Industrial'),
    ('M',    'Ingeniería Mecánica'),
    ('N',    'Ingeniería Naval'),
    ('Q',    'Ingeniería Química'),
    ('X',    'Intercambio'),
    ('L',    'Lic. en Administración y Sistemas'),
    ('LAES', 'Licenciatura en Analítica Empresarial y Social'),
    ('LCA',  'Licenciatura en Ciencias Aplicadas'),
    ('LCC',  'Licenciatura en Ciencias del Comportamiento'),
    ('LN',   'Licenciatura en Gestión de Negocios')
) AS x (codigo, nombre)
JOIN sga.escuela e ON e.nombre = 'Escuela de Gestión y Tecnología'
ON CONFLICT (codigo) DO NOTHING;

UPDATE sga.carrera SET nivel_informatico = 'Grado'
WHERE nivel = 'GRADO' AND nivel_informatico IS NULL;

-- Bases cargadas con una versión anterior de este seed: las materias
-- tenían códigos inventados. Se renombran a las reales del plan A22, así
-- sus cursos y cursadas se conservan.
UPDATE sga.materia m
SET codigo = x.nuevo, nombre = x.nombre, creditos = x.creditos
FROM (VALUES
    ('93.58', '93.20', 'Análisis Matemático',                6),
    ('93.59', '93.21', 'Álgebra',                            6),
    ('72.31', '71.45', 'Estructura de Datos y Programación', 6),
    ('72.40', '71.38', 'Programación web',                   3)
) AS x (viejo, nuevo, nombre, creditos)
WHERE m.codigo = x.viejo
  AND NOT EXISTS (SELECT 1 FROM sga.materia y WHERE y.codigo = x.nuevo);

-- El plan inventado INF-2023 se reemplaza por el plan real A22 de LAES
-- (seed_plan_a22.sql). Se borra solo si ningún legajo lo usa.
DELETE FROM sga.plan_materia pm
USING sga.plan_estudio p
WHERE pm.plan_id = p.id AND p.codigo = 'INF-2023'
  AND NOT EXISTS (SELECT 1 FROM sga.legajo l WHERE l.plan_estudio_id = p.id);
DELETE FROM sga.plan_estudio p
WHERE p.codigo = 'INF-2023'
  AND NOT EXISTS (SELECT 1 FROM sga.legajo l WHERE l.plan_estudio_id = p.id);

-- Materias con cursos en el cuatrimestre actual (el resto del plan A22
-- se carga en seed_plan_a22.sql)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM (VALUES
    ('93.20', 'Análisis Matemático',                'Ciencias Exactas y Naturales', 6),
    ('93.21', 'Álgebra',                            'Ciencias Exactas y Naturales', 6),
    ('71.45', 'Estructura de Datos y Programación', 'Sistemas Digitales y Datos',   6),
    ('71.38', 'Programación web',                   'Sistemas Digitales y Datos',   3)
) AS m (codigo, nombre, departamento, creditos)
JOIN sga.departamento d ON d.nombre = m.departamento
ON CONFLICT (codigo) DO NOTHING;

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

-- Cursos del cuatrimestre con las fechas reales del SGA actual (versiones
-- anteriores de este seed usaban 10/08 al 04/12)
UPDATE sga.curso c
SET fecha_inicio = DATE '2026-07-26', fecha_fin = DATE '2026-12-31'
FROM sga.materia m
WHERE m.id = c.materia_id AND m.codigo IN ('93.20', '71.45', '71.38')
  AND c.anio = 2026 AND c.periodo = '2C' AND c.fecha_inicio = DATE '2026-08-10';

INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, '2C', DATE '2026-07-26', DATE '2026-12-31'
FROM sga.materia WHERE codigo IN ('93.20', '71.45', '71.38')
ON CONFLICT (materia_id, anio, periodo, fecha_inicio) DO NOTHING;

INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, x.nombre, x.cupo
FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id
CROSS JOIN (VALUES ('A', 40), ('B', 30)) AS x (nombre, cupo)
WHERE c.anio = 2026 AND c.periodo = '2C'
  AND m.codigo IN ('93.20', '71.45', '71.38')
ON CONFLICT (curso_id, nombre) DO NOTHING;

-- horario_comision no tiene clave única: solo se cargan horarios para
-- las comisiones que todavía no tienen ninguno.
INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id)
SELECT co.id, h.dia::sga.dia_semana, h.inicio::time, h.fin::time, a.id
FROM (VALUES
    ('93.20', 'A', 'LUNES',     '09:00', '12:00', 'SEDE-DM', '304'),
    ('93.20', 'B', 'MARTES',    '09:00', '12:00', 'SEDE-PT', '108'),
    ('71.45', 'A', 'MIERCOLES', '11:30', '14:30', 'SEDE-DM', 'LAB-2'),
    ('71.45', 'B', 'JUEVES',    '11:30', '14:30', 'SEDE-DM', 'LAB-2'),
    ('71.38', 'A', 'VIERNES',   '14:00', '17:00', 'SEDE-DM', '101'),
    ('71.38', 'B', 'VIERNES',   '18:00', '21:00', 'SEDE-DM', '101')
) AS h (materia, comision, dia, inicio, fin, edificio, aula)
JOIN sga.materia m   ON m.codigo = h.materia
JOIN sga.curso c     ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = h.comision
JOIN sga.edificio e  ON e.codigo = h.edificio
JOIN sga.aula a      ON a.edificio_id = e.id AND a.codigo = h.aula
WHERE NOT EXISTS (
    SELECT 1 FROM sga.horario_comision hc WHERE hc.comision_id = co.id
);

-- Eventos y exámenes de la semana del 5/10/2026, para ver todos los colores
-- de Ocupación de Aulas: un examen (lunes), un evento (lunes) y un evento
-- superpuesto con la clase de 71.38 en el Aula 101 (viernes).
INSERT INTO sga.evento_academico (nombre, tipo, fecha, hora_inicio, hora_fin, aula_id)
SELECT x.nombre, x.tipo, x.fecha, x.inicio::time, x.fin::time, a.id
FROM (VALUES
    ('Jornada de orientación vocacional', 'Jornada', DATE '2026-10-05', '18:00', '20:00', 'SEDE-PT', '108'),
    ('Charla de bienvenida a ingresantes', 'Charla', DATE '2026-10-09', '15:00', '16:00', 'SEDE-DM', '101')
) AS x (nombre, tipo, fecha, inicio, fin, edificio, aula)
JOIN sga.edificio e ON e.codigo = x.edificio
JOIN sga.aula a ON a.edificio_id = e.id AND a.codigo = x.aula
WHERE NOT EXISTS (
    SELECT 1 FROM sga.evento_academico ev WHERE ev.nombre = x.nombre AND ev.fecha = x.fecha
);

INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin, aula_id)
SELECT c.id, DATE '2026-10-05', '13:00', '15:00', a.id
FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id AND m.codigo = '93.20'
JOIN sga.edificio e ON e.codigo = 'SEDE-DM'
JOIN sga.aula a ON a.edificio_id = e.id AND a.codigo = '304'
WHERE c.anio = 2026 AND c.periodo = '2C'
  AND NOT EXISTS (
      SELECT 1 FROM sga.examen_final ef WHERE ef.curso_id = c.id AND ef.fecha = DATE '2026-10-05'
  );

COMMIT;

SELECT
    (SELECT count(*) FROM sga.materia)          AS materias,
    (SELECT count(*) FROM sga.aula)             AS aulas,
    (SELECT count(*) FROM sga.curso)            AS cursos,
    (SELECT count(*) FROM sga.comision)         AS comisiones,
    (SELECT count(*) FROM sga.horario_comision) AS horarios;
