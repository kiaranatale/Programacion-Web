-- =====================================================================
-- Proyectos de ejemplo de la alumna demo (correr DESPUÉS de
-- seed_legajo_demo.sql): uno validado, uno pendiente de revisión y uno
-- rechazado con motivo, para ver los tres estados.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.proyecto_alumno (legajo_id, tipo, titulo, responsable, descripcion, desde, hasta, estado, observaciones, fecha_revision)
SELECT l.id, x.tipo, x.titulo, x.responsable, x.descripcion, x.desde, x.hasta, x.estado, x.observaciones,
       CASE WHEN x.estado = 'PENDIENTE' THEN NULL ELSE now() END
FROM sga.legajo l, (VALUES
    ('EXTENSION', 'Tutorías del curso de ingreso', 'Área de Ingreso',
     'Acompañamiento a ingresantes en Matemática durante el curso de verano.',
     DATE '2026-02-02', DATE '2026-02-27', 'VALIDADO', NULL),
    ('INVESTIGACION', 'Análisis de datos de movilidad urbana', 'Departamento de Sistemas Digitales y Datos',
     'Limpieza y visualización de datos abiertos de transporte público.',
     DATE '2026-04-01', NULL, 'PENDIENTE', NULL),
    ('PROYECTO', 'Organización de la Semana de la Ingeniería', NULL, NULL,
     DATE '2025-09-15', DATE '2025-09-19', 'RECHAZADO', 'Indicá quién estuvo a cargo para poder validarlo.')
) AS x (tipo, titulo, responsable, descripcion, desde, hasta, estado, observaciones)
WHERE l.numero_legajo = 'DEMO-001'
  AND NOT EXISTS (SELECT 1 FROM sga.proyecto_alumno p WHERE p.legajo_id = l.id AND p.titulo = x.titulo);

COMMIT;
