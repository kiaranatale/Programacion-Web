-- =====================================================================
-- Plan A22 de la Licenciatura en Analítica Empresarial y Social (LAES),
-- transcripto del "Detalle de Planes de estudio" del SGA actual.
-- Correr DESPUÉS de seed.sql y ANTES de seed_usuarios.sql.
--
-- Los departamentos de cada materia no figuran en el detalle del plan:
-- las materias nuevas quedan en "A confirmar" hasta tener ese dato.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.departamento (nombre) VALUES ('A confirmar')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.plan_estudio (carrera_id, codigo, version, creditos_totales, vigencia_desde)
SELECT id, 'A22', 1, 192, DATE '2024-08-01'
FROM sga.carrera WHERE codigo = 'LAES'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE a22_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'LAES' AND p.codigo = 'A22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM a22_plan p
CROSS JOIN (VALUES
    ('Básico',               'APROBAR_TODOS',   192, 1),
    ('Electivas Analytics',  'JUNTAR_CREDITOS',  15, 2),
    ('Electivas Gestion',    'JUNTAR_CREDITOS',  18, 3),
    ('Electivas Informática','JUNTAR_CREDITOS',  15, 4),
    ('Electivas Orientación','JUNTAR_CREDITOS',  18, 5),
    ('Electivas Social',     'JUNTAR_CREDITOS',  12, 6)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE a22_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO a22_materias VALUES
    -- Básico
    ('Básico', '71.80', 'Utilitarios en Informática', 6, 0, 1, 1, ''),
    ('Básico', '81.06', 'Introducción a la Administración', 6, 0, 1, 1, ''),
    ('Básico', '93.20', 'Análisis Matemático', 6, 0, 1, 1, ''),
    ('Básico', '93.21', 'Álgebra', 6, 0, 1, 1, ''),
    ('Básico', '71.20', 'Informática General', 3, 0, 1, 2, ''),
    ('Básico', '82.15', 'Matemática Aplicada', 6, 0, 1, 2, '93.20 93.21'),
    ('Básico', '93.16', 'Matemática Discreta', 3, 0, 1, 2, ''),
    ('Básico', '94.24', 'Metodología del Aprendizaje', 3, 0, 1, 2, ''),
    ('Básico', '94.60', 'Panorama Histórico Global', 3, 0, 1, 2, ''),
    ('Básico', '61.81', 'Microeconomía', 3, 0, 2, 1, '93.20'),
    ('Básico', '71.45', 'Estructura de Datos y Programación', 6, 0, 2, 1, '71.20'),
    ('Básico', '93.36', 'Probabilidad', 3, 0, 2, 1, '93.16 82.15'),
    ('Básico', '94.61', 'Filosofía', 3, 0, 2, 1, ''),
    ('Básico', '94.62', 'Ética en los Negocios', 3, 0, 2, 1, ''),
    ('Básico', '11.67', 'Estadística Aplicada', 6, 0, 2, 2, '93.36'),
    ('Básico', '71.88', 'Gestión de Datos', 6, 0, 2, 2, '71.20'),
    ('Básico', '72.74', 'Visualización de Información', 3, 0, 2, 2, '71.20'),
    ('Básico', '94.40', 'Estructura de las Organizaciones', 3, 0, 2, 2, '81.06'),
    ('Básico', '94.90', 'Inglés I (analista)', 0, 0, 2, 2, ''),
    ('Básico', '61.82', 'Macroeconomía', 3, 0, 3, 1, '93.20'),
    ('Básico', '61.87', 'Derecho Público y Privado I', 3, 0, 3, 1, ''),
    ('Básico', '82.01', 'Proyecto I', 3, 0, 3, 1, '11.67 71.88 72.74'),
    ('Básico', '82.03', 'Gestión del Ciclo de Vida de la Información', 3, 0, 3, 1, '71.88'),
    ('Básico', '82.04', 'Analítica Descriptiva', 6, 0, 3, 1, '11.67 71.88'),
    ('Básico', '11.86', 'Investigación de Operaciones I', 3, 0, 3, 2, '11.67'),
    ('Básico', '82.05', 'Análisis Predictivo', 6, 0, 3, 2, '11.67'),
    ('Básico', '11.87', 'Investigación de Operaciones II', 3, 0, 4, 1, '11.67'),
    ('Básico', '11.63', 'Simulación', 3, 0, 4, 2, '11.86 11.87'),
    ('Básico', '82.02', 'Proyecto Final - Analítica', 3, 0, 4, 2, '82.05 11.86 72.74 82.04 11.87 82.03 82.01'),
    ('Básico', '94.91', 'Inglés II (licenciado)', 0, 0, 4, 2, '94.90'),
    -- Electivas Analytics
    ('Electivas Analytics', '10.15', 'Agroindustria', 3, 96, NULL, NULL, ''),
    ('Electivas Analytics', '15.12', 'Análisis Estratégico del Mercado', 1, 96, NULL, NULL, ''),
    ('Electivas Analytics', '73.67', 'Análisis de series de tiempo con Inteligencia Artificial', 1, 0, NULL, NULL, '71.88 93.20 93.36'),
    ('Electivas Analytics', '74.61', 'Current AI techniques for scientific discovery', 1, 96, NULL, NULL, '71.22'),
    ('Electivas Analytics', '81.17', 'Finanzas y Programación', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '81.76', 'Tecnologías para las Finanzas', 3, 96, NULL, NULL, '71.88'),
    ('Electivas Analytics', '82.09', 'Analítica en Redes de Telecomunicaciones', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.10', 'Analítica en Transporte y Logística', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.11', 'Analítica en Venta Minorista', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.12', 'Análisis de Información Biomédica', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.13', 'Analítica de Redes Sociales', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.14', 'Analítica en Recursos Humanos', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.16', 'Analítica de Ciudades', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.17', 'Análisis Multivariado', 3, 96, NULL, NULL, '11.67 71.45'),
    ('Electivas Analytics', '82.19', 'Analítica del Deporte', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.20', 'Análisis Predictivo Avanzado', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.21', 'Factibilidad de Proyectos Data Driven', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.23', 'Marketing Analytics', 3, 96, NULL, NULL, ''),
    ('Electivas Analytics', '82.81', 'Analítica de Big Data con Spark', 3, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.82', 'Analítica de medios sociales', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.83', 'Analítica en Marketing', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.84', 'Gestión de Innovación con enfoque cuantitativo', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.85', 'Aplicaciones de analítica de redes sociales', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.86', 'Análisis Estratégico Cuantitativo', 1, 96, NULL, NULL, '82.05 82.04'),
    ('Electivas Analytics', '82.87', 'Conocimiento del cliente en analítica', 1, 96, NULL, NULL, '82.05 82.04'),
    -- Electivas Gestion
    ('Electivas Gestion', '10.09', 'Formación para Emprendedores', 3, 115, NULL, NULL, ''),
    ('Electivas Gestion', '10.10', 'Gestión de Sistemas Complejos', 3, 96, NULL, NULL, '11.79'),
    ('Electivas Gestion', '11.79', 'Sistemas y Modelos', 3, 96, NULL, NULL, '93.36'),
    ('Electivas Gestion', '11.83', 'Gestión de Operaciones', 6, 96, NULL, NULL, '81.06 93.36'),
    ('Electivas Gestion', '11.84', 'Gestión de Proyectos', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '15.09', 'Agile, Lean y Lean Six Sigma', 1, 96, NULL, NULL, ''),
    ('Electivas Gestion', '17.22', 'Cálculo de Huella de Carbono en Organizaciones', 1, 96, NULL, NULL, ''),
    ('Electivas Gestion', '17.23', 'Triple Impacto: Estrategias para el Desarrollo Sostenible', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '61.30', 'Econometría Aplicada', 3, 96, NULL, NULL, '61.82 11.67'),
    ('Electivas Gestion', '81.03', 'Sistemas de Información', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.04', 'Teoría de Juegos y Estrategia', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.19', 'Marketing Digital', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.20', 'Comercialización', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.23', 'Comercio Electrónico', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.28', 'Tecnologías exponenciales', 3, 115, NULL, NULL, ''),
    ('Electivas Gestion', '81.41', 'Estrategia Empresaria', 6, 115, NULL, NULL, ''),
    ('Electivas Gestion', '81.42', 'Estrategia Empresarial', 3, 144, NULL, NULL, ''),
    ('Electivas Gestion', '81.58', 'Service Design', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.70', 'Service Analysis', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '81.86', 'Gestión de la Experiencia del Usuario (CX, UX, UI)', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '82.24', 'Investigación de Mercados', 3, 0, NULL, NULL, '11.67 82.04'),
    ('Electivas Gestion', '82.90', 'Estadística para los Negocios', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '94.27', 'Administración de Recursos Humanos', 3, 96, NULL, NULL, '61.87'),
    ('Electivas Gestion', '94.64', 'Prácticas Expositivas', 3, 96, NULL, NULL, ''),
    ('Electivas Gestion', '94.78', 'Gestión de Capital Emprendedor y Venture Capital', 1, 0, NULL, NULL, '10.09'),
    -- Electivas Informática
    ('Electivas Informática', '71.22', 'Sistemas de Inteligencia Artificial', 3, 96, NULL, NULL, '71.20 82.15'),
    ('Electivas Informática', '71.38', 'Programación web', 3, 96, NULL, NULL, '71.20'),
    ('Electivas Informática', '71.77', 'Fundamentos de programación y análisis de datos', 1, 0, NULL, NULL, ''),
    ('Electivas Informática', '71.92', 'Base de Datos I', 6, 96, NULL, NULL, '71.45 93.16'),
    ('Electivas Informática', '72.41', 'Base de Datos II', 6, 96, NULL, NULL, '71.88'),
    ('Electivas Informática', '72.92', 'El Paradigma NoSQL - Bases de Datos de Grafos', 3, 96, NULL, NULL, '72.41'),
    ('Electivas Informática', '73.22', 'Fundamentos de DevOps', 3, 96, NULL, NULL, '81.32'),
    ('Electivas Informática', '73.82', 'Bases de Datos Espaciales y de Movilidad', 3, 96, NULL, NULL, '71.88'),
    ('Electivas Informática', '73.89', 'Introducción a Blockchain y Criptomonedas', 3, 96, NULL, NULL, ''),
    ('Electivas Informática', '81.32', 'Análisis funcional de aplicaciones informáticas', 3, 72, NULL, NULL, ''),
    ('Electivas Informática', '81.56', 'Arquitectura de la Tecnología Informática', 6, 96, NULL, NULL, ''),
    ('Electivas Informática', '81.57', 'Arquitectura de soluciones digitales', 3, 96, NULL, NULL, ''),
    ('Electivas Informática', '81.75', 'Fund. del desarrollo de software y análisis de datos en Python', 1, 0, NULL, NULL, ''),
    ('Electivas Informática', '81.91', 'Inteligencia Artificial Aplicada a los Negocios', 3, 96, NULL, NULL, ''),
    ('Electivas Informática', '82.06', 'Plataformas de Computación Cognitiva', 3, 96, NULL, NULL, ''),
    ('Electivas Informática', '82.08', 'Cloud Computing', 3, 96, NULL, NULL, ''),
    ('Electivas Informática', '82.18', 'Procesamiento del Lenguaje Natural', 3, 96, NULL, NULL, '82.05 11.67 71.45'),
    ('Electivas Informática', '82.22', 'Inteligencia Artificial Generativa', 1, 0, NULL, NULL, '82.05'),
    ('Electivas Informática', '83.16', 'Machine Learning para Negocios', 3, 0, NULL, NULL, '82.15'),
    -- Electivas Orientación
    ('Electivas Orientación', '61.12', 'Gestión Financiera', 6, 0, NULL, NULL, '81.07 93.21'),
    ('Electivas Orientación', '81.07', 'Sistemas Contables', 6, 0, NULL, NULL, ''),
    ('Electivas Orientación', '81.11', 'Contabilidad Gerencial', 6, 0, NULL, NULL, '81.07'),
    ('Electivas Orientación', '94.11', 'Sociología Política', 6, 0, NULL, NULL, ''),
    ('Electivas Orientación', '94.12', 'Antropología', 6, 0, NULL, NULL, ''),
    ('Electivas Orientación', '94.13', 'Gestión de Organizaciones Sociales', 6, 0, NULL, NULL, ''),
    -- Electivas Social
    ('Electivas Social', '10.07', 'Creatividad', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '10.11', 'Infraestructuras de Nueva Generación', 3, 96, NULL, NULL, '61.03'),
    ('Electivas Social', '61.02', 'Economía del Mercado Laboral', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '61.03', 'Economía de las Infraestructuras', 3, 96, NULL, NULL, '61.82 61.81'),
    ('Electivas Social', '61.04', 'Sistema Monetario y Financiero en Argentina', 3, 96, NULL, NULL, '61.82 61.81'),
    ('Electivas Social', '61.05', 'Economía de la Salud', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '61.14', 'Economía Internacional Real', 3, 96, NULL, NULL, '61.82'),
    ('Electivas Social', '61.15', 'Economía Internacional Monetaria', 3, 96, NULL, NULL, '61.82'),
    ('Electivas Social', '81.05', 'Responsabilidad Social Empresaria', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '94.07', 'Cultura Latinoamericana', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '94.09', 'Cultura, Identidad y Política', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '94.14', 'Teorías Sociológicas Contemporáneas', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '94.15', 'Propiedad Intelectual y Nuevas Tecnologías', 3, 96, NULL, NULL, ''),
    ('Electivas Social', '94.77', 'Propiedad Intelectual', 1, 0, NULL, NULL, '61.87');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM a22_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM a22_materias m
CROSS JOIN a22_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Huecos de electivas en la grilla del bloque Básico
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, h.anio, h.cuatri, h.creditos
FROM a22_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id
JOIN (VALUES
    ('Electivas Orientación', 1, 2, 18),
    ('Electivas Gestion',     3, 1, 18),
    ('Electivas Informática', 3, 1, 15),
    ('Electivas Analytics',   3, 2, 15),
    ('Electivas Social',      3, 2, 12)
) AS h (bloque, anio, cuatri, creditos) ON h.bloque = b.nombre
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM a22_materias m
CROSS JOIN a22_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Licenciado/a en Analítica Empresarial y Social', 'Aprobar A22 (sumar 192 créditos)'
FROM a22_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: el bloque Básico debe sumar 192 créditos (materias + huecos)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'A22') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'A22' AND b.nombre = 'Básico')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'A22') AS creditos_basico,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'A22') AS correlativas;
