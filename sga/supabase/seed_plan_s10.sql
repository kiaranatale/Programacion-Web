-- =====================================================================
-- Plan S10-Rev23 de Ingeniería en Informática, transcripto del "Detalle de Planes de
-- estudio" del SGA actual. Correr DESPUÉS de seed.sql (como
-- seed_plan_a22.sql).
--
-- La fecha de inicio (primer cuatrimestre de 2023) se supone por el
-- nombre del plan: el detalle no la muestra.
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
SELECT id, 'S10-Rev23', 1, 243, DATE '2023-03-01', NULL
FROM sga.carrera WHERE codigo = 'S'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE s10_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'S' AND p.codigo = 'S10-Rev23';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM s10_plan p
CROSS JOIN (VALUES
    ('Ciclo Básico',      'APROBAR_TODOS',   147, 1),
    ('Ciclo Profesional', 'APROBAR_TODOS',    96, 2),
    ('Electivas',         'JUNTAR_CREDITOS',  27, 3)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE s10_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO s10_materias VALUES
    -- Ciclo Básico
    ('Ciclo Básico', '31.08', 'Sistemas de Representación', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '72.03', 'Introducción a la Informática', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '93.26', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '93.58', 'Álgebra', 9, 0, 1, 1, ''),
    ('Ciclo Básico', '94.24', 'Metodología del Aprendizaje', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '72.31', 'Programación Imperativa', 9, 0, 1, 2, '93.58 72.03'),
    ('Ciclo Básico', '93.28', 'Análisis Matemático II', 6, 0, 1, 2, '93.58 93.26'),
    ('Ciclo Básico', '93.41', 'Física I', 6, 0, 1, 2, '93.26'),
    ('Ciclo Básico', '93.59', 'Matemática Discreta', 6, 0, 1, 2, '93.58'),
    ('Ciclo Básico', '12.09', 'Química', 3, 0, 2, 1, ''),
    ('Ciclo Básico', '72.32', 'Diseño y Procesamiento de Documentos XML', 3, 0, 2, 1, '72.31'),
    ('Ciclo Básico', '72.33', 'Programación Orientada a Objetos', 6, 0, 2, 1, '72.31'),
    ('Ciclo Básico', '93.35', 'Lógica Computacional', 6, 0, 2, 1, '93.58'),
    ('Ciclo Básico', '93.43', 'Física III', 6, 0, 2, 1, '93.28 93.41'),
    ('Ciclo Básico', '72.08', 'Arquitectura de Computadoras', 6, 0, 2, 2, '72.31'),
    ('Ciclo Básico', '72.34', 'Estructura de Datos y Algoritmos', 6, 0, 2, 2, '93.59 72.33'),
    ('Ciclo Básico', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 2, '93.28'),
    ('Ciclo Básico', '93.42', 'Física II', 6, 0, 2, 2, '93.28'),
    ('Ciclo Básico', '72.11', 'Sistemas Operativos', 6, 0, 3, 1, '72.08 72.34'),
    ('Ciclo Básico', '72.35', 'Ingeniería de Software I', 6, 0, 3, 1, '72.33'),
    ('Ciclo Básico', '72.36', 'Interacción Hombre-Computadora (HCI)', 6, 0, 3, 1, '72.33 72.32'),
    ('Ciclo Básico', '72.37', 'Base de Datos I', 6, 0, 3, 1, '72.34 93.35'),
    ('Ciclo Básico', '72.07', 'Protocolos de Comunicación', 6, 0, 3, 2, '72.11'),
    ('Ciclo Básico', '72.38', 'Proyecto de Aplicaciones Web', 6, 0, 3, 2, '72.11 72.37 72.36 72.35'),
    ('Ciclo Básico', '72.39', 'Autómatas, Teoría de Lenguajes y Compiladores', 6, 0, 3, 2, '72.34'),
    ('Ciclo Básico', '93.07', 'Métodos Numéricos', 3, 0, 3, 2, '93.28'),
    ('Ciclo Básico', '94.21', 'Formación General I', 3, 0, 3, 2, ''),
    ('Ciclo Básico', '94.51', 'Inglés I', 0, 0, 3, 2, ''),
    -- Ciclo Profesional
    ('Ciclo Profesional', '61.23', 'Economía para Ingenieros', 3, 120, 4, 1, ''),
    ('Ciclo Profesional', '61.32', 'Derecho para Ingenieros', 3, 120, 4, 1, ''),
    ('Ciclo Profesional', '72.40', 'Ingeniería del Software II', 3, 0, 4, 1, '72.35'),
    ('Ciclo Profesional', '72.41', 'Base de Datos II', 6, 0, 4, 1, '72.37 72.11'),
    ('Ciclo Profesional', '72.42', 'Programación de Objetos Distribuidos', 3, 0, 4, 1, '72.07 72.37'),
    ('Ciclo Profesional', '93.75', 'Métodos Numéricos Avanzados', 6, 0, 4, 1, '93.07'),
    ('Ciclo Profesional', '72.25', 'Simulación de Sistemas', 6, 140, 4, 2, '93.75 72.34 93.07'),
    ('Ciclo Profesional', '72.27', 'Sistemas de Inteligencia Artificial', 6, 120, 4, 2, '93.75 93.24 72.34'),
    ('Ciclo Profesional', '72.43', 'Gestión de Proyectos Informáticos', 3, 0, 4, 2, ''),
    ('Ciclo Profesional', '72.44', 'Criptografía y Seguridad', 6, 0, 4, 2, '72.07'),
    ('Ciclo Profesional', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 140, 5, 1, ''),
    ('Ciclo Profesional', '72.20', 'Redes de Información', 6, 171, 5, 1, '72.07'),
    ('Ciclo Profesional', '72.45', 'Proyecto Final', 12, 160, 5, 1, ''),
    ('Ciclo Profesional', '72.98', 'Práctica Laboral', 0, 144, 5, 2, ''),
    ('Ciclo Profesional', '94.23', 'Formación General III', 3, 168, 5, 2, ''),
    ('Ciclo Profesional', '94.52', 'Inglés II', 0, 0, 5, 2, ''),
    -- Electivas
    ('Electivas', '10.07', 'Creatividad', 3, 96, NULL, NULL, ''),
    ('Electivas', '10.09', 'Formación para Emprendedores', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.36', 'Innovación y Competitividad', 3, 192, NULL, NULL, ''),
    ('Electivas', '11.83', 'Gestión de Operaciones', 6, 0, NULL, NULL, '93.24'),
    ('Electivas', '16.04', 'Neurociencias y Desarrollo Productivo', 3, 0, NULL, NULL, ''),
    ('Electivas', '16.50', 'Introducción a la Bioinformática', 3, 0, NULL, NULL, '72.37'),
    ('Electivas', '16.57', 'Robótica Bioinspirada', 3, 0, NULL, NULL, '72.08'),
    ('Electivas', '16.68', 'Señales y Sistemas', 6, 0, NULL, NULL, '93.75'),
    ('Electivas', '16.82', 'Neurociencia Computacional', 3, 0, NULL, NULL, '93.28 72.34 93.24'),
    ('Electivas', '16.95', 'Startups basadas en ciencia', 1, 144, NULL, NULL, ''),
    ('Electivas', '22.09', 'Fundamentos Electrónicos de la Informática', 6, 0, NULL, NULL, ''),
    ('Electivas', '22.48', 'Procesamiento de Imágenes', 3, 0, NULL, NULL, '93.75'),
    ('Electivas', '23.15', 'Realidad Virtual', 3, 0, NULL, NULL, '93.58 72.34'),
    ('Electivas', '25.04', 'Computación Cuántica', 6, 144, NULL, NULL, ''),
    ('Electivas', '25.27', 'Sistemas Embebidos', 6, 144, NULL, NULL, ''),
    ('Electivas', '48.02', 'AI: Data Management Course & Digital Transformation', 1, 0, NULL, NULL, ''),
    ('Electivas', '61.08', 'Derecho Digital', 1, 0, NULL, NULL, '61.32'),
    ('Electivas', '61.11', 'Derecho Laboral y Seguridad Social en la Empresa', 1, 0, NULL, NULL, '61.32'),
    ('Electivas', '61.13', 'Práctica Contractual', 1, 0, NULL, NULL, '61.32'),
    ('Electivas', '61.16', 'Introducción a las Finanzas', 3, 0, NULL, NULL, '61.23'),
    ('Electivas', '61.50', 'Finanzas de la Empresa', 3, 0, NULL, NULL, '61.23'),
    ('Electivas', '68.99', 'Introducción a la Ciencia de Ciudades', 1, 144, NULL, NULL, ''),
    ('Electivas', '71.48', 'Introducción a la realidad aumentada', 1, 51, NULL, NULL, ''),
    ('Electivas', '72.02', 'Organización Básica de la Computadora', 6, 0, NULL, NULL, ''),
    ('Electivas', '72.18', 'Programación Funcional', 4, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.22', 'Sistemas Tolerantes a Fallas', 6, 0, NULL, NULL, ''),
    ('Electivas', '72.23', 'Diseño y Construcción de Compiladores', 1, 0, NULL, NULL, ''),
    ('Electivas', '72.28', 'Topología de Internet: Análisis y Modelado', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.29', 'Tipos para Lenguajes de Programación', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.46', 'Robótica Basada en Comportamiento', 6, 0, NULL, NULL, '72.27'),
    ('Electivas', '72.49', 'Sistemas Tolerantes a Fallas', 3, 0, NULL, NULL, '72.42'),
    ('Electivas', '72.50', 'Introducción al Desarrollo de Videojuegos', 6, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.51', 'Tecnologías para Web 2.0 y Redes Sociales', 3, 0, NULL, NULL, '72.42'),
    ('Electivas', '72.52', 'Análisis y Tratamiento de Imágenes', 3, 0, NULL, NULL, '93.75 72.34'),
    ('Electivas', '72.53', 'Visión Computacional 3D', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.54', 'OLAP y Explotación de Datos', 3, 0, NULL, NULL, '93.24 72.41'),
    ('Electivas', '72.55', 'Ontologías en la Web', 3, 0, NULL, NULL, '72.32 72.37'),
    ('Electivas', '72.56', 'Automatización e Integración de Sistemas de Información', 6, 0, NULL, NULL, ''),
    ('Electivas', '72.57', 'Sistemas Embebidos', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.58', 'Computación Gráfica', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.59', 'Sistemas de Inteligencia Artificial II', 3, 0, NULL, NULL, '72.27'),
    ('Electivas', '72.60', 'Programación Funcional', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.61', 'Taller de Diseño de Videojuegos', 1, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.64', 'Cloud Computing', 3, 0, NULL, NULL, '72.32'),
    ('Electivas', '72.65', 'Desarrollo de Videojuegos 2D en IPhone OS', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.66', 'Sistemas Embebidos', 6, 0, NULL, NULL, ''),
    ('Electivas', '72.67', 'Robótica Cinemática Computacional', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.68', 'Arte y Ciencia Interactivos', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.69', 'Seguridad de Software basada en Flujo de Información', 6, 0, NULL, NULL, ''),
    ('Electivas', '72.70', 'Modelos e Imágenes Fractales', 1, 0, NULL, NULL, ''),
    ('Electivas', '72.71', 'Integración de Sistemas de Información', 3, 0, NULL, NULL, '72.07 72.37 72.35'),
    ('Electivas', '72.72', 'Análisis y Verificación de Modelos y Códigos', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.73', 'Aprendizaje por Refuerzo en Robótica', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.74', 'Visualización de Información', 3, 0, NULL, NULL, '72.31'),
    ('Electivas', '72.75', 'Aprendizaje Automático (Machine Learning)', 3, 0, NULL, NULL, '93.75 72.34 93.24'),
    ('Electivas', '72.77', 'Técnicas Automáticas para Testing de Software', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.78', 'OLAP Espacial', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.79', 'Sistemas Multiagente I', 3, 144, NULL, NULL, ''),
    ('Electivas', '72.80', 'Big Data', 3, 0, NULL, NULL, '72.41'),
    ('Electivas', '72.81', 'Simulación y Animación de Sistemas Multipartículas', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.82', 'Tópicos de NOSQL', 3, 0, NULL, NULL, '72.41'),
    ('Electivas', '72.83', 'Técnicas Avanzadas de HCI con Uso de Rastreadores de Ojos y Manos', 3, 0, NULL, NULL, ''),
    ('Electivas', '72.84', 'Base de Datos Espaciales y Sistemas de Información Geográfica', 3, 0, NULL, NULL, '72.37'),
    ('Electivas', '72.85', 'Análisis de Datos en la Web Semántica', 3, 0, NULL, NULL, '72.32 72.37'),
    ('Electivas', '72.86', 'Técnicas Avanzadas en Videojuegos', 3, 0, NULL, NULL, '72.97'),
    ('Electivas', '72.87', 'Diseño Sonoro para Animación y Videojuegos', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '72.88', 'Introducción a la Neurociencia Computacional', 3, 0, NULL, NULL, '93.75 93.24 72.34'),
    ('Electivas', '72.89', 'Moneda Digital Descentralizada', 3, 0, NULL, NULL, '72.44'),
    ('Electivas', '72.90', 'Internet de las Cosas (IoT)', 3, 0, NULL, NULL, '93.07 93.43'),
    ('Electivas', '72.92', 'El Paradigma NoSQL - Bases de Datos de Grafos', 3, 0, NULL, NULL, '72.41'),
    ('Electivas', '72.94', 'Introducción a los Sistemas Embebidos', 3, 0, NULL, NULL, '72.08'),
    ('Electivas', '72.95', 'Proyecto de Innovación Científico-Tecnológico', 12, 0, NULL, NULL, ''),
    ('Electivas', '72.96', 'Proyecto de Aplicaciones Móviles', 3, 0, NULL, NULL, '72.38'),
    ('Electivas', '72.97', 'Introducción a la Programación de Videojuegos', 3, 0, NULL, NULL, '72.34'),
    ('Electivas', '73.21', 'Desarrollo de Aplicaciones Móviles Multiplataforma', 3, 0, NULL, NULL, '72.38'),
    ('Electivas', '73.22', 'Fundamentos de DevOps', 3, 0, NULL, NULL, '72.35'),
    ('Electivas', '73.23', 'Programación Orientada a Datos', 1, 0, NULL, NULL, '72.34'),
    ('Electivas', '73.24', 'Diseño de Runtimes Concurrentes', 1, 0, NULL, NULL, '72.34'),
    ('Electivas', '73.30', 'Desarrollo profesional de software: del código al producto', 3, 0, NULL, NULL, '72.38'),
    ('Electivas', '73.31', 'Spec-Driven Development', 1, 0, NULL, NULL, '72.38 72.35'),
    ('Electivas', '73.40', 'ARQUITECTURA DE MICROSERVICIOS', 3, 0, NULL, NULL, '72.07 72.35'),
    ('Electivas', '73.50', 'Infraestructura de Cómputo: Data Center, Cloud y Edge', 3, 0, NULL, NULL, '72.20 72.41'),
    ('Electivas', '73.60', 'Introducción a la Robótica Empresarial', 1, 0, NULL, NULL, ''),
    ('Electivas', '73.61', 'Neurorobótica', 1, 0, NULL, NULL, ''),
    ('Electivas', '73.62', 'Introducción a la Programación Paralela', 1, 0, NULL, NULL, '72.33 72.11'),
    ('Electivas', '73.63', 'Redes Equivariantes', 1, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.64', 'Temas Avanzados en Deep Learning', 2, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.65', 'Procesamiento del Lenguaje Natural', 3, 0, NULL, NULL, '93.07'),
    ('Electivas', '73.66', 'Procesamiento de Imágenes Satelitales', 1, 0, NULL, NULL, ''),
    ('Electivas', '73.67', 'Análisis de series de tiempo con Inteligencia Artificial', 1, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.68', 'Tecnologías Emergentes para Aprendizaje Automático e Inteligencia Artificial', 1, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.69', 'Large Language Models', 3, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.70', 'Análisis de datos en neurociencias', 3, 144, NULL, NULL, ''),
    ('Electivas', '73.80', 'SEGURIDAD OFENSIVA', 1, 0, NULL, NULL, '72.44'),
    ('Electivas', '73.81', 'Ciberseguridad Ofensiva y Defensiva', 3, 0, NULL, NULL, '72.44'),
    ('Electivas', '73.82', 'Bases de Datos Espaciales y de Movilidad', 3, 0, NULL, NULL, '72.37'),
    ('Electivas', '73.83', 'Gestión estratégica de la Ciberseguridad', 1, 0, NULL, NULL, '72.44'),
    ('Electivas', '73.84', 'Ciencia de Datos Aplicada', 3, 0, NULL, NULL, '72.27'),
    ('Electivas', '73.89', 'Introducción a Blockchain y Criptomonedas', 3, 0, NULL, NULL, '72.44'),
    ('Electivas', '73.98', 'Desarrollo Integral de Videojuegos', 3, 0, NULL, NULL, '72.97'),
    ('Electivas', '74.60', 'Visión por Computadora (Computer Vision)', 3, 144, NULL, NULL, ''),
    ('Electivas', '74.61', 'Current AI techniques for scientific discovery', 1, 0, NULL, NULL, '72.27'),
    ('Electivas', '81.13', 'Futuros Posibles', 1, 0, NULL, NULL, ''),
    ('Electivas', '81.14', 'Product Management', 3, 0, NULL, NULL, ''),
    ('Electivas', '81.16', 'Negociación', 1, 0, NULL, NULL, ''),
    ('Electivas', '81.57', 'Arquitectura de soluciones digitales', 3, 0, NULL, NULL, '72.07 72.37 72.35'),
    ('Electivas', '81.74', 'Introducción a la realidad aumentada', 1, 51, NULL, NULL, ''),
    ('Electivas', '81.76', 'Tecnologías para las Finanzas', 3, 144, NULL, NULL, ''),
    ('Electivas', '81.94', 'Experiencia Inmersiva de Innovación Tecnológica', 1, 0, NULL, NULL, ''),
    ('Electivas', '82.08', 'Cloud Computing', 3, 0, NULL, NULL, '72.32'),
    ('Electivas', '82.18', 'Procesamiento del Lenguaje Natural', 3, 0, NULL, NULL, '93.07'),
    ('Electivas', '82.21', 'Factibilidad de Proyectos Data Driven', 3, 0, NULL, NULL, '61.23'),
    ('Electivas', '94.26', 'Comunicación Organizacional', 3, 0, NULL, NULL, ''),
    ('Electivas', '94.42', 'Comunicación Estratégica', 3, 0, NULL, NULL, ''),
    ('Electivas', '94.62', 'Ética en los Negocios', 3, 0, NULL, NULL, ''),
    ('Electivas', '94.64', 'Prácticas Expositivas', 3, 120, NULL, NULL, ''),
    ('Electivas', '94.65', 'Practica Profesional supervisada', 0, 144, NULL, NULL, ''),
    ('Electivas', '94.78', 'Gestión de Capital Emprendedor y Venture Capital', 1, 0, NULL, NULL, '10.09'),
    ('Electivas', '94.92', 'Escritura Académica', 3, 0, NULL, NULL, '');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM s10_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM s10_materias m
CROSS JOIN s10_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 4, 2, 27
FROM s10_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'Electivas'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM s10_materias m
CROSS JOIN s10_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT p.id, t.tipo, t.nombre, t.requisito
FROM s10_plan p
CROSS JOIN (VALUES
    ('Intermedio', 'Analista en Tecnología Informática', 'Aprobar Ciclo Básico y sumar 147 créditos'),
    ('Principal',  'Ingeniero/a en Informática',         'Aprobar S10-Rev23 y sumar 243 créditos')
) AS t (tipo, nombre, requisito)
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: los dos ciclos deben sumar 243 créditos (materias + hueco)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'S10-Rev23') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'S10-Rev23' AND b.requisito = 'APROBAR_TODOS')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'S10-Rev23') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'S10-Rev23') AS correlativas;
