-- =====================================================================
-- Plan E 11 de Ingeniería Electricista, transcripto del "Detalle de Planes de
-- estudio" del SGA actual. Correr DESPUÉS de seed.sql (como
-- seed_plan_a22.sql).
--
-- La correlativa 31.17 de 31.27 no es del plan ni está en el catálogo:
-- queda afuera hasta saber qué materia es.
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
SELECT id, 'E 11', 1, 240, DATE '2011-03-01', NULL
FROM sga.carrera WHERE codigo = 'E'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE e11_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'E' AND p.codigo = 'E 11';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM e11_plan p
CROSS JOIN (VALUES
    ('Ciclo Básico',      'APROBAR_TODOS',   147, 1),
    ('Ciclo Profesional', 'APROBAR_TODOS',    93, 2),
    ('Electivas',         'JUNTAR_CREDITOS',   3, 3)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE e11_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO e11_materias VALUES
    -- Ciclo Básico
    ('Ciclo Básico', '12.01', 'Química I', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '22.06', 'Introducción a la Computación', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '93.17', 'Matemática I', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('Ciclo Básico', '22.07', 'Programación I', 6, 0, 1, 2, '22.06'),
    ('Ciclo Básico', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '93.02', 'Matemática II', 6, 0, 1, 2, '93.18 93.17'),
    ('Ciclo Básico', '93.41', 'Física I', 6, 0, 1, 2, '93.17'),
    ('Ciclo Básico', '94.21', 'Formación General I', 3, 0, 1, 2, ''),
    ('Ciclo Básico', '31.19', 'Estática y Resistencia de Materiales', 6, 0, 2, 1, '93.02 93.41 31.08'),
    ('Ciclo Básico', '93.03', 'Matemática III', 6, 0, 2, 1, '93.18 93.17'),
    ('Ciclo Básico', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 1, '93.02'),
    ('Ciclo Básico', '93.42', 'Física II', 6, 0, 2, 1, '93.02'),
    ('Ciclo Básico', '31.21', 'Termodinámica', 6, 0, 2, 2, '93.42'),
    ('Ciclo Básico', '93.07', 'Métodos Numéricos', 3, 0, 2, 2, '93.03'),
    ('Ciclo Básico', '93.43', 'Física III', 6, 0, 2, 2, '93.03 93.41'),
    ('Ciclo Básico', '93.65', 'Matemática IV', 6, 0, 2, 2, '93.02 93.03'),
    ('Ciclo Básico', '94.24', 'Metodología del Aprendizaje', 3, 0, 2, 2, ''),
    ('Ciclo Básico', '21.32', 'Tecnología de Mat. Eléctricos', 6, 0, 3, 1, '93.65 93.43'),
    ('Ciclo Básico', '21.71', 'Electrotecnia I', 6, 0, 3, 1, '93.65'),
    ('Ciclo Básico', '22.08', 'Algoritmos y Estructura de Datos', 6, 0, 3, 1, '93.02 22.07'),
    ('Ciclo Básico', '93.44', 'Física IV', 6, 0, 3, 1, '93.42 93.43'),
    ('Ciclo Básico', '21.74', 'Instrumentos y Mediciones Eléctricas', 3, 0, 3, 2, '21.71'),
    ('Ciclo Básico', '21.80', 'Máquinas Eléctricas I', 6, 0, 3, 2, '21.71 21.32'),
    ('Ciclo Básico', '22.20', 'Electrónica General', 3, 0, 3, 2, '21.71'),
    ('Ciclo Básico', '22.37', 'Electromagnetismo', 3, 0, 3, 2, '93.65 93.43'),
    ('Ciclo Básico', '22.42', 'Laboratorio de Electrónica', 6, 0, 3, 2, '21.71'),
    ('Ciclo Básico', '31.24', 'Mecánica de Fluidos', 3, 0, 3, 2, '93.65'),
    ('Ciclo Básico', '31.27', 'Mecanismos y Elementos de Máquinas', 3, 0, 3, 2, '31.17'),
    ('Ciclo Básico', '94.51', 'Inglés I', 0, 0, 3, 2, ''),
    -- Ciclo Profesional
    ('Ciclo Profesional', '11.15', 'Organización Industrial', 3, 0, 4, 1, '93.24'),
    ('Ciclo Profesional', '21.79', 'Electrotecnia II', 3, 0, 4, 1, '21.71'),
    ('Ciclo Profesional', '21.81', 'Máquinas Eléctricas II', 6, 0, 4, 1, '21.80'),
    ('Ciclo Profesional', '22.58', 'Instrumentación y Control', 6, 0, 4, 1, '22.20'),
    ('Ciclo Profesional', '31.38', 'Turbomáquinas', 6, 0, 4, 1, '31.21 31.24'),
    ('Ciclo Profesional', '21.65', 'Instalaciones Eléctricas y Luminotecnia', 6, 0, 4, 2, '21.81'),
    ('Ciclo Profesional', '21.82', 'Centrales Eléctricas', 6, 0, 4, 2, '21.74 22.58 21.81'),
    ('Ciclo Profesional', '21.83', 'Transmisión de la Energía Eléctrica', 6, 0, 4, 2, '21.79 22.37'),
    ('Ciclo Profesional', '61.23', 'Economía para Ingenieros', 3, 0, 4, 2, '93.24'),
    ('Ciclo Profesional', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 0, 5, 1, '21.71'),
    ('Ciclo Profesional', '21.45', 'Eficiencia Energética', 3, 0, 5, 1, '21.65'),
    ('Ciclo Profesional', '21.84', 'Proyecto Final', 6, 0, 5, 1, '21.83 21.82 21.65'),
    ('Ciclo Profesional', '21.85', 'Sistemas Eléctricos de Potencia', 6, 0, 5, 1, '21.83 21.81'),
    ('Ciclo Profesional', '21.86', 'Diseño de Líneas de Transmisión y Estaciones Transformadoras', 6, 0, 5, 1, '21.83'),
    ('Ciclo Profesional', '22.28', 'Electrónica de Potencia', 3, 0, 5, 1, '22.20'),
    ('Ciclo Profesional', '21.72', 'Mantenimiento de Máquinas e Instalaciones Eléctricas', 3, 0, 5, 2, '21.65 21.81'),
    ('Ciclo Profesional', '21.73', 'Energías Alternativas', 6, 0, 5, 2, '21.82 21.65'),
    ('Ciclo Profesional', '21.87', 'Mercado Eléctrico', 3, 0, 5, 2, '21.83 61.23'),
    ('Ciclo Profesional', '21.88', 'Distribución de la Energía Eléctrica', 3, 0, 5, 2, '21.83 21.65'),
    ('Ciclo Profesional', '21.98', 'Práctica Laboral', 0, 0, 5, 2, ''),
    ('Ciclo Profesional', '61.31', 'Derecho para Ingenieros', 3, 144, 5, 2, ''),
    ('Ciclo Profesional', '94.52', 'Inglés II', 0, 0, 5, 2, '94.51'),
    -- Electivas
    ('Electivas', '94.23', 'Formación General III', 3, 0, NULL, NULL, '94.21');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM e11_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM e11_materias m
CROSS JOIN e11_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 4, 2, 3
FROM e11_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'Electivas'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM e11_materias m
CROSS JOIN e11_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Ingeniero Electricista', 'Aprobar E 11 y sumar 240 créditos'
FROM e11_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: los dos ciclos deben sumar 240 créditos (materias + hueco)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'E 11') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'E 11' AND b.requisito = 'APROBAR_TODOS')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'E 11') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'E 11') AS correlativas;
