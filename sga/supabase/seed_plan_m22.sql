-- =====================================================================
-- Plan M22, generado con scripts/csv_a_seed_plan.py desde el
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
SELECT id, 'M22', 1, 240, DATE '2023-03-01', NULL
FROM sga.carrera WHERE codigo = 'M'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE nuevo_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'M' AND p.codigo = 'M22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, items, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.items, b.orden
FROM nuevo_plan p
CROSS JOIN (VALUES
    ('Ciclo Básico', 'APROBAR_TODOS', 150, NULL::INTEGER, 1),
    ('Ciclo Profesional', 'APROBAR_TODOS', 90, NULL::INTEGER, 2),
    ('Materias electivas', 'JUNTAR_CREDITOS', 42, NULL::INTEGER, 3),
    ('Área Complementaria', 'JUNTAR_CREDITOS', 3, NULL::INTEGER, 4),
    ('Área Tecnológica', 'JUNTAR_CREDITOS', 36, NULL::INTEGER, 5)
) AS b (nombre, requisito, creditos, items, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE nuevo_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO nuevo_materias VALUES
    ('Ciclo Básico', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '71.58', 'Informática General', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('Ciclo Básico', '16.55', 'Biología', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '30.26', 'Ciencia de Materiales I', 6, 0, 1, 2, '12.67'),
    ('Ciclo Básico', '30.51', 'Introducción a la Ingeniería Mecánica', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '71.90', 'Certificaciones tecnológicas', 0, 0, 1, 2, ''),
    ('Ciclo Básico', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('Ciclo Básico', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('Ciclo Básico', '30.41', 'Diseño Mecánico I', 6, 0, 2, 1, '93.41 30.26 31.08'),
    ('Ciclo Básico', '30.46', 'Laboratorio de Diseño Mecánico', 3, 0, 2, 1, '93.41 31.08 30.26'),
    ('Ciclo Básico', '71.59', 'Estructura de Datos y Programación', 6, 0, 2, 1, '71.58 71.90'),
    ('Ciclo Básico', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('Ciclo Básico', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('Ciclo Básico', '30.42', 'Diseño Mecánico II', 6, 0, 2, 2, '92.02 92.03 93.41'),
    ('Ciclo Básico', '31.21', 'Termodinámica', 6, 0, 2, 2, '93.42 93.41'),
    ('Ciclo Básico', '92.04', 'Análisis Matemático IV', 6, 0, 2, 2, '92.02 92.03'),
    ('Ciclo Básico', '93.07', 'Métodos Numéricos', 3, 0, 2, 2, '71.58 92.03'),
    ('Ciclo Básico', '93.43', 'Física III', 6, 0, 2, 2, '92.03 93.41'),
    ('Ciclo Básico', '21.08', 'Electrotecnia', 6, 0, 3, 1, '93.43'),
    ('Ciclo Básico', '30.25', 'Ciencia de Materiales II', 3, 0, 3, 1, '30.26'),
    ('Ciclo Básico', '30.43', 'Diseño Mecánico III A', 4, 0, 3, 1, '30.42 92.03 93.07 92.04'),
    ('Ciclo Básico', '30.44', 'Diseño Mecánico III B', 4, 0, 3, 1, '92.03 30.42 93.07 92.04'),
    ('Ciclo Básico', '93.61', 'Física IV', 4, 0, 3, 1, '93.42 93.43'),
    ('Ciclo Básico', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, ''),
    ('Ciclo Básico', '30.45', 'Diseño Mecánico IV', 6, 0, 3, 2, '30.41 30.43 30.25 30.44'),
    ('Ciclo Básico', '30.47', 'Termofluidos I', 6, 0, 3, 2, '31.21 92.03 93.42 93.41'),
    ('Ciclo Básico', '93.24', 'Probabilidad y Estadística', 6, 0, 3, 2, '92.02'),
    ('Ciclo Básico', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('Ciclo Básico', '94.51', 'Inglés I', 0, 0, 3, 2, ''),
    ('Ciclo Profesional', '11.15', 'Organización Industrial', 3, 0, 4, 1, '93.24'),
    ('Ciclo Profesional', '23.18', 'Electrónica e Instrumentación', 6, 0, 4, 1, '92.04 21.08'),
    ('Ciclo Profesional', '30.48', 'Termofluidos II', 3, 0, 4, 1, '93.07 30.47'),
    ('Ciclo Profesional', '31.68', 'Instalaciones Industriales', 6, 0, 4, 1, '30.44 30.47'),
    ('Ciclo Profesional', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 1, '93.24'),
    ('Ciclo Profesional', '61.31', 'Derecho para Ingenieros', 3, 144, 4, 1, ''),
    ('Ciclo Profesional', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 0, 4, 2, '30.41 30.42'),
    ('Ciclo Profesional', '23.16', 'Sistemas de Control', 3, 0, 4, 2, '92.04'),
    ('Ciclo Profesional', '30.23', 'Mantenimiento Industrial', 3, 0, 4, 2, '30.43 30.46 30.47'),
    ('Ciclo Profesional', '30.49', 'Máquinas Térmicas e Hidráulicas', 6, 0, 4, 2, '30.47'),
    ('Ciclo Profesional', '61.16', 'Introducción a las Finanzas', 3, 0, 4, 2, '11.15 61.27'),
    ('Ciclo Profesional', '30.80', 'Proyecto Final (Anual)', 6, 192, 5, 1, ''),
    ('Ciclo Profesional', '94.52', 'Inglés II', 0, 0, 5, 1, '94.51'),
    ('Ciclo Profesional', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, ''),
    ('Área Complementaria', '10.09', 'Formación para Emprendedores', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '11.73', 'Teoría de la Decisión', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '61.50', 'Finanzas de la Empresa', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.19', 'Comportamiento Organizacional', 3, 0, NULL, NULL, '11.15'),
    ('Área Complementaria', '94.27', 'Administración de Recursos Humanos', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.40', 'Estructura de las Organizaciones', 3, 0, NULL, NULL, '11.15'),
    ('Área Complementaria', '94.42', 'Comunicación Estratégica', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.61', 'Filosofía', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.62', 'Ética en los Negocios', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.63', 'Epistemología y Heurística', 3, 72, NULL, NULL, ''),
    ('Área Complementaria', '94.64', 'Prácticas Expositivas', 3, 72, NULL, NULL, ''),
    ('Área Tecnológica', '10.08', 'Energías Renovables', 3, 144, NULL, NULL, ''),
    ('Área Tecnológica', '10.12', 'Energías Convencionales', 3, 144, NULL, NULL, ''),
    ('Área Tecnológica', '10.24', 'Economía de la Transición Energética', 3, 144, NULL, NULL, ''),
    ('Área Tecnológica', '11.19', 'Prototipado e Impresión 3D', 3, 72, NULL, NULL, ''),
    ('Área Tecnológica', '12.46', 'Introducción al Proceso de Fabricación de Aceros', 3, 0, NULL, NULL, '31.21 30.25'),
    ('Área Tecnológica', '12.94', 'Introducción a la Ingeniería Nuclear', 3, 0, NULL, NULL, '31.21'),
    ('Área Tecnológica', '16.02', 'Histología y Anatomía', 6, 0, NULL, NULL, '16.55'),
    ('Área Tecnológica', '16.03', 'Fisiología', 6, 0, NULL, NULL, '16.55'),
    ('Área Tecnológica', '16.06', 'Señales y Sistemas', 3, 0, NULL, NULL, '92.04'),
    ('Área Tecnológica', '16.64', 'Mecánica de biomateriales y tejidos', 8, 0, NULL, NULL, '16.03 93.41'),
    ('Área Tecnológica', '16.79', 'Neurociencias', 3, 0, NULL, NULL, '94.43 16.03'),
    ('Área Tecnológica', '16.82', 'Neurociencia Computacional', 3, 0, NULL, NULL, '71.59 92.03 93.24'),
    ('Área Tecnológica', '21.41', 'Instalaciones Eléctricas', 6, 0, NULL, NULL, ''),
    ('Área Tecnológica', '21.73', 'Energías Alternativas', 6, 0, NULL, NULL, '30.49 21.08'),
    ('Área Tecnológica', '22.48', 'Procesamiento de Imágenes', 3, 168, NULL, NULL, ''),
    ('Área Tecnológica', '22.56', 'Sensores y Actuadores', 3, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '22.57', 'Microprocesadores y Control', 6, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '22.90', 'Automación Industrial', 6, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '22.94', 'Control Discreto', 6, 0, NULL, NULL, '22.57'),
    ('Área Tecnológica', '23.07', 'Electrónica Industrial', 3, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '23.19', 'Complementos de Instrumentación y Control', 3, 0, NULL, NULL, ''),
    ('Área Tecnológica', '25.62', 'Electrónica Aeroespacial', 3, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '30.06', 'Motores de Combustión Interna', 4, 0, NULL, NULL, '31.21'),
    ('Área Tecnológica', '30.09', 'Motores de Combustión Interna', 6, 0, NULL, NULL, '31.21'),
    ('Área Tecnológica', '30.12', 'Diseño Mecánico Avanzado', 6, 0, NULL, NULL, '30.48 23.16 23.18 30.45'),
    ('Área Tecnológica', '30.14', 'Mecánica de Fluidos Computacional', 3, 0, NULL, NULL, '30.48'),
    ('Área Tecnológica', '30.15', 'Tecnologías para Energías Renovables', 3, 0, NULL, NULL, '30.47'),
    ('Área Tecnológica', '30.19', 'Introducción a la Dinámica del Automóvil', 3, 0, NULL, NULL, '30.43'),
    ('Área Tecnológica', '30.20', 'Dinámica del Automóvil Avanzada', 3, 0, NULL, NULL, '30.19'),
    ('Área Tecnológica', '30.21', 'Ciclos Reales en Motores de Combustión Interna', 3, 0, NULL, NULL, '30.09'),
    ('Área Tecnológica', '30.22', 'Proceso de Combustión en Motores de Combustión Interna', 3, 0, NULL, NULL, '30.21'),
    ('Área Tecnológica', '30.24', 'Metalurgia Física I', 4, 0, NULL, NULL, '30.25'),
    ('Área Tecnológica', '30.28', 'Accionamientos Industriales', 6, 0, NULL, NULL, '23.16 23.18 30.45 30.47'),
    ('Área Tecnológica', '30.30', 'Transporte Sustentable A', 3, 0, NULL, NULL, '30.49 21.08'),
    ('Área Tecnológica', '30.35', 'Gestión de Proyectos Mecánicos', 3, 168, NULL, NULL, ''),
    ('Área Tecnológica', '30.40', 'Sistemas Mecatrónicos del Automóvil', 4, 0, NULL, NULL, '30.49 23.16 23.18'),
    ('Área Tecnológica', '30.50', 'Mecánica del Continuo', 3, 0, NULL, NULL, '30.42'),
    ('Área Tecnológica', '30.52', 'Mecánica Aplicada', 6, 0, NULL, NULL, '92.02 92.03 93.41'),
    ('Área Tecnológica', '30.53', 'Mecánica de Sólidos Computacional', 4, 0, NULL, NULL, '93.07 30.44'),
    ('Área Tecnológica', '30.54', 'Mecánica de Sólidos Computacional Avanzada', 3, 0, NULL, NULL, '30.53'),
    ('Área Tecnológica', '30.63', 'Cadenas de Valor Circulares', 3, 144, NULL, NULL, ''),
    ('Área Tecnológica', '30.64', 'Bioenergía', 2, 0, NULL, NULL, '31.21 16.55'),
    ('Área Tecnológica', '30.65', 'Energía Eólica', 2, 0, NULL, NULL, '30.48'),
    ('Área Tecnológica', '30.66', 'Energía Geotérmica', 2, 0, NULL, NULL, '31.21 30.47'),
    ('Área Tecnológica', '30.67', 'Energía Hidráulica', 2, 0, NULL, NULL, '30.48'),
    ('Área Tecnológica', '30.68', 'Energía Solar', 2, 0, NULL, NULL, '30.43'),
    ('Área Tecnológica', '30.69', 'Tecnologías del Hidrógeno', 2, 0, NULL, NULL, '31.21 30.49 30.25'),
    ('Área Tecnológica', '31.30', 'Materiales Poliméricos', 3, 0, NULL, NULL, '30.25'),
    ('Área Tecnológica', '31.65', 'Procesos de Manufactura II', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.66', 'Hidráulica, Neumática y PLC', 3, 0, NULL, NULL, '30.43 23.16 23.18 30.47'),
    ('Área Tecnológica', '31.67', 'Procesos de Manufactura I', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.73', 'Aire Acondicionado y Refrigeración', 6, 0, NULL, NULL, '31.21 30.47'),
    ('Área Tecnológica', '31.82', 'Sistemas Mecatrónicos', 3, 0, NULL, NULL, '22.57'),
    ('Área Tecnológica', '31.84', 'Estructuras Automotrices', 3, 0, NULL, NULL, '30.44'),
    ('Área Tecnológica', '31.85', 'Transmisiones Automotrices', 3, 0, NULL, NULL, '30.49 30.45'),
    ('Área Tecnológica', '31.90', 'Integridad Estructural', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.94', 'Tecnología de Materiales Compuestos', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.95', 'Física y Mecánica de Aceros', 3, 0, NULL, NULL, '30.24'),
    ('Área Tecnológica', '31.96', 'Deformación y Fractura de Materiales', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.97', 'Corrosión y Degradación de Materiales', 3, 0, NULL, NULL, '30.25 30.44'),
    ('Área Tecnológica', '31.98', 'Laboratorio Avanzado de Materiales', 3, 0, NULL, NULL, '30.25'),
    ('Área Tecnológica', '32.49', 'Estructura de Buques', 6, 0, NULL, NULL, '30.44'),
    ('Área Tecnológica', '32.54', 'Construcción Naval', 6, 0, NULL, NULL, '30.44 32.66'),
    ('Área Tecnológica', '32.56', 'Alistamiento Naval', 6, 0, NULL, NULL, '31.21 32.66 30.47'),
    ('Área Tecnológica', '32.66', 'Hidrostática y Estabilidad', 6, 0, NULL, NULL, '92.03 93.41 31.08'),
    ('Área Tecnológica', '32.69', 'Resistencia y Propulsión', 6, 0, NULL, NULL, '32.66'),
    ('Área Tecnológica', '33.04', 'Astrodinámica y misiones espaciales', 3, 0, NULL, NULL, '92.02 93.42'),
    ('Área Tecnológica', '33.05', 'Aerodinámica', 6, 0, NULL, NULL, '30.47'),
    ('Área Tecnológica', '33.06', 'Estructuras aeroespaciales', 6, 0, NULL, NULL, '30.44'),
    ('Área Tecnológica', '33.12', 'Sistemas de Propulsión II', 6, 0, NULL, NULL, ''),
    ('Área Tecnológica', '33.13', 'Guiado, Navegación y Control', 6, 0, NULL, NULL, '23.16 23.18'),
    ('Área Tecnológica', '33.14', 'Sistemas de control térmico', 3, 0, NULL, NULL, '31.21 33.04'),
    ('Área Tecnológica', '34.98', 'Baterías y Acumulación de Energía', 1, 0, NULL, NULL, '31.21 12.67 23.18'),
    ('Área Tecnológica', '34.99', 'Energía Solar Fotovoltaica, aplicaciones terrestres y espaciales', 1, 0, NULL, NULL, '23.18'),
    ('Área Tecnológica', '72.31', 'Programación Imperativa', 9, 0, NULL, NULL, '71.58 93.18'),
    ('Área Tecnológica', '72.33', 'Programación Orientada a Objetos', 6, 0, NULL, NULL, '72.31'),
    ('Área Tecnológica', '72.90', 'Internet de las Cosas (IoT)', 3, 0, NULL, NULL, '93.42 93.07'),
    ('Área Tecnológica', '73.70', 'Análisis de datos en neurociencias', 3, 0, NULL, NULL, ''),
    ('Área Tecnológica', '92.90', 'Complementos de Matemática', 3, 144, NULL, NULL, ''),
    ('Área Tecnológica', '92.91', 'Complementos de Física', 2, 0, NULL, NULL, ''),
    ('Área Tecnológica', '92.92', 'Complementos de Física de la Relatividad', 2, 0, NULL, NULL, ''),
    ('Área Tecnológica', '92.93', 'Complementos de Química', 1, 0, NULL, NULL, ''),
    ('Área Tecnológica', '93.75', 'Métodos Numéricos Avanzados', 6, 0, NULL, NULL, '93.07');

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

-- Huecos de electivas: en la grilla del bloque obligatorio, o dentro
-- de un bloque de electivas que agrupa a otros (contenedor)
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos, contenedor_bloque_id)
SELECT b.id, h.anio, h.cuatri, h.creditos, c.id
FROM nuevo_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id
JOIN (VALUES
    ('Materias electivas', 5, 2, 42, NULL),
    ('Área Complementaria', NULL::SMALLINT, NULL::SMALLINT, 3, 'Materias electivas'),
    ('Área Tecnológica', NULL::SMALLINT, NULL::SMALLINT, 36, 'Materias electivas')
) AS h (bloque, anio, cuatri, creditos, contenedor) ON h.bloque = b.nombre
LEFT JOIN sga.plan_bloque c ON c.plan_id = p.id AND c.nombre = h.contenedor
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
    ('Principal', 'Ingeniero/a Mecánico/a', 'Aprobar M22-Marzo y sumar 240 créditos')
) AS t (tipo, nombre, requisito)
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: 141 materias, 240 créditos en los bloques obligatorios
-- (materias + huecos) y 186 correlativas según el SGA.
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'M22') AS materias,
    (SELECT coalesce(sum(m.creditos), 0) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'M22' AND b.requisito = 'APROBAR_TODOS')
    + (SELECT coalesce(sum(h.creditos), 0) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'M22' AND h.contenedor_bloque_id IS NULL) AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'M22') AS correlativas;
