-- =====================================================================
-- Plan K22 de Ingeniería Electrónica, transcripto del "Detalle de Planes de
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
SELECT id, 'K22', 1, 240, DATE '2023-03-01', DATE '2024-02-01'
FROM sga.carrera WHERE codigo = 'K'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

CREATE TEMP TABLE k22_plan ON COMMIT DROP AS
SELECT p.id FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'K' AND p.codigo = 'K22';

INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, orden)
SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.orden
FROM k22_plan p
CROSS JOIN (VALUES
    ('Ciclo Basico', 'APROBAR_TODOS',   240, 1),
    ('ELECTIVAS',    'JUNTAR_CREDITOS',  27, 2)
) AS b (nombre, requisito, creditos, orden)
ON CONFLICT (plan_id, nombre) DO NOTHING;

-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,
-- correlativas (códigos separados por espacio)
CREATE TEMP TABLE k22_materias (
    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,
    anio SMALLINT, cuatri SMALLINT, correlativas TEXT
) ON COMMIT DROP;

INSERT INTO k22_materias VALUES
    -- Ciclo Basico
    ('Ciclo Basico', '12.67', 'Química General', 6, 0, 1, 1, ''),
    ('Ciclo Basico', '71.93', 'Principios de Informática', 3, 0, 1, 1, ''),
    ('Ciclo Basico', '92.01', 'Análisis Matemático I', 6, 0, 1, 1, ''),
    ('Ciclo Basico', '93.18', 'Álgebra Lineal', 6, 0, 1, 1, ''),
    ('Ciclo Basico', '94.33', 'Tecnología y Sociedad', 3, 0, 1, 1, ''),
    ('Ciclo Basico', '25.01', 'Fundamentos de Electrónica', 3, 0, 1, 2, '71.93'),
    ('Ciclo Basico', '25.02', 'Programación I', 6, 0, 1, 2, '71.93'),
    ('Ciclo Basico', '31.08', 'Sistemas de Representación', 3, 0, 1, 2, ''),
    ('Ciclo Basico', '92.02', 'Análisis Matemático II', 6, 0, 1, 2, '92.01 93.18'),
    ('Ciclo Basico', '93.41', 'Física I', 6, 0, 1, 2, '92.01'),
    ('Ciclo Basico', '25.03', 'Algoritmos y Estructuras de Datos', 3, 0, 2, 1, '25.02'),
    ('Ciclo Basico', '92.03', 'Análisis Matemático III', 6, 0, 2, 1, '92.01 93.18'),
    ('Ciclo Basico', '93.16', 'Matemática Discreta', 3, 0, 2, 1, '93.18'),
    ('Ciclo Basico', '93.24', 'Probabilidad y Estadística', 6, 0, 2, 1, '92.02'),
    ('Ciclo Basico', '93.42', 'Física II', 6, 0, 2, 1, '92.02'),
    ('Ciclo Basico', '16.55', 'Biología', 3, 0, 2, 2, ''),
    ('Ciclo Basico', '25.10', 'Teoría de Circuitos 1', 6, 0, 2, 2, '92.03 25.01'),
    ('Ciclo Basico', '92.04', 'Análisis Matemático IV', 6, 0, 2, 2, '92.02 92.03'),
    ('Ciclo Basico', '93.07', 'Métodos Numéricos', 3, 0, 2, 2, '92.03 93.24'),
    ('Ciclo Basico', '93.43', 'Física III', 6, 0, 2, 2, '92.03 93.41'),
    ('Ciclo Basico', '25.12', 'Tecnología de Materiales Electrónicos', 4, 0, 3, 1, '93.42 25.10'),
    ('Ciclo Basico', '25.13', 'Laboratorio de Electrónica 1', 6, 0, 3, 1, '25.10'),
    ('Ciclo Basico', '25.18', 'Física Electrónica', 3, 0, 3, 1, '92.04 25.10'),
    ('Ciclo Basico', '92.07', 'Análisis Matemático V', 4, 0, 3, 1, '92.04'),
    ('Ciclo Basico', '93.61', 'Física IV', 4, 0, 3, 1, '93.42 93.43'),
    ('Ciclo Basico', '94.43', 'Metodología del Diseño', 3, 72, 3, 1, '93.24'),
    ('Ciclo Basico', '25.14', 'Teoría de Circuitos 2', 6, 0, 3, 2, '25.10 25.12 92.07'),
    ('Ciclo Basico', '25.15', 'Electrónica I', 6, 0, 3, 2, '25.18'),
    ('Ciclo Basico', '25.16', 'Laboratorio de Electrónica 2', 3, 0, 3, 2, '25.13'),
    ('Ciclo Basico', '25.17', 'Electrónica II', 6, 0, 3, 2, '25.13'),
    ('Ciclo Basico', '94.44', 'Proyecto Interdisciplinario', 3, 0, 3, 2, '94.43'),
    ('Ciclo Basico', '94.51', 'Inglés I', 0, 0, 3, 2, ''),
    ('Ciclo Basico', '25.20', 'Análisis de Señales y Sistemas Digitales', 6, 0, 4, 1, '93.24 25.14'),
    ('Ciclo Basico', '25.21', 'Electrónica III', 4, 0, 4, 1, '25.15'),
    ('Ciclo Basico', '25.22', 'Electromagnetismo', 4, 0, 4, 1, '93.43 92.07'),
    ('Ciclo Basico', '25.23', 'Sistemas de Control', 6, 0, 4, 1, '92.07'),
    ('Ciclo Basico', '25.24', 'Laboratorio de Electrónica 3', 4, 0, 4, 1, '25.16'),
    ('Ciclo Basico', '11.15', 'Organización Industrial', 3, 0, 4, 2, '93.24'),
    ('Ciclo Basico', '25.26', 'Transmisión de la Información', 6, 0, 4, 2, '25.22 25.20'),
    ('Ciclo Basico', '25.27', 'Sistemas Embebidos', 6, 0, 4, 2, '25.17 25.16 25.03'),
    ('Ciclo Basico', '25.28', 'Electrónica IV', 4, 0, 4, 2, '25.24 25.23 25.12'),
    ('Ciclo Basico', '61.27', 'Análisis de Coyuntura Económica', 3, 0, 4, 2, '93.24'),
    ('Ciclo Basico', '12.83', 'Seguridad Ocupacional y Ambiental', 3, 120, 5, 1, ''),
    ('Ciclo Basico', '25.30', 'Electrónica V', 4, 0, 5, 1, '25.27'),
    ('Ciclo Basico', '25.31', 'Proyectos Electrónicos', 4, 168, 5, 1, ''),
    ('Ciclo Basico', '25.32', 'Proyecto Integrador (anual) (Anual)', 6, 168, 5, 1, ''),
    ('Ciclo Basico', '61.16', 'Introducción a las Finanzas', 3, 0, 5, 1, '11.15 61.27'),
    ('Ciclo Basico', '61.31', 'Derecho para Ingenieros', 3, 144, 5, 2, ''),
    ('Ciclo Basico', '94.52', 'Inglés II', 0, 0, 5, 2, '94.51'),
    ('Ciclo Basico', '94.65', 'Practica Profesional supervisada', 0, 144, 5, 2, ''),
    -- ELECTIVAS
    ('ELECTIVAS', '10.07', 'Creatividad', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '10.09', 'Formación para Emprendedores', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '11.34', 'Taller de Modelización de Productos', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '12.02', 'Química II', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '14.72', 'Analytics', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '14.89', 'Ventas', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '15.09', 'Agile, Lean y Lean Six Sigma', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '15.79', 'Metodología de la Investigación', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '16.04', 'Neurociencias y Desarrollo Productivo', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '16.87', 'Microfabricación', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.22', 'Antenas y Radiopropagación', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.29', 'Microondas', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.46', 'Procesamiento Adaptativo de Señales', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.47', 'Procesamiento de Voz', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.48', 'Procesamiento de Imágenes', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.64', 'Comunicaciones Digitales', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.66', 'Redes Digitales', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.88', 'Sensores y Actuadores', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.90', 'Automación Industrial', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '22.93', 'Control Automático', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '23.05', 'Acústica para Ingenieros', 3, 0, NULL, NULL, '92.07'),
    ('ELECTIVAS', '23.10', 'Formación General II', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.04', 'Computación Cuántica', 6, 144, NULL, NULL, ''),
    ('ELECTIVAS', '25.40', 'Transmisión Digital y Codificación', 3, 0, NULL, NULL, '25.26'),
    ('ELECTIVAS', '25.41', 'Sistemas de Comunicaciones de Datos', 3, 0, NULL, NULL, '25.26'),
    ('ELECTIVAS', '25.42', 'Análisis de Sistemas Estocásticos', 3, 0, NULL, NULL, '25.26'),
    ('ELECTIVAS', '25.43', 'Laboratorio de Procesamiento de Señales', 3, 144, NULL, NULL, '25.20'),
    ('ELECTIVAS', '25.51', 'Electrónica aplicada a Movilidad Eléctrica', 4, 96, NULL, NULL, ''),
    ('ELECTIVAS', '25.52', 'Electrónica de Potencia', 4, 0, NULL, NULL, '25.28'),
    ('ELECTIVAS', '25.53', 'Señales Aleatorias', 4, 0, NULL, NULL, '25.26'),
    ('ELECTIVAS', '25.54', 'Física Electrónica', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.55', 'Microelectrónica', 3, 0, NULL, NULL, '25.17 25.15'),
    ('ELECTIVAS', '25.56', 'Diseño Físico de Circuitos Integrados', 3, 0, NULL, NULL, '25.55'),
    ('ELECTIVAS', '25.57', 'Diseño Analógico de Circuitos Integrados (Anual)', 6, 0, NULL, NULL, '25.56'),
    ('ELECTIVAS', '25.59', 'Dispositivos Lógicos Programables', 3, 0, NULL, NULL, '25.56'),
    ('ELECTIVAS', '25.60', 'Control Avanzado', 3, 0, NULL, NULL, '25.23'),
    ('ELECTIVAS', '25.61', 'Tecnologías para el agro', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '25.62', 'Electrónica Aeroespacial', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '25.63', 'Redes Neuronales', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '25.64', 'Deep Learning', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '25.65', 'Realidad Virtual', 3, 0, NULL, NULL, '93.18 25.03'),
    ('ELECTIVAS', '25.66', 'Acústica para Ingenieros', 3, 0, NULL, NULL, '92.07'),
    ('ELECTIVAS', '25.67', 'Laboratorio de Dsp_fpga', 6, 0, NULL, NULL, '25.17 25.20'),
    ('ELECTIVAS', '25.68', 'Electrónica aplicada a Energías alternativas', 3, 0, NULL, NULL, '25.28'),
    ('ELECTIVAS', '25.70', 'Diseño analógico de circuitos integrados', 6, 0, NULL, NULL, '25.56'),
    ('ELECTIVAS', '25.71', 'Diseño analógico de Sistemas integrados', 6, 0, NULL, NULL, '25.70'),
    ('ELECTIVAS', '25.72', 'Diseño digital de circuitos integrados', 6, 0, NULL, NULL, '25.56'),
    ('ELECTIVAS', '25.73', 'Verificación de Circuitos Digitales Integrados', 6, 0, NULL, NULL, '25.72'),
    ('ELECTIVAS', '25.74', 'Verificación de Sistemas Digitales', 3, 0, NULL, NULL, '25.18'),
    ('ELECTIVAS', '25.80', 'Introducción a la programación orientada a objetos', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.81', 'Principios de Electrotecnia', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.82', 'Circuitos de Audio', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.83', 'Guías de ondas', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.84', 'Convertidores de potencia', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.85', 'Programación en bajo nivel', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.86', 'Procesamiento Avanzado de Señales', 3, 0, NULL, NULL, '25.53'),
    ('ELECTIVAS', '25.87', 'Redes Neuronales II', 3, 0, NULL, NULL, '25.63'),
    ('ELECTIVAS', '25.88', 'Redes Neuronales III', 3, 0, NULL, NULL, '25.63'),
    ('ELECTIVAS', '25.89', 'Laboratorio de simulaciones de señales aleatorias', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '25.90', 'Sistemas de energía espaciales', 3, 144, NULL, NULL, '25.15'),
    ('ELECTIVAS', '31.81', 'Tecnología de Máquinas', 6, 0, NULL, NULL, ''),
    ('ELECTIVAS', '31.99', 'Mecatrónica Aplicada', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '34.99', 'Energía Solar Fotovoltaica, aplicaciones terrestres y espaciales', 1, 144, NULL, NULL, ''),
    ('ELECTIVAS', '72.75', 'Aprendizaje Automático (Machine Learning)', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '73.67', 'Análisis de series de tiempo con Inteligencia Artificial', 1, 0, NULL, NULL, '72.75'),
    ('ELECTIVAS', '81.83', 'Tecnología e Innovación Aplicada a la Industria', 1, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.92', 'Complementos de Física de la Relatividad', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '92.97', 'Complementos de Matemática V', 2, 0, NULL, NULL, ''),
    ('ELECTIVAS', '94.24', 'Metodología del Aprendizaje', 3, 0, NULL, NULL, ''),
    ('ELECTIVAS', '94.42', 'Comunicación Estratégica', 3, 96, NULL, NULL, ''),
    ('ELECTIVAS', '94.78', 'Gestión de Capital Emprendedor y Venture Capital', 1, 0, NULL, NULL, '10.09');

-- Materias (las que ya existían conservan su departamento)
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT m.codigo, m.nombre, d.id, m.creditos
FROM k22_materias m
JOIN sga.departamento d ON d.nombre = 'A confirmar'
ON CONFLICT (codigo) DO NOTHING;

-- Ubicación de cada materia en el plan
INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)
SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos
FROM k22_materias m
CROSS JOIN k22_plan p
JOIN sga.materia ma ON ma.codigo = m.codigo
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque
ON CONFLICT (plan_id, materia_id) DO UPDATE
SET bloque_id = EXCLUDED.bloque_id,
    anio_sugerido = EXCLUDED.anio_sugerido,
    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,
    creditos_requeridos = EXCLUDED.creditos_requeridos;

-- Hueco de electivas en la grilla del plan
INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)
SELECT b.id, 5, 2, 27
FROM k22_plan p
JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = 'ELECTIVAS'
ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;

-- Correlativas del plan (para cursar, con la correlativa regular)
INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)
SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'
FROM k22_materias m
CROSS JOIN k22_plan p
CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)
JOIN sga.materia ma  ON ma.codigo = m.codigo
JOIN sga.materia req ON req.codigo = c.codigo
ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT id, 'Principal', 'Ingeniero/a Electrónico/a', 'Aprobar K22 y sumar 240 créditos'
FROM k22_plan
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;

-- Control: el bloque Ciclo Basico debe sumar 240 créditos (materias + huecos)
SELECT
    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = 'K22') AS materias,
    (SELECT sum(m.creditos) FROM sga.plan_materia pm
        JOIN sga.plan_estudio p ON p.id = pm.plan_id
        JOIN sga.plan_bloque b ON b.id = pm.bloque_id
        JOIN sga.materia m ON m.id = pm.materia_id
        WHERE p.codigo = 'K22' AND b.nombre = 'Ciclo Basico')
    + (SELECT sum(h.creditos) FROM sga.plan_hueco_electiva h
        JOIN sga.plan_bloque b ON b.id = h.bloque_id
        JOIN sga.plan_estudio p ON p.id = b.plan_id
        WHERE p.codigo = 'K22') AS creditos_plan,
    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = 'K22') AS correlativas;
