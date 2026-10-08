-- =====================================================================
-- Plan C23 de Ingeniería Civil, transcripto del "Detalle de Planes de
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
SELECT id, 'C23', 1, 221, DATE '2024-08-01', NULL
FROM sga.carrera WHERE codigo = 'C'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE c23_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'C' AND p.codigo = 'C23';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM c23_plan p
CROSS JOIN (VALUES
    ('Básico',    'APROBAR_TODOS',   221, 1),
    ('Electivas', 'JUNTAR_CREDITOS',  30, 2)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE c23_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO c23_materias VALUES
    -- Básico
    ('Básico', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('Básico', '71.58', 'Informática General', 3, 0, 1, 1, ''),
    ('Básico', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('Básico', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('Básico', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('Básico', '16.55', 'Biología', 3, 0, 1, 2, ''),
    ('Básico', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('Básico', '67.04', 'Introducción a la temática social', 3, 0, 1, 2, ''),
    ('Básico', '71.90', 'Certificaciones tecnológicas', 0, 0, 1, 2, ''),
    ('Básico', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('Básico', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('Básico', '67.02', 'Estática', 6, 0, 2, 1, '93.18 93.41'),
    ('Básico', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('Básico', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 1, '92.02'),
    ('Básico', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('Básico', '94.51', 'Inglés I', 0, 0, 2, 1, ''),
    ('Básico', '31.22', 'Mecánica de Fluidos', 6, 0, 2, 2, '92.03 93.41'),
    ('Básico', '67.01', 'Tecnología de materiales', 3, 0, 2, 2, '93.41 12.67'),
    ('Básico', '67.03', 'Resistencia de Materiales', 6, 0, 2, 2, '67.02'),
    ('Básico', '93.43', 'Física III', 6, 0, 2, 2, '92.03 93.41'),
    ('Básico', '11.15', 'Organización Industrial', 3, 0, 3, 1, ''),
    ('Básico', '67.05', 'Tecnología del Hormigón', 3, 0, 3, 1, '67.01 93.24'),
    ('Básico', '67.06', 'Construcciones', 6, 0, 3, 1, '67.01'),
    ('Básico', '67.08', 'Análisis Estructural', 4, 0, 3, 1, '67.03'),
    ('Básico', '93.07', 'Métodos Numéricos', 3, 0, 3, 1, '71.58 92.03'),
    ('Básico', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, ''),
    ('Básico', '46.21', 'Geología I', 3, 0, 3, 2, '93.42'),
    ('Básico', '67.07', 'Geotopografía', 6, 0, 3, 2, '93.18 93.42 93.24'),
    ('Básico', '67.09', 'Instalaciones', 6, 0, 3, 2, '67.06'),
    ('Básico', '67.10', 'Hormigón I', 4, 0, 3, 2, '67.03 67.06 67.05'),
    ('Básico', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('Básico', '94.52', 'Inglés II', 0, 0, 3, 2, '94.51'),
    ('Básico', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 1, '93.24'),
    ('Básico', '61.31', 'Derecho para Ingenieros', 3, 0, 4, 1, '94.33'),
    ('Básico', '67.11', 'Evaluación de Impacto Ambiental y Social', 2, 0, 4, 1, '16.55 12.67 67.06'),
    ('Básico', '67.12', 'Geotecnia', 6, 0, 4, 1, '31.22 67.03 67.07'),
    ('Básico', '67.13', 'Hidrología y obras hidráulicas', 4, 0, 4, 1, '67.03 31.22 67.07'),
    ('Básico', '67.14', 'Hormigón II', 4, 0, 4, 2, '67.10 93.07 67.08'),
    ('Básico', '67.15', 'Planeamiento territorial y urbano', 3, 0, 4, 2, '94.33 61.31 67.07 67.06 67.11'),
    ('Básico', '67.16', 'Vías de Comunicación', 6, 0, 4, 2, '67.07 67.12 67.06 67.05 67.13'),
    ('Básico', '67.17', 'Higiene y Seguridad en Obras Civiles', 3, 0, 4, 2, '94.33 67.06'),
    ('Básico', '17.20', 'Agua y Efluentes Líquidos', 3, 0, 5, 1, '67.09 67.12 67.13'),
    ('Básico', '67.18', 'Proyecto Final', 6, 144, 5, 1, ''),
    ('Básico', '67.19', 'Cimentaciones', 4, 0, 5, 1, '67.10 67.08 67.12 67.13'),
    ('Básico', '67.20', 'Estructuras Metálicas y de Madera', 4, 0, 5, 1, '67.10 67.08'),
    ('Básico', '67.21', 'Organización y conducción de obras', 3, 0, 5, 1, '11.15 67.10 67.09 67.12 67.06'),
    ('Básico', '67.22', 'Auditorías ambientales', 3, 0, 5, 1, '67.11'),
    ('Básico', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, ''),
    -- Electivas
    ('Electivas', '10.07', 'Creatividad', 3, 0, NULL, NULL, ''),
    ('Electivas', '10.08', 'Energías Renovables', 3, 0, NULL, NULL, ''),
    ('Electivas', '10.09', 'Formación para Emprendedores', 3, 0, NULL, NULL, ''),
    ('Electivas', '10.12', 'Energías Convencionales', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.05', 'Calidad', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.19', 'Prototipado e Impresión 3D', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.39', 'Marketing', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.46', 'Planeamiento Estratégico', 3, 0, NULL, NULL, ''),
    ('Electivas', '11.73', 'Teoría de la Decisión', 3, 144, NULL, NULL, ''),
    ('Electivas', '11.76', 'Gestión de Calidad', 3, 0, NULL, NULL, '93.24'),
    ('Electivas', '11.84', 'Gestión de Proyectos', 3, 160, NULL, NULL, ''),
    ('Electivas', '11.89', 'Formulación y Evaluación de Proyectos', 3, 0, NULL, NULL, ''),
    ('Electivas', '16.04', 'Neurociencias y Desarrollo Productivo', 3, 0, NULL, NULL, ''),
    ('Electivas', '25.63', 'Redes Neuronales', 3, 0, NULL, NULL, ''),
    ('Electivas', '25.64', 'Deep Learning', 3, 0, NULL, NULL, ''),
    ('Electivas', '25.66', 'Acústica para Ingenieros', 3, 0, NULL, NULL, ''),
    ('Electivas', '25.69', 'Introducción a la Investigación', 3, 183, NULL, NULL, ''),
    ('Electivas', '46.82', 'Evaluación de Proyectos', 3, 0, NULL, NULL, ''),
    ('Electivas', '47.87', 'Desarrollo de Negocios', 3, 0, NULL, NULL, ''),
    ('Electivas', '61.04', 'Sistema Monetario y Financiero en Argentina', 3, 0, NULL, NULL, ''),
    ('Electivas', '61.09', 'Economía Empresaria', 6, 0, NULL, NULL, '93.24'),
    ('Electivas', '61.16', 'Introducción a las Finanzas', 3, 0, NULL, NULL, '11.15 61.27'),
    ('Electivas', '61.50', 'Finanzas de la Empresa', 3, 0, NULL, NULL, ''),
    ('Electivas', '67.23', 'Sustentabilidad y eficiencia energética en la construcción', 3, 0, NULL, NULL, '93.42'),
    ('Electivas', '68.99', 'Introducción a la Ciencia de Ciudades', 1, 144, NULL, NULL, ''),
    ('Electivas', '71.22', 'Sistemas de Inteligencia Artificial', 3, 0, NULL, NULL, '71.88'),
    ('Electivas', '71.59', 'Estructura de Datos y Programación', 6, 0, NULL, NULL, '71.58'),
    ('Electivas', '71.88', 'Gestión de Datos', 6, 0, NULL, NULL, '71.59'),
    ('Electivas', '81.59', 'Gestión de Servicios', 3, 0, NULL, NULL, ''),
    ('Electivas', '92.04', 'Análisis Matemático IV', 6, 0, NULL, NULL, '92.02 92.03'),
    ('Electivas', '92.07', 'Análisis Matemático V', 4, 0, NULL, NULL, '92.04'),
    ('Electivas', '92.20', 'Representación Gráfica para Ingeniería Civil', 1, 0, NULL, NULL, '31.08'),
    ('Electivas', '92.97', 'Complementos de Matemática V', 2, 0, NULL, NULL, ''),
    ('Electivas', '93.75', 'Métodos Numéricos Avanzados', 6, 0, NULL, NULL, '93.07'),
    ('Electivas', '94.40', 'Estructura de las Organizaciones', 3, 0, NULL, NULL, '94.44'),
    ('Electivas', '94.42', 'Comunicación Estratégica', 3, 0, NULL, NULL, ''),
    ('Electivas', '94.61', 'Filosofía', 3, 0, NULL, NULL, ''),
    ('Electivas', '94.62', 'Ética en los Negocios', 3, 72, NULL, NULL, '');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM c23_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM c23_materias m
CROSS JOIN c23_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 5, 2, 30
FROM c23_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'Electivas'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM c23_materias m
CROSS JOIN c23_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Ingeniero/a Civil', 'Aprobar C23 y sumar 221 créditos'
FROM c23_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: el bloque Básico debe sumar 221 créditos (materias + huecos)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'C23') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'C23' AND b.nombre = 'Básico')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'C23') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'C23') AS correlativas;
