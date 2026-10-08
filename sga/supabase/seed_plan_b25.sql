-- =====================================================================
-- Plan B 25 de Ingeniería en Biotecnología, transcripto del "Detalle de Planes de
-- estudio" del SGA actual. Correr DESPUÉS de seed.sql (como
-- seed_plan_a22.sql).
--
-- El bloque Electivas (juntar 60 créditos) todavía no tiene materias en
-- el SGA: solo figura el hueco de 60 créditos en 5.º año.
--
-- Los departamentos de cada materia no figuran en el detalle del plan:
-- las materias nuevas quedan en "A confirmar" hasta tener ese dato.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.departamento (nombre) VALUES ('A confirmar')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.plan_estudio (carrera_id, codigo, version, creditos_totales, vigencia_desde, vigencia_hasta)
SELECT id, 'B 25', 1, 240, DATE '2025-03-01', NULL
FROM sga.carrera WHERE codigo = 'B'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE b25_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'B' AND p.codigo = 'B 25';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM b25_plan p
CROSS JOIN (VALUES
    ('Ciclo Básico',      'APROBAR_TODOS',   144, 1),
    ('Ciclo Profesional', 'APROBAR_TODOS',    96, 2),
    ('Electivas',         'JUNTAR_CREDITOS',  60, 3)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE b25_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO b25_materias VALUES
    -- Ciclo Básico
    ('Ciclo Básico', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '71.58', 'Informática General', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '13.02', 'Fundamentos de Química Orgánica', 6, 0, 1, 2, '12.67'),
    ('Ciclo Básico', '16.55', 'Biología', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '18.01', 'Introducción a la Biotecnología', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('Ciclo Básico', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('Ciclo Básico', '94.51', 'Inglés I', 0, 0, 1, 2, ''),
    ('Ciclo Básico', '12.19', 'Química Analítica', 6, 0, 2, 1, '92.01 93.41 12.67'),
    ('Ciclo Básico', '17.03', 'Bioquímica y Microbiología Aplicadas', 5, 0, 2, 1, '13.02 16.55'),
    ('Ciclo Básico', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('Ciclo Básico', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('Ciclo Básico', '12.20', 'Química-Física', 6, 0, 2, 2, '92.03'),
    ('Ciclo Básico', '16.01', 'Biología Molecular y Celular', 6, 0, 2, 2, '16.55 12.19'),
    ('Ciclo Básico', '92.05', 'Análisis Matemático IV', 4, 0, 2, 2, '92.02 92.03'),
    ('Ciclo Básico', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 2, '92.02'),
    ('Ciclo Básico', '94.52', 'Inglés II', 0, 0, 2, 2, '94.51'),
    ('Ciclo Básico', '12.26', 'Termodinámica', 6, 0, 3, 1, '12.20'),
    ('Ciclo Básico', '17.04', 'Fenómenos de Transporte', 6, 0, 3, 1, '12.20'),
    ('Ciclo Básico', '18.02', 'Fisiología y Genética de Microorganismos', 6, 0, 3, 1, '17.03 16.01'),
    ('Ciclo Básico', '93.54', 'Métodos Numéricos', 3, 0, 3, 1, '92.03'),
    ('Ciclo Básico', '94.43', 'Metodología del Diseño', 3, 96, 3, 1, ''),
    ('Ciclo Básico', '11.15', 'Organización Industrial', 3, 0, 3, 2, '93.24'),
    ('Ciclo Básico', '12.11', 'Operaciones Unitarias I', 6, 0, 3, 2, '17.04 12.26'),
    ('Ciclo Básico', '18.03', 'Bioprocesos', 6, 0, 3, 2, '18.02 17.04 12.26'),
    ('Ciclo Básico', '25.23', 'Sistemas de Control', 6, 0, 3, 2, '71.58 93.42 92.05 12.26'),
    ('Ciclo Básico', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    -- Ciclo Profesional
    ('Ciclo Profesional', '15.88', 'Calidad de Organizaciones', 3, 0, 4, 1, '11.15'),
    ('Ciclo Profesional', '18.04', 'Separaciones Biotecnológicas', 4, 0, 4, 1, '17.03 16.01'),
    ('Ciclo Profesional', '18.05', 'Biodepuraciones y biorremediación', 4, 0, 4, 1, '18.02'),
    ('Ciclo Profesional', '18.06', 'Ingeniería Genética', 4, 0, 4, 1, '18.02 16.01'),
    ('Ciclo Profesional', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 1, '93.24'),
    ('Ciclo Profesional', '61.31', 'Derecho para Ingenieros', 3, 144, 4, 1, ''),
    ('Ciclo Profesional', '11.84', 'Gestión de Proyectos', 3, 0, 4, 2, ''),
    ('Ciclo Profesional', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 0, 4, 2, '11.15'),
    ('Ciclo Profesional', '61.16', 'Introducción a las Finanzas', 3, 0, 4, 2, '11.15 61.27'),
    ('Ciclo Profesional', '18.07', 'Proyecto final de carrera (Anual)', 6, 192, 5, 1, ''),
    ('Ciclo Profesional', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, '');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM b25_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM b25_materias m
CROSS JOIN b25_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 5, 2, 60
FROM b25_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'Electivas'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM b25_materias m
CROSS JOIN b25_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Ingeniero/a en Biotecnología', 'Aprobar B 25 y sumar 240 créditos'
FROM b25_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: los dos ciclos deben sumar 240 créditos (materias + hueco)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'B 25') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'B 25' AND b.requisito = 'APROBAR_TODOS')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'B 25') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'B 25') AS correlativas;
