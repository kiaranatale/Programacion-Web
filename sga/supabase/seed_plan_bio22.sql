-- =====================================================================
-- Plan BIO 22 de Bioingeniería, transcripto del "Detalle de Planes de
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
SELECT id, 'BIO 22', 1, 240, DATE '2023-03-01', DATE '2024-02-01'
FROM sga.carrera WHERE codigo = 'BIO'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE bio22_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'BIO' AND p.codigo = 'BIO 22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM bio22_plan p
CROSS JOIN (VALUES
    ('PLAN BIO22', 'APROBAR_TODOS',   240, 1),
    ('ELECTIVAS',  'JUNTAR_CREDITOS',  48, 2)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE bio22_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO bio22_materias VALUES
    -- PLAN BIO22
    ('PLAN BIO22', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('PLAN BIO22', '71.58', 'Informática General', 3, 0, 1, 1, ''),
    ('PLAN BIO22', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('PLAN BIO22', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('PLAN BIO22', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('PLAN BIO22', '13.02', 'Fundamentos de Química Orgánica', 6, 0, 1, 2, '12.67'),
    ('PLAN BIO22', '16.55', 'Biología', 3, 0, 1, 2, ''),
    ('PLAN BIO22', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('PLAN BIO22', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('PLAN BIO22', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('PLAN BIO22', '94.51', 'Inglés I', 0, 0, 1, 2, ''),
    ('PLAN BIO22', '16.01', 'Biología Molecular y Celular', 6, 0, 2, 1, '13.02 16.55'),
    ('PLAN BIO22', '71.59', 'Estructura de Datos y Programación', 6, 0, 2, 1, '71.58'),
    ('PLAN BIO22', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('PLAN BIO22', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('PLAN BIO22', '16.02', 'Histología y Anatomía', 6, 0, 2, 2, '16.01'),
    ('PLAN BIO22', '92.04', 'Análisis Matemático IV', 6, 0, 2, 2, '92.02 92.03'),
    ('PLAN BIO22', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 2, '92.02'),
    ('PLAN BIO22', '93.43', 'Física III', 6, 0, 2, 2, '92.03 93.41'),
    ('PLAN BIO22', '94.52', 'Inglés II', 0, 0, 2, 2, '94.51'),
    ('PLAN BIO22', '16.03', 'Fisiología', 6, 0, 3, 1, '16.02'),
    ('PLAN BIO22', '16.64', 'Mecánica de biomateriales y tejidos', 8, 0, 3, 1, '16.02 93.41'),
    ('PLAN BIO22', '21.06', 'Electrotecnia', 3, 0, 3, 1, '93.43'),
    ('PLAN BIO22', '93.61', 'Física IV', 4, 0, 3, 1, '93.42 93.43'),
    ('PLAN BIO22', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, ''),
    ('PLAN BIO22', '16.24', 'Ingeniería de Rehabilitación', 3, 0, 3, 2, '16.03'),
    ('PLAN BIO22', '16.44', 'Física Médica', 3, 0, 3, 2, '93.61'),
    ('PLAN BIO22', '16.68', 'Señales y Sistemas', 6, 0, 3, 2, '92.04'),
    ('PLAN BIO22', '23.02', 'Electrónica Analógica y Digital', 6, 0, 3, 2, '71.59 21.06 92.04'),
    ('PLAN BIO22', '93.54', 'Métodos Numéricos', 3, 0, 3, 2, '71.59 92.03'),
    ('PLAN BIO22', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('PLAN BIO22', '11.15', 'Organización Industrial', 3, 0, 4, 1, '93.24'),
    ('PLAN BIO22', '16.17', 'Instrumentación Biomédica I', 6, 0, 4, 1, '16.68 23.02'),
    ('PLAN BIO22', '16.63', 'Procesamiento de Señales e Imágenes Biomédicas', 6, 0, 4, 1, '16.68'),
    ('PLAN BIO22', '23.16', 'Sistemas de Control', 3, 0, 4, 1, '16.68'),
    ('PLAN BIO22', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 1, '93.24'),
    ('PLAN BIO22', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 0, 4, 2, '21.06'),
    ('PLAN BIO22', '16.18', 'Instrumentación Biomédica II', 6, 0, 4, 2, '16.17'),
    ('PLAN BIO22', '16.25', 'Ingeniería Clínica', 6, 0, 4, 2, '16.17'),
    ('PLAN BIO22', '61.16', 'Introducción a las Finanzas', 3, 0, 4, 2, '11.15 61.27'),
    ('PLAN BIO22', '61.31', 'Derecho para Ingenieros', 3, 120, 4, 2, ''),
    ('PLAN BIO22', '16.30', 'Proyecto Final de Carrera (Anual)', 6, 192, 5, 1, '16.63'),
    ('PLAN BIO22', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, ''),
    -- ELECTIVAS
    ('ELECTIVAS', '10.07', 'Creatividad', 3, 120, NULL, NULL, ''),
    ('ELECTIVAS', '10.08', 'Energías Renovables', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '10.09', 'Formación para Emprendedores', 3, 144, NULL, NULL, ''),
    ('ELECTIVAS', '11.19', 'Prototipado e Impresión 3D', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '11.76', 'Gestión de Calidad', 3, 0, NULL, NULL, '11.15'),
    ('ELECTIVAS', '14.72', 'Analytics', 1, 72, NULL, NULL, ''),
    ('ELECTIVAS', '15.13', 'Innovación en materiales Biobasados', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '16.04', 'Neurociencias y Desarrollo Productivo', 3, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.09', 'Ventilación Mecánica', 3, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.14', 'Fisiología Cuantitativa', 6, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.19', 'Biosensores', 3, 0, NULL, NULL, '23.02'),
    ('ELECTIVAS', '16.20', 'Biomedicina Estructural y Computacional', 6, 0, NULL, NULL, '71.59 16.01'),
    ('ELECTIVAS', '16.21', 'Bioinformática', 6, 0, NULL, NULL, '71.59 16.01'),
    ('ELECTIVAS', '16.22', 'Informática Médica', 6, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '16.23', 'Órganos Artificiales', 6, 0, NULL, NULL, '16.03 23.02 16.64'),
    ('ELECTIVAS', '16.27', 'Ingeniería de Tejidos', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.29', 'Diseño de Fármacos', 3, 0, NULL, NULL, '16.20 16.01'),
    ('ELECTIVAS', '16.32', 'Redes Neuronales en Bioingeniería', 3, 0, NULL, NULL, '93.24'),
    ('ELECTIVAS', '16.43', 'Bioestadística', 3, 0, NULL, NULL, '93.24'),
    ('ELECTIVAS', '16.45', 'Edición Genética', 1, 0, NULL, NULL, '16.55'),
    ('ELECTIVAS', '16.46', 'Reprogramación celular y epigenética', 1, 0, NULL, NULL, '16.55'),
    ('ELECTIVAS', '16.51', 'Int. a la Ciencia de Datos Aplicados a la Salud', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '16.52', 'Inmunología Biológica', 3, 0, NULL, NULL, '16.03 16.01'),
    ('ELECTIVAS', '16.53', 'Biotecnología aplicada', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.54', 'Regulaciones Biomédicas', 3, 0, NULL, NULL, '16.25'),
    ('ELECTIVAS', '16.57', 'Robótica Bioinspirada', 3, 0, NULL, NULL, '23.16'),
    ('ELECTIVAS', '16.58', 'Biomecánica del Deporte', 3, 0, NULL, NULL, '16.63 16.64'),
    ('ELECTIVAS', '16.59', 'Microfluídica', 1, 0, NULL, NULL, '93.41'),
    ('ELECTIVAS', '16.65', 'Genética del Comportamiento', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.66', 'Reprogramación Celular', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.67', 'Inmunología Biológica y Evasión Inmune', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.69', 'Nanotecnología en Medicina y Cuidado de la Salud', 3, 0, NULL, NULL, '16.01'),
    ('ELECTIVAS', '16.71', 'Ingeniería del Cerebro y el Comportamiento', 3, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.72', 'Análisis y Tratamiento de Imágenes', 3, 0, NULL, NULL, '16.63'),
    ('ELECTIVAS', '16.73', 'Sistemas de Imágenes en Diagnóstico Médico', 3, 0, NULL, NULL, '16.63'),
    ('ELECTIVAS', '16.74', 'Interfaces Cerebro Computadora y Neurorobótica', 3, 0, NULL, NULL, '16.63'),
    ('ELECTIVAS', '16.75', 'Gestión de Procesos Hospitalarios', 3, 0, NULL, NULL, '16.25'),
    ('ELECTIVAS', '16.76', 'Bases Fisicomatemáticas de la Biomecánica del Deporte', 1, 0, NULL, NULL, '16.64'),
    ('ELECTIVAS', '16.77', 'Tecnologías emergentes en plantas con aplicaciones terapéuticas', 1, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.78', 'Enfermedades del Sistema Nervioso: Implicancias e innovaciones', 1, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.79', 'Neurociencias', 3, 0, NULL, NULL, '16.03 93.43'),
    ('ELECTIVAS', '16.80', 'Microfluídica', 3, 0, NULL, NULL, '23.02 16.64'),
    ('ELECTIVAS', '16.81', 'Neurobiología del Aprendizaje y Control del Movimiento', 3, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.82', 'Neurociencia Computacional', 3, 0, NULL, NULL, '71.59 92.03 93.24'),
    ('ELECTIVAS', '16.83', 'Introducción a cultivos celulares derivados de tejido nervioso', 1, 0, NULL, NULL, '16.55'),
    ('ELECTIVAS', '16.84', 'Informática en Salud', 3, 0, NULL, NULL, '16.02 16.03'),
    ('ELECTIVAS', '16.85', 'Procesamiento Avanzado de Imágenes en Biología y Biomedicina', 3, 0, NULL, NULL, '16.63'),
    ('ELECTIVAS', '16.87', 'Microfabricación', 1, 0, NULL, NULL, '16.01 92.04 93.61'),
    ('ELECTIVAS', '16.88', 'Avances Tecnol. para el estudio del SNC en mod. animales', 1, 0, NULL, NULL, '16.63 16.03'),
    ('ELECTIVAS', '16.89', 'Laboratorio de Neurobiología de la Memoria', 1, 0, NULL, NULL, '16.79'),
    ('ELECTIVAS', '16.90', 'Laboratorio de Inmunología Biológica', 1, 0, NULL, NULL, '16.52'),
    ('ELECTIVAS', '16.91', 'Sistemas Embebidos: Aplicaciones en Biomedicina', 1, 0, NULL, NULL, '71.59 23.02'),
    ('ELECTIVAS', '16.92', 'Nanocarriers biológicos: vesículas extracelulares y su potencial biotecnológico', 1, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.93', 'Análisis crítico de evidencia en bioingeniería', 1, 0, NULL, NULL, '16.03'),
    ('ELECTIVAS', '16.94', 'Biomimética', 1, 0, NULL, NULL, '16.55'),
    ('ELECTIVAS', '16.95', 'Startups basadas en ciencia', 1, 144, NULL, NULL, ''),
    ('ELECTIVAS', '16.96', 'Laboratorio de Bioimpresión', 1, 0, NULL, NULL, '16.64'),
    ('ELECTIVAS', '16.97', 'Modelado en mecánica cardiovascular', 3, 0, NULL, NULL, '16.03 16.64'),
    ('ELECTIVAS', '16.98', 'Glicobiología Funcional', 3, 0, NULL, NULL, '12.67 16.01'),
    ('ELECTIVAS', '17.15', 'Introducción a la Ingeniería Ambiental', 3, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS', '17.16', 'Introducción a la Nanotecnología', 3, 0, NULL, NULL, '93.42 16.64'),
    ('ELECTIVAS', '22.57', 'Microprocesadores y Control', 6, 0, NULL, NULL, '23.02'),
    ('ELECTIVAS', '22.94', 'Control Discreto', 6, 0, NULL, NULL, '22.57'),
    ('ELECTIVAS', '23.05', 'Acústica para Ingenieros', 3, 0, NULL, NULL, '92.04'),
    ('ELECTIVAS', '23.08', 'Control Avanzado', 3, 0, NULL, NULL, '23.16'),
    ('ELECTIVAS', '23.15', 'Realidad Virtual', 3, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '25.88', 'Redes Neuronales III', 3, 0, NULL, NULL, '16.32'),
    ('ELECTIVAS', '30.41', 'Diseño Mecánico I', 6, 0, NULL, NULL, '93.41 16.64 31.08'),
    ('ELECTIVAS', '30.63', 'Cadenas de Valor Circulares', 3, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS', '30.64', 'Bioenergía', 2, 0, NULL, NULL, '12.83'),
    ('ELECTIVAS', '31.25', 'Termodinámica', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '61.05', 'Economía de la Salud', 3, 120, NULL, NULL, '61.27'),
    ('ELECTIVAS', '71.22', 'Sistemas de Inteligencia Artificial', 3, 0, NULL, NULL, '71.59 93.24'),
    ('ELECTIVAS', '71.38', 'Programación web', 3, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '71.77', 'Fundamentos de programación y análisis de datos', 1, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '71.88', 'Gestión de Datos', 6, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '71.94', 'Introducción al Diseño de Bases de Datos Relacionales y No-Relacionales', 3, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '72.75', 'Aprendizaje Automático (Machine Learning)', 3, 0, NULL, NULL, '93.24 92.04'),
    ('ELECTIVAS', '72.87', 'Diseño Sonoro para Animación y Videojuegos', 3, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '72.90', 'Internet de las Cosas (IoT)', 3, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '72.96', 'Proyecto de Aplicaciones Móviles', 3, 0, NULL, NULL, '71.38'),
    ('ELECTIVAS', '73.61', 'Neurorobótica', 1, 0, NULL, NULL, '93.54 92.04'),
    ('ELECTIVAS', '73.63', 'Redes Equivariantes', 1, 0, NULL, NULL, '16.32'),
    ('ELECTIVAS', '73.66', 'Procesamiento de Imágenes Satelitales', 1, 0, NULL, NULL, '93.43'),
    ('ELECTIVAS', '73.67', 'Análisis de series de tiempo con Inteligencia Artificial', 1, 0, NULL, NULL, '72.75'),
    ('ELECTIVAS', '73.70', 'Análisis de datos en neurociencias', 3, 144, NULL, NULL, ''),
    ('ELECTIVAS', '74.60', 'Visión por Computadora (Computer Vision)', 3, 0, NULL, NULL, '16.63'),
    ('ELECTIVAS', '74.61', 'Current AI techniques for scientific discovery', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '81.75', 'Fund. del desarrollo de software y análisis de datos en Python', 1, 0, NULL, NULL, '71.59'),
    ('ELECTIVAS', '82.12', 'Análisis de Información Biomédica', 3, 0, NULL, NULL, '81.75'),
    ('ELECTIVAS', '82.19', 'Analítica del Deporte', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.07', 'Análisis Matemático V', 4, 0, NULL, NULL, '92.04'),
    ('ELECTIVAS', '92.08', 'Procesos Estocásticos', 3, 0, NULL, NULL, '93.24'),
    ('ELECTIVAS', '92.09', 'Complementos de Análisis Matemático IV', 0, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.90', 'Complementos de Matemática', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.92', 'Complementos de Física de la Relatividad', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.97', 'Complementos de Matemática V', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '93.75', 'Métodos Numéricos Avanzados', 6, 0, NULL, NULL, '93.54'),
    ('ELECTIVAS', '94.19', 'Comportamiento Organizacional', 3, 0, NULL, NULL, '11.15'),
    ('ELECTIVAS', '94.24', 'Metodología del Aprendizaje', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '94.40', 'Estructura de las Organizaciones', 3, 0, NULL, NULL, '94.19'),
    ('ELECTIVAS', '94.42', 'Comunicación Estratégica', 3, 120, NULL, NULL, '');


-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM bio22_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM bio22_materias m
CROSS JOIN bio22_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 5, 2, 48
FROM bio22_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'ELECTIVAS'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM bio22_materias m
CROSS JOIN bio22_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Bioingeniería', 'Aprobar BIO 22 y sumar 240 créditos'
FROM bio22_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: el bloque PLAN BIO22 debe sumar 240 créditos (materias + huecos)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'BIO 22') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'BIO 22' AND b.nombre = 'PLAN BIO22')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'BIO 22') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'BIO 22') AS correlativas;
