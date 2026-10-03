-- =====================================================================
-- Legajo de demo de la alumna (correr DESPUÉS de seed.sql y
-- seed_usuarios.sql). Completa todas las solapas de "Mi legajo":
-- títulos, historial de actividades, cursadas anteriores con finales,
-- inhibiciones, excepciones, exámenes habilitados, documentación,
-- facturables, facturas y pagos.
--
-- Se puede correr más de una vez: cada bloque se saltea si ya cargó.
-- =====================================================================

BEGIN;

CREATE TEMP TABLE demo_legajo ON COMMIT DROP AS
SELECT l.id, l.plan_estudio_id FROM sga.legajo l WHERE l.numero_legajo = 'DEMO-001';

-- La alumna ingresó en el segundo cuatrimestre de 2025
UPDATE sga.legajo SET fecha_registracion = DATE '2025-08-01'
WHERE numero_legajo = 'DEMO-001' AND fecha_registracion <> DATE '2025-08-01';

-- Datos personales que en seed_usuarios.sql quedaron vacíos
UPDATE sga.persona
SET fecha_nacimiento = DATE '2006-06-23',
    lugar_nacimiento = 'Ciudad Autónoma de Buenos Aires',
    genero = 'MUJER',
    nacionalidad = 'Argentina'
WHERE mail_institucional = 'alumno.demo@itba.edu.ar'
  AND fecha_nacimiento IS NULL;

-- Títulos previos
INSERT INTO sga.titulo_previo (legajo_id, fecha, titulo, institucion, pais, nivel, descripcion)
SELECT id, DATE '2024-12-15', 'Bachiller', 'Escuela Secundaria de Demo', 'Argentina', 'Secundario', 'Título de ingreso'
FROM demo_legajo
WHERE NOT EXISTS (SELECT 1 FROM sga.titulo_previo t JOIN demo_legajo d ON t.legajo_id = d.id);

-- Historial de actividades
INSERT INTO sga.hito_academico (legajo_id, tipo, descripcion, fecha_evento)
SELECT d.id, h.tipo, h.descripcion, h.fecha
FROM demo_legajo d
CROSS JOIN (VALUES
    ('Ingreso',         'Aprobó el curso de ingreso',                          DATE '2025-03-01'),
    ('Inicio de plan',  'Inicio de estudios en el plan INF-2023 (Ingeniería en Informática)', DATE '2025-08-01')
) AS h (tipo, descripcion, fecha)
WHERE NOT EXISTS (SELECT 1 FROM sga.hito_academico x JOIN demo_legajo d2 ON x.legajo_id = d2.id);

-- Cursos de períodos anteriores (2025-2C y 2026-1C) con sus comisiones,
-- horarios y mesas de final
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT m.id, x.anio, x.periodo, x.inicio, x.fin
FROM (VALUES
    ('93.58', 2025, '2C', DATE '2025-08-11', DATE '2025-12-05'),
    ('93.59', 2025, '2C', DATE '2025-08-11', DATE '2025-12-05'),
    ('72.31', 2026, '1C', DATE '2026-03-09', DATE '2026-07-03')
) AS x (codigo, anio, periodo, inicio, fin)
JOIN sga.materia m ON m.codigo = x.codigo
ON CONFLICT (materia_id, anio, periodo) DO NOTHING;

INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A'
FROM sga.curso c
WHERE (c.anio, c.periodo) IN ((2025, '2C'), (2026, '1C'))
ON CONFLICT (curso_id, nombre) DO NOTHING;

INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin)
SELECT c.id, f.fecha, '09:00', '12:00'
FROM sga.curso c
JOIN sga.materia m ON m.id = c.materia_id
JOIN (VALUES
    ('93.58', 2025, '2C', DATE '2025-12-15'),
    ('93.59', 2025, '2C', DATE '2025-12-16'),
    ('93.59', 2025, '2C', DATE '2026-02-20')
) AS f (codigo, anio, periodo, fecha)
  ON f.codigo = m.codigo AND f.anio = c.anio AND f.periodo = c.periodo
WHERE NOT EXISTS (
    SELECT 1 FROM sga.examen_final ef WHERE ef.curso_id = c.id AND ef.fecha = f.fecha
);

-- Cursadas de la alumna
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado, nota_cursada, fecha_carga_cursada)
SELECT d.id, c.id, co.id, x.estado::sga.estado_inscripcion_curso, x.nota, x.fecha
FROM demo_legajo d
CROSS JOIN (VALUES
    ('93.58', 2025, '2C', 'CURSANDO',         8.00, TIMESTAMP '2025-12-01 10:00'),
    ('93.59', 2025, '2C', 'CURSANDO',         6.00, TIMESTAMP '2025-12-01 10:00'),
    ('72.31', 2026, '1C', 'CURSADA_APROBADA', 9.00, TIMESTAMP '2026-07-01 10:00')
) AS x (codigo, anio, periodo, estado, nota, fecha)
JOIN sga.materia m   ON m.codigo = x.codigo
JOIN sga.curso c     ON c.materia_id = m.id AND c.anio = x.anio AND c.periodo = x.periodo
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

-- Finales: Análisis aprueba con 7; Álgebra desaprueba (3) y después
-- aprueba (5). Los triggers calculan nota definitiva y rendimiento.
-- (NOT EXISTS y no ON CONFLICT: el trigger que valida intentos rechaza
-- la fila antes de que ON CONFLICT pueda ignorarla.)
INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento, nota_final, fecha_carga_final)
SELECT ic.id, ef.id, x.intento, x.nota, x.fecha::timestamp
FROM (VALUES
    ('93.58', DATE '2025-12-15', 1, 7.00),
    ('93.59', DATE '2025-12-16', 1, 3.00),
    ('93.59', DATE '2026-02-20', 2, 5.00)
) AS x (codigo, fecha, intento, nota)
JOIN sga.materia m           ON m.codigo = x.codigo
JOIN sga.curso c             ON c.materia_id = m.id AND c.anio = 2025 AND c.periodo = '2C'
JOIN sga.inscripcion_curso ic ON ic.curso_id = c.id
JOIN demo_legajo d           ON d.id = ic.legajo_id
JOIN sga.examen_final ef     ON ef.curso_id = c.id AND ef.fecha = x.fecha
WHERE NOT EXISTS (
    SELECT 1 FROM sga.inscripcion_examen_final ief
    WHERE ief.inscripcion_curso_id = ic.id AND ief.numero_intento = x.intento
)
ORDER BY x.codigo, x.intento;

-- Inhibiciones y excepciones
INSERT INTO sga.inhibicion (legajo_id, tipo, fecha_inicio, fecha_fin, observaciones)
SELECT d.id, x.tipo::sga.tipo_inhibicion, x.desde, x.hasta, x.obs
FROM demo_legajo d
CROSS JOIN (VALUES
    ('ENCUESTA', DATE '2025-12-10', DATE '2025-12-12', 'Encuesta de alumnos sin completar'),
    ('ARANCEL',  DATE '2026-07-15', DATE '2026-07-20', 'Cuota de julio impaga')
) AS x (tipo, desde, hasta, obs)
WHERE NOT EXISTS (SELECT 1 FROM sga.inhibicion i JOIN demo_legajo d2 ON i.legajo_id = d2.id);

INSERT INTO sga.excepcion (legajo_id, tipo, descripcion, fecha)
SELECT id, 'Correlativa', 'Se autoriza cursar 72.40 sin el final de 72.31 aprobado', DATE '2026-08-05'
FROM demo_legajo
WHERE NOT EXISTS (SELECT 1 FROM sga.excepcion e JOIN demo_legajo d ON e.legajo_id = d.id);

-- Exámenes especiales (catálogo) e intentos de la alumna
INSERT INTO sga.examen_especial (codigo, nombre, intentos_maximos, vigencia_meses) VALUES
    ('72.98', 'Práctica Laboral', 1, NULL),
    ('94.50', 'Castellano',       3, NULL),
    ('94.51', 'Inglés I',         3, 24),
    ('94.52', 'Inglés II',        3, 24)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO sga.examen_especial_intento (legajo_id, examen_especial_id, numero_intento, fecha, nota, aprobado, fecha_vencimiento)
SELECT d.id, e.id, 1, DATE '2025-09-10', 8.00, TRUE, DATE '2027-09-10'
FROM demo_legajo d
JOIN sga.examen_especial e ON e.codigo = '94.51'
ON CONFLICT (legajo_id, examen_especial_id, numero_intento) DO NOTHING;

-- Documentación requerida (catálogo) y lo que entregó la alumna
INSERT INTO sga.documento_requerido (nombre, categoria, obligatoria) VALUES
    ('Fotocopia del DNI',                         'Académica', TRUE),
    ('Certificado del título secundario',         'Académica', TRUE),
    ('Código de Conducta',                        'Académica', TRUE),
    ('Certificado médico apto físico',            'Académica', FALSE),
    ('Foto 4x4',                                  'Académica', FALSE),
    ('Adhesión a la Política de Propiedad Intelectual', 'Académica', FALSE)
ON CONFLICT (carrera_id, nivel, nombre) DO NOTHING;

INSERT INTO sga.documento_legajo (legajo_id, documento_requerido_id, nombre_archivo, estado, fecha_carga)
SELECT d.id, dr.id, x.archivo, x.estado::sga.estado_documento, TIMESTAMP '2025-03-01 12:00'
FROM demo_legajo d
CROSS JOIN (VALUES
    ('Fotocopia del DNI',                 'DNI.png',               'VALIDADO'),
    ('Certificado del título secundario', 'Titulo_secundario.pdf', 'VALIDADO'),
    ('Foto 4x4',                          'Foto.jpg',              'CARGADO')
) AS x (nombre, archivo, estado)
JOIN sga.documento_requerido dr ON dr.nombre = x.nombre AND dr.carrera_id IS NULL
ON CONFLICT (legajo_id, documento_requerido_id) DO NOTHING;

-- Ítems facturables: el trigger los activa para todos los legajos al
-- crearlos; CEITBA se da de baja para la alumna
INSERT INTO sga.item_facturable (codigo, nombre, monto) VALUES
    ('ADITBA', 'ADITBA (Padre)', 1500),
    ('CEITBA', 'CEITBA',         2000)
ON CONFLICT (codigo) DO NOTHING;

UPDATE sga.item_facturable_legajo ifl
SET activo = FALSE, fecha_hasta = DATE '2026-03-01', motivo_baja = 'Baja solicitada por la alumna'
FROM sga.item_facturable i, demo_legajo d
WHERE ifl.item_facturable_id = i.id AND ifl.legajo_id = d.id
  AND i.codigo = 'CEITBA' AND ifl.activo;

-- Facturas de julio y agosto, pagadas con órdenes de pago
INSERT INTO sga.factura (legajo_id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos, monto_total, fecha_emision, fecha_vencimiento)
SELECT d.id, x.periodo, 6, 72004, 432024, 432024, x.emision, x.vence
FROM demo_legajo d
CROSS JOIN (VALUES
    ('2026-07', DATE '2026-07-01', DATE '2026-07-10'),
    ('2026-08', DATE '2026-08-03', DATE '2026-08-12')
) AS x (periodo, emision, vence)
ON CONFLICT (legajo_id, periodo) DO NOTHING;

INSERT INTO sga.orden_pago (legajo_id, monto_total, fecha_creacion)
SELECT f.legajo_id, f.monto_total, f.fecha_emision
FROM sga.factura f
JOIN demo_legajo d ON d.id = f.legajo_id
WHERE f.estado = 'PENDIENTE'
  AND NOT EXISTS (SELECT 1 FROM sga.orden_pago_factura opf WHERE opf.factura_id = f.id);

INSERT INTO sga.orden_pago_factura (orden_pago_id, factura_id)
SELECT op.id, f.id
FROM sga.factura f
JOIN demo_legajo d ON d.id = f.legajo_id
JOIN sga.orden_pago op ON op.legajo_id = f.legajo_id
     AND op.fecha_creacion::date = f.fecha_emision AND op.estado = 'PENDIENTE'
WHERE NOT EXISTS (SELECT 1 FROM sga.orden_pago_factura opf WHERE opf.factura_id = f.id);

-- Confirmar los pagos (el trigger pasa las facturas a PAGADA)
UPDATE sga.orden_pago op
SET estado = 'PAGADO',
    fecha_pago = op.fecha_creacion + INTERVAL '9 days'
FROM demo_legajo d
WHERE op.legajo_id = d.id AND op.estado = 'PENDIENTE';

COMMIT;

SELECT
    l.numero_legajo,
    l.rendimiento_academico,
    (SELECT count(*) FROM sga.inscripcion_curso ic WHERE ic.legajo_id = l.id) AS cursadas,
    (SELECT count(*) FROM sga.factura f WHERE f.legajo_id = l.id AND f.estado = 'PAGADA') AS facturas_pagadas
FROM sga.legajo l
WHERE l.numero_legajo = 'DEMO-001';
