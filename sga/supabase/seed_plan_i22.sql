-- =====================================================================
-- Plan I22, generado con scripts/csv_a_seed_plan.py desde el
-- "Detalle de Planes de estudio" del SGA actual. Correr DESPUÉS de
-- seed.sql (como seed_plan_a22.sql).
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
SELECT id, 'I22', 1, 240, DATE '2022-08-01', DATE '2024-08-01'
FROM sga.carrera WHERE codigo = 'I'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE nuevo_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'I' AND p.codigo = 'I22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, items, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.items, b.orden
FROM nuevo_plan p
CROSS JOIN (VALUES
    ('PLAN I22', 'APROBAR_TODOS', 240, NULL::INTEGER, 1),
    ('Bloque I Electivas', 'JUNTAR_CREDITOS', 6, NULL::INTEGER, 2),
    ('Bloque II Electivas General', 'JUNTAR_CREDITOS', 43, NULL::INTEGER, 3),
    ('Bloque III Electivas Gestión', 'JUNTAR_CREDITOS', 3, NULL::INTEGER, 4),
    ('Bloque IV Electivas Tics', 'JUNTAR_CREDITOS', 3, NULL::INTEGER, 5),
    ('Bloque V Electivas Energía', 'JUNTAR_CREDITOS', 4, NULL::INTEGER, 6),
    ('Bloque VI Electivas Finanzas', 'JUNTAR_CREDITOS', 6, NULL::INTEGER, 7),
    ('Bloque VII Electivas Tecnología', 'JUNTAR_CREDITOS', 6, NULL::INTEGER, 8),
    ('Gestión de datos (obligatoria)', 'APROBAR_ITEMS', 6, 1, 9)
) AS b (nombre, requisito, creditos, items, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE nuevo_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO nuevo_materias VALUES
    ('PLAN I22', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('PLAN I22', '71.20', 'Informática General', 3, 0, 1, 1, ''),
    ('PLAN I22', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('PLAN I22', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('PLAN I22', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('PLAN I22', '16.55', 'Biología', 3, 0, 1, 2, ''),
    ('PLAN I22', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('PLAN I22', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('PLAN I22', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('PLAN I22', '30.89', 'Mecánica de Sólidos', 3, 0, 2, 1, '93.41'),
    ('PLAN I22', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('PLAN I22', '93.36', 'Probabilidad', 3, 0, 2, 1, '92.02'),
    ('PLAN I22', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('PLAN I22', '11.28', 'Sistemas Complejos', 3, 0, 2, 2, ''),
    ('PLAN I22', '11.67', 'Estadística Aplicada', 6, 0, 2, 2, '93.36'),
    ('PLAN I22', '31.24', 'Mecánica de Fluidos', 3, 0, 2, 2, '92.03 93.41'),
    ('PLAN I22', '92.05', 'Análisis Matemático IV', 4, 0, 2, 2, '92.03'),
    ('PLAN I22', '93.07', 'Métodos Numéricos', 3, 0, 2, 2, '92.03'),
    ('PLAN I22', '93.43', 'Física III', 6, 0, 2, 2, '92.03'),
    ('PLAN I22', '11.10', 'Organización de la Producción I', 6, 0, 3, 1, ''),
    ('PLAN I22', '11.16', 'Materiales y Procesos', 6, 0, 3, 1, '30.89'),
    ('PLAN I22', '21.30', 'Principios y Aplicaciones Eléctricas', 5, 0, 3, 1, '93.43'),
    ('PLAN I22', '93.61', 'Física IV', 4, 0, 3, 1, '93.43'),
    ('PLAN I22', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, ''),
    ('PLAN I22', '11.20', 'Supply Chain', 6, 0, 3, 2, '11.10'),
    ('PLAN I22', '11.51', 'Investigación Operativa', 6, 0, 3, 2, '11.67'),
    ('PLAN I22', '30.32', 'Termodinámica y sus aplicaciones', 6, 0, 3, 2, '93.42'),
    ('PLAN I22', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('PLAN I22', '11.75', 'Tecnologías y Procesos de Producción', 3, 0, 4, 1, '11.16'),
    ('PLAN I22', '23.17', 'Electrónica e Instrumentación', 3, 0, 4, 1, ''),
    ('PLAN I22', '61.09', 'Economía Empresaria', 6, 0, 4, 1, '11.10'),
    ('PLAN I22', '71.90', 'Certificaciones tecnológicas', 0, 0, 4, 1, ''),
    ('PLAN I22', '94.51', 'Inglés I', 0, 0, 4, 1, ''),
    ('PLAN I22', '10.02', 'Gestión Ambiental', 3, 0, 4, 2, '11.75'),
    ('PLAN I22', '11.63', 'Simulación', 3, 0, 4, 2, '11.51'),
    ('PLAN I22', '61.28', 'Economía', 6, 0, 4, 2, '61.09'),
    ('PLAN I22', '61.31', 'Derecho para Ingenieros', 3, 0, 4, 2, ''),
    ('PLAN I22', '10.01', 'Proyecto Final de Ingeniería Industrial (Anual)', 6, 0, 5, 1, '94.44 11.51 61.09 11.20'),
    ('PLAN I22', '94.52', 'Inglés II', 0, 0, 5, 2, '94.51'),
    ('PLAN I22', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, ''),
    ('Bloque I Electivas', '71.45', 'Estructura de Datos y Programación', 6, 0, NULL, NULL, '71.20'),
    ('Bloque II Electivas General', '10.07', 'Creatividad', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '10.09', 'Formación para Emprendedores', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '10.15', 'Agroindustria', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '10.16', 'Machine Learning para Negocios', 3, 72, NULL, NULL, '92.03 93.36'),
    ('Bloque II Electivas General', '10.21', 'Herramientas Avanzadas de la Calidad', 3, 72, NULL, NULL, '11.67'),
    ('Bloque II Electivas General', '10.22', 'Machine Learning Avanzada', 3, 72, NULL, NULL, '10.16'),
    ('Bloque II Electivas General', '10.23', 'Agroindustria II', 3, 145, NULL, NULL, ''),
    ('Bloque II Electivas General', '11.39', 'Marketing', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '11.59', 'Logística', 3, 72, NULL, NULL, '11.20'),
    ('Bloque II Electivas General', '11.76', 'Gestión de Calidad', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '11.84', 'Gestión de Proyectos', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '11.91', 'Metodología de la Investigación', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.03', 'Gestión de la Innovación', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.14', 'Introducción a la Consultoría', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.37', 'Análisis de Encuestas', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.40', 'Ingeniería y Cambio Climático', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.46', 'Lean Manufacturing', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.59', 'Lean Six Sigma White Belt', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.67', 'Bem1105x Pricing Options with Mathematical Models', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.72', 'Analytics', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.77', 'Diseño de Producto', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.97', 'Diseño Circular: Sustentabilidad e Innovación en la Cadena de Valor.', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '14.99', 'Electric Cars Technology', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.06', 'Storytelling aplicado a los negocios', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.07', 'Conceptos de Minería para Ing. Industriales', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.11', 'Aplicaciones avanzadas de estadística', 1, 0, NULL, NULL, '11.67'),
    ('Bloque II Electivas General', '15.12', 'Análisis Estratégico del Mercado', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.13', 'Innovación en materiales Biobasados', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.14', 'Proyecto I', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.16', 'Supply Chain leadership', 1, 0, NULL, NULL, '11.20'),
    ('Bloque II Electivas General', '15.61', 'Mecánica de Fluidos Computacional', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.62', 'Ciclos reales en motores de combustión interna', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.63', 'Deformación y fractura de materiales', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.69', 'Factibilidad de proyectos Data Driven', 3, 145, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.70', 'Service Design', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.71', 'Introducción a la realidad virtual', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.72', 'Growth Hacking', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.75', 'Filosofía', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.76', 'Prácticas Expositivas', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.77', 'Química Inorgánica', 6, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.80', 'Seminario Internacional I', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.81', 'Seminario Internacional II', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.82', 'Seminario Internacional III', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.83', 'Seminario Internacional IV', 2, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.84', 'Gestión de la Operación Diaria a través de DMS y KPIs Estratégicos', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '15.85', 'Logística Internacional', 3, 0, NULL, NULL, '11.10'),
    ('Bloque II Electivas General', '15.86', 'Analítica para la Cadena de Suministro', 2, 0, NULL, NULL, '11.20'),
    ('Bloque II Electivas General', '15.87', 'Simulación para la Cadena de Suministro', 2, 0, NULL, NULL, '11.20'),
    ('Bloque II Electivas General', '15.89', 'Mejora continua de procesos', 3, 0, NULL, NULL, '11.67 11.10'),
    ('Bloque II Electivas General', '16.04', 'Neurociencias y Desarrollo Productivo', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '21.44', 'Instalaciones Eléctricas', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '23.15', 'Realidad Virtual', 3, 0, NULL, NULL, '71.45 71.20'),
    ('Bloque II Electivas General', '31.67', 'Procesos de Manufactura I', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '47.73', 'Operaciones Offshore - Petróleo y LNG', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '48.02', 'AI: Data Management Course & Digital Transformation', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '48.04', 'El Gas Natural Licuado - Tecnología, Mercados y Negocios', 3, 0, NULL, NULL, '61.28'),
    ('Bloque II Electivas General', '48.05', 'La Cadena de valor del Gas Natural', 3, 0, NULL, NULL, '61.28'),
    ('Bloque II Electivas General', '61.11', 'Derecho Laboral y Seguridad Social en la Empresa', 1, 0, NULL, NULL, '61.31'),
    ('Bloque II Electivas General', '61.34', 'Valuación de Empresas', 1, 0, NULL, NULL, '61.50'),
    ('Bloque II Electivas General', '71.22', 'Sistemas de Inteligencia Artificial', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '74.61', 'Current AI techniques for scientific discovery', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.04', 'Teoría de Juegos y Estrategia', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.21', 'Gestión de Ventas', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.51', 'Gestión de Empresas Familiares', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.53', 'Negocios en Internet', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.59', 'Gestión de Servicios', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.65', 'Logística Internacional', 3, 72, NULL, NULL, '11.20'),
    ('Bloque II Electivas General', '81.73', 'Introducción a la IOT', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.74', 'Introducción a la realidad aumentada', 1, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '81.94', 'Experiencia Inmersiva de Innovación Tecnológica', 1, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '82.07', 'Blockchain (Moneda digital descentralizada)', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '82.08', 'Cloud Computing', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '82.17', 'Análisis Multivariado', 3, 96, NULL, NULL, '11.67'),
    ('Bloque II Electivas General', '92.99', 'Complementos de Análisis Matemático IV', 2, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '94.13', 'Gestión de Organizaciones Sociales', 6, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '94.19', 'Comportamiento Organizacional', 3, 72, NULL, NULL, '94.33'),
    ('Bloque II Electivas General', '94.27', 'Administración de Recursos Humanos', 3, 72, NULL, NULL, ''),
    ('Bloque II Electivas General', '94.40', 'Estructura de las Organizaciones', 3, 0, NULL, NULL, ''),
    ('Bloque II Electivas General', '94.42', 'Comunicación Estratégica', 3, 72, NULL, NULL, ''),
    ('Bloque III Electivas Gestión', '11.46', 'Planeamiento Estratégico', 3, 72, NULL, NULL, ''),
    ('Bloque III Electivas Gestión', '11.73', 'Teoría de la Decisión', 3, 72, NULL, NULL, ''),
    ('Bloque IV Electivas Tics', '15.65', 'Derecho digital', 1, 72, NULL, NULL, ''),
    ('Bloque IV Electivas Tics', '15.67', 'Programación web', 3, 72, NULL, NULL, ''),
    ('Bloque IV Electivas Tics', '15.68', 'Programación Básica', 3, 0, NULL, NULL, ''),
    ('Bloque IV Electivas Tics', '81.03', 'Sistemas de Información', 3, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.08', 'Energías Renovables', 3, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.12', 'Energías Convencionales', 3, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.18', 'Demanda Energética', 2, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.19', 'Tecnologías Energéticas Disruptivas', 2, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.20', 'Introducción al Desarrollo Energético Sustentable', 2, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '10.24', 'Economía de la Transición Energética', 3, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '14.52', 'Eficiencia Energética', 1, 0, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '15.15', 'Tecnologías del Hidrógeno', 1, 72, NULL, NULL, ''),
    ('Bloque V Electivas Energía', '34.98', 'Baterías y Acumulación de Energía', 1, 0, NULL, NULL, '30.32 12.67 23.17'),
    ('Bloque V Electivas Energía', '47.86', 'Transición Energética y Sustentabilidad', 3, 96, NULL, NULL, ''),
    ('Bloque VI Electivas Finanzas', '15.64', 'Sistema Monetario y Financiero en Argentina', 3, 72, NULL, NULL, ''),
    ('Bloque VI Electivas Finanzas', '61.30', 'Econometría Aplicada', 3, 72, NULL, NULL, '11.67'),
    ('Bloque VI Electivas Finanzas', '61.50', 'Finanzas de la Empresa', 3, 72, NULL, NULL, ''),
    ('Bloque VI Electivas Finanzas', '61.93', 'Estrategia Financiera', 3, 0, NULL, NULL, '61.09'),
    ('Bloque VII Electivas Tecnología', '10.04', 'Plantas Industriales', 3, 72, NULL, NULL, ''),
    ('Bloque VII Electivas Tecnología', '11.14', 'Diseño de Producto', 3, 72, NULL, NULL, '11.16'),
    ('Bloque VII Electivas Tecnología', '11.19', 'Prototipado e Impresión 3D', 3, 72, NULL, NULL, ''),
    ('Bloque VII Electivas Tecnología', '11.33', 'Gestión de la tecnología', 3, 160, NULL, NULL, ''),
    ('Gestión de datos (obligatoria)', '71.78', 'Gestión de Datos', 6, 0, NULL, NULL, '71.20'),
    ('Gestión de datos (obligatoria)', '71.88', 'Gestión de Datos', 6, 900, NULL, NULL, '71.20');

-- Materias (las que ya existían conservan su nombre y departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT DISTINCT ON (m.codigo) m.codigo, m.nombre, d.id, m.creditos
FROM nuevo_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM nuevo_materias m
CROSS JOIN nuevo_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Huecos de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, h.anio, h.cuatri, h.creditos
FROM nuevo_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id
JOIN (VALUES
    ('Gestión de datos (obligatoria)', 1, 2, 6),
    ('Bloque I Electivas', NULL::SMALLINT, NULL::SMALLINT, 6),
    ('Bloque II Electivas General', NULL::SMALLINT, NULL::SMALLINT, 43),
    ('Bloque III Electivas Gestión', NULL::SMALLINT, NULL::SMALLINT, 3),
    ('Bloque IV Electivas Tics', NULL::SMALLINT, NULL::SMALLINT, 3),
    ('Bloque V Electivas Energía', NULL::SMALLINT, NULL::SMALLINT, 4),
    ('Bloque VI Electivas Finanzas', NULL::SMALLINT, NULL::SMALLINT, 6),
    ('Bloque VII Electivas Tecnología', NULL::SMALLINT, NULL::SMALLINT, 6)
) AS h (bloque, anio, cuatri, creditos) ON h.bloque = b.nombre
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM nuevo_materias m
CROSS JOIN nuevo_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT p.id, t.tipo, t.nombre, t.requisito
FROM nuevo_plan p
CROSS JOIN (VALUES
    ('Principal', 'Ingeniero/a Industrial', 'Aprobar I22 (sumar 240 créditos)')
) AS t (tipo, nombre, requisito)
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: 146 materias, 240 créditos en los bloques obligatorios
-- (materias + huecos) y 61 correlativas según el SGA.
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'I22') AS materias,
    (SELECT coalesce(sum(m.creditos), 0) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'I22' AND b.requisito = 'APROBAR_TODOS')
    + (SELECT coalesce(sum(h.creditos), 0) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'I22') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'I22') AS correlativas;
