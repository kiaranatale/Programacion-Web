-- =====================================================================
-- Convocatorias de intercambio de ejemplo (correr DESPUÉS de
-- seed_legajo_demo.sql):
--   - Abierta hasta el 30/10/2026 con requisitos que la alumna demo
--     cumple (para probar la postulación).
--   - Abierta con más créditos de los que tiene (muestra el motivo).
--   - Cerrada el 30/09/2026, con postulantes demo y resultados sin
--     publicar (para probar la selección desde Administración).
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.convocatoria_intercambio
    (universidad, pais, ciudad, anio, periodo, vacantes, creditos_minimos, promedio_minimo, descripcion, postulacion_desde, postulacion_hasta)
SELECT x.* FROM (VALUES
    ('Universidad Politécnica de Madrid', 'España', 'Madrid', 2027, '2C', 2, 12, 6.00,
     'Intercambio de un cuatrimestre con reconocimiento de materias electivas. Cursada en castellano.',
     DATE '2026-10-01', DATE '2026-10-30'),
    ('Technische Universität München', 'Alemania', 'Múnich', 2027, '2C', 1, 120, 7.50,
     'Cursada en inglés; se pide certificado de inglés B2.',
     DATE '2026-10-01', DATE '2026-10-30'),
    ('Universidade de São Paulo', 'Brasil', 'São Paulo', 2027, '1C', 3, 0, NULL,
     'Intercambio de un cuatrimestre. Cursada en portugués.',
     DATE '2026-09-01', DATE '2026-09-30')
) AS x (universidad, pais, ciudad, anio, periodo, vacantes, creditos_minimos, promedio_minimo, descripcion, desde, hasta)
WHERE NOT EXISTS (SELECT 1 FROM sga.convocatoria_intercambio c WHERE c.universidad = x.universidad AND c.anio = x.anio AND c.periodo = x.periodo);

INSERT INTO sga.postulacion_intercambio (convocatoria_id, legajo_id, motivacion, fecha)
SELECT c.id, l.id, 'Me interesa conocer otro sistema universitario y practicar portugués; además la universidad tiene materias electivas que complementan mi plan.', x.fecha
FROM sga.convocatoria_intercambio c, sga.legajo l,
     (VALUES ('DEMO-011', TIMESTAMPTZ '2026-09-10 10:00-03'), ('DEMO-012', TIMESTAMPTZ '2026-09-15 18:30-03')) AS x (legajo, fecha)
WHERE c.universidad = 'Universidade de São Paulo' AND c.anio = 2027 AND l.numero_legajo = x.legajo
ON CONFLICT (convocatoria_id, legajo_id) DO NOTHING;

COMMIT;
