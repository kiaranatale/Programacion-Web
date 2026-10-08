-- =====================================================================
-- Plan P22 de Ingeniería en Petróleo, transcripto del "Detalle de Planes de
-- estudio" del SGA actual. Correr DESPUÉS de seed.sql (como
-- seed_plan_a22.sql).
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
SELECT id, 'P22', 1, 240, DATE '2023-03-01', DATE '2024-02-01'
FROM sga.carrera WHERE codigo = 'P'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE p22_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'P' AND p.codigo = 'P22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM p22_plan p
CROSS JOIN (VALUES
    ('PLAN P22',             'APROBAR_TODOS',   240, 1),
    ('ELECTIVAS GENERALES',  'JUNTAR_CREDITOS',  13, 2),
    ('ELECTIVAS PETRÓLEO',   'JUNTAR_CREDITOS',  24, 3)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE p22_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO p22_materias VALUES
    -- PLAN P22
    ('PLAN P22', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('PLAN P22', '71.58', 'Informática General', 3, 0, 1, 1, ''),
    ('PLAN P22', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('PLAN P22', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('PLAN P22', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('PLAN P22', '12.34', 'Química Orgánica para Petroleo', 6, 0, 1, 2, '12.67'),
    ('PLAN P22', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('PLAN P22', '46.01', 'Introducción a la Ingeniería en Petróleo', 3, 0, 1, 2, ''),
    ('PLAN P22', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('PLAN P22', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('PLAN P22', '71.59', 'Estructura de Datos y Programación', 6, 0, 2, 1, '71.58'),
    ('PLAN P22', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('PLAN P22', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 1, '92.02'),
    ('PLAN P22', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('PLAN P22', '16.55', 'Biología', 3, 0, 2, 2, '94.33'),
    ('PLAN P22', '31.19', 'Estática y Resistencia de Materiales', 6, 0, 2, 2, '92.03 31.08'),
    ('PLAN P22', '46.21', 'Geología I', 3, 0, 2, 2, '46.01 93.42'),
    ('PLAN P22', '92.05', 'Análisis Matemático IV', 4, 0, 2, 2, '92.02 92.03'),
    ('PLAN P22', '93.07', 'Métodos Numéricos', 3, 0, 2, 2, '92.03'),
    ('PLAN P22', '93.43', 'Física III', 6, 0, 2, 2, '92.03 93.41'),
    ('PLAN P22', '21.06', 'Electrotecnia', 3, 0, 3, 1, '93.43'),
    ('PLAN P22', '31.21', 'Termodinámica', 6, 0, 3, 1, '93.42'),
    ('PLAN P22', '31.22', 'Mecánica de Fluidos', 6, 0, 3, 1, '92.03'),
    ('PLAN P22', '46.22', 'Geofísica de Reservorios', 3, 0, 3, 1, '46.21'),
    ('PLAN P22', '93.61', 'Física IV', 4, 0, 3, 1, '93.43'),
    ('PLAN P22', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, ''),
    ('PLAN P22', '11.15', 'Organización Industrial', 3, 0, 3, 2, '93.24'),
    ('PLAN P22', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 0, 3, 2, '12.34 16.55'),
    ('PLAN P22', '21.09', 'Máquinas Eléctricas', 3, 0, 3, 2, '21.06'),
    ('PLAN P22', '30.70', 'Introducción a Mecánica de Rocas', 3, 0, 3, 2, '31.19'),
    ('PLAN P22', '46.41', 'Petrofísica y Fluidos de Reservorio', 6, 0, 3, 2, '31.21 31.22 46.21'),
    ('PLAN P22', '46.61', 'Ingeniería de Perforación I', 3, 0, 3, 2, '46.21 31.19'),
    ('PLAN P22', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('PLAN P22', '94.51', 'Inglés I', 0, 0, 3, 2, ''),
    ('PLAN P22', '46.23', 'Geología II', 3, 0, 4, 1, '46.22 46.41'),
    ('PLAN P22', '46.42', 'Registros de Pozo I', 6, 0, 4, 1, '93.61 46.41'),
    ('PLAN P22', '46.44', 'Análisis de Transientes de Presión', 3, 0, 4, 1, '30.70 92.05 46.41'),
    ('PLAN P22', '46.46', 'Ingeniería de Reservorios', 6, 0, 4, 1, '46.41'),
    ('PLAN P22', '46.63', 'Ingeniería de Workover I', 3, 0, 4, 1, '46.61'),
    ('PLAN P22', '46.65', 'Instalaciones de Superficie', 3, 0, 4, 1, '31.21 12.34 46.41'),
    ('PLAN P22', '71.90', 'Certificaciones tecnológicas', 0, 0, 4, 1, ''),
    ('PLAN P22', '46.66', 'Gas y Gasolina Natural', 3, 0, 4, 2, '46.65'),
    ('PLAN P22', '46.67', 'Ingeniería de Producción I', 6, 0, 4, 2, '46.65 46.41 21.09'),
    ('PLAN P22', '46.81', 'Gestión Ambiental en la Industria', 3, 0, 4, 2, '12.83'),
    ('PLAN P22', '46.82', 'Evaluación de Proyectos', 3, 0, 4, 2, '46.46'),
    ('PLAN P22', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 2, '11.15'),
    ('PLAN P22', '94.52', 'Inglés II', 0, 0, 4, 2, '94.51'),
    ('PLAN P22', '46.69', 'Transporte y Cadena de Valor de los Hidrocarburos', 3, 0, 5, 1, '46.66 46.67'),
    ('PLAN P22', '46.83', 'Desarrollo de Yacimientos', 3, 0, 5, 1, '46.23 46.66 46.82 46.67 46.42'),
    ('PLAN P22', '61.16', 'Introducción a las Finanzas', 3, 0, 5, 1, '61.27'),
    ('PLAN P22', '61.31', 'Derecho para Ingenieros', 3, 0, 5, 1, ''),
    ('PLAN P22', '46.02', 'Práctica de Campo I', 0, 72, 5, 2, '46.21 46.41 46.67'),
    ('PLAN P22', '46.03', 'Práctica de Campo II', 0, 144, 5, 2, '46.02 46.63 46.46'),
    ('PLAN P22', '46.70', 'Industrialización y Economía de los Hidrocarburos', 3, 0, 5, 2, '46.69'),
    -- ELECTIVAS GENERALES
    ('ELECTIVAS GENERALES', '10.08', 'Energías Renovables', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '11.10', 'Organización de la Producción I', 6, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '11.58', 'Dinámica de Sistemas', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '11.84', 'Gestión de Proyectos', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '12.02', 'Química II', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '15.06', 'Storytelling aplicado a los negocios', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '15.79', 'Metodología de la Investigación', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '17.09', 'Industrias Químicas', 3, 0, NULL, NULL, '31.21'),
    ('ELECTIVAS GENERALES', '17.15', 'Introducción a la Ingeniería Ambiental', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '17.22', 'Cálculo de Huella de Carbono en Organizaciones', 1, 144, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '17.23', 'Triple Impacto: Estrategias para el Desarrollo Sostenible', 3, 144, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '30.24', 'Metalurgia Física I', 4, 0, NULL, NULL, '47.84'),
    ('ELECTIVAS GENERALES', '31.30', 'Materiales Poliméricos', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '48.01', 'Oil & Gas Investment and Economics', 1, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '48.02', 'AI: Data Management Course & Digital Transformation', 1, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '48.03', 'Negociación - Contratos Oil & Gas', 1, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '61.10', 'Economía Internacional', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '61.50', 'Finanzas de la Empresa', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '71.22', 'Sistemas de Inteligencia Artificial', 3, 0, NULL, NULL, '71.88'),
    ('ELECTIVAS GENERALES', '71.56', 'Programación Básica', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '71.88', 'Gestión de Datos', 6, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS GENERALES', '92.06', 'Análisis Matemático V', 6, 96, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '92.92', 'Complementos de Física de la Relatividad', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '92.99', 'Complementos de Análisis Matemático IV', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '94.23', 'Formación General III', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS GENERALES', '94.24', 'Metodología del Aprendizaje', 3, 0, NULL, NULL, ''),
    -- ELECTIVAS PETRÓLEO
    ('ELECTIVAS PETRÓLEO', '17.08', 'Seguridad de Procesos', 3, 144, NULL, NULL, ''),
    ('ELECTIVAS PETRÓLEO', '47.24', 'Geoestadística', 3, 0, NULL, NULL, '46.22 93.07'),
    ('ELECTIVAS PETRÓLEO', '47.43', 'Registros de Pozo II', 3, 0, NULL, NULL, '46.42'),
    ('ELECTIVAS PETRÓLEO', '47.45', 'Análisis de Transientes de Caudal', 3, 0, NULL, NULL, '46.44'),
    ('ELECTIVAS PETRÓLEO', '47.47', 'Recuperación Asistida de Petróleo', 6, 0, NULL, NULL, '46.46'),
    ('ELECTIVAS PETRÓLEO', '47.48', 'Simulación de Reservorios', 3, 0, NULL, NULL, '46.23 46.46'),
    ('ELECTIVAS PETRÓLEO', '47.49', 'Recursos y Reservas', 3, 0, NULL, NULL, '46.46 46.82'),
    ('ELECTIVAS PETRÓLEO', '47.62', 'Ingeniería de Perforación II', 6, 0, NULL, NULL, '46.61'),
    ('ELECTIVAS PETRÓLEO', '47.64', 'Ingeniería de Workover II', 3, 0, NULL, NULL, '46.63'),
    ('ELECTIVAS PETRÓLEO', '47.68', 'Ingeniería de Producción II', 6, 0, NULL, NULL, '46.67'),
    ('ELECTIVAS PETRÓLEO', '47.71', 'Fluidos de Perforación', 3, 0, NULL, NULL, '47.62'),
    ('ELECTIVAS PETRÓLEO', '47.72', 'Geomecánica y Diseño de Fracturas', 3, 0, NULL, NULL, '47.64'),
    ('ELECTIVAS PETRÓLEO', '47.73', 'Operaciones Offshore - Petróleo y LNG', 3, 72, NULL, NULL, ''),
    ('ELECTIVAS PETRÓLEO', '47.84', 'Ciencia de los Materiales', 3, 0, NULL, NULL, '31.19'),
    ('ELECTIVAS PETRÓLEO', '47.85', 'Trabajo de Investigación', 3, 0, NULL, NULL, '94.44'),
    ('ELECTIVAS PETRÓLEO', '47.86', 'Transición Energética y Sustentabilidad', 3, 0, NULL, NULL, '46.81'),
    ('ELECTIVAS PETRÓLEO', '47.87', 'Desarrollo de Negocios', 3, 0, NULL, NULL, '46.82'),
    ('ELECTIVAS PETRÓLEO', '47.88', 'Introducción a la Energía Geotermal', 1, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS PETRÓLEO', '47.89', 'Introducción a la Generación de Energía Cerrada', 1, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS PETRÓLEO', '47.90', 'Introducción a la Producción de Litio', 1, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS PETRÓLEO', '48.04', 'El Gas Natural Licuado - Tecnología, Mercados y Negocios', 3, 0, NULL, NULL, '61.27'),
    ('ELECTIVAS PETRÓLEO', '48.05', 'La Cadena de valor del Gas Natural', 3, 0, NULL, NULL, '61.27'),
    ('ELECTIVAS PETRÓLEO', '92.09', 'Complementos de Análisis Matemático IV', 0, 0, NULL, NULL, ''),
    ('ELECTIVAS PETRÓLEO', '92.15', 'Complementos de Física Mecánica', 3, 0, NULL, NULL, '31.19');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM p22_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM p22_materias m
CROSS JOIN p22_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Huecos de electivas en la grilla del plan (los dos en 5.º año, 2.º cuat.)
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 5, 2, h.creditos
FROM p22_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id
JOIN (VALUES
    ('ELECTIVAS GENERALES', 13),
    ('ELECTIVAS PETRÓLEO',  24)
) AS h (bloque, creditos) ON h.bloque = b.nombre
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM p22_materias m
CROSS JOIN p22_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Ingeniero/a en Petróleo', 'Aprobar P22 y sumar 240 créditos'
FROM p22_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: el bloque PLAN P22 debe sumar 240 créditos (materias + huecos)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'P22') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'P22' AND b.nombre = 'PLAN P22')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'P22') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'P22') AS correlativas;
