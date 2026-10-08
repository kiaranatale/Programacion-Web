-- =====================================================================
-- Autoridades y encuestas de ejemplo (correr DESPUÉS de
-- seed_usuarios.sql).
--
--   - Cargos en el orden de Académica → Autoridades del SGA y una
--     autoridad para cada uno. Las personas son ficticias (además de
--     las demo, tres autoridades inventadas sin usuario): las reales
--     las designa Administración desde esa misma pantalla.
--   - Una encuesta de desempeño del docente demo en su comisión de
--     Programación web y una encuesta general para alumnos, abiertas
--     durante octubre y noviembre de 2026.
--
-- Se puede correr más de una vez: no repite lo que ya existe.
-- =====================================================================

BEGIN;

INSERT INTO sga.cargo_institucional (nombre, orden)
VALUES ('Rector/a', 1), ('Vicerrector/a Académico/a', 2), ('Secretario/a Académico/a', 3),
       ('Director/a', 10), ('Director/a Adjunto/a', 11),
       ('Decano/a', 20), ('Director/a de Carrera', 21), ('Director/a de Departamento', 22)
ON CONFLICT (nombre) DO UPDATE SET orden = EXCLUDED.orden;

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES
    ('DNI', '40000101', 'Martín Andrés',  'Rosales',  'autoridad1.demo@itba.edu.ar'),
    ('DNI', '40000102', 'Federico Tomás', 'Quiroga',  'autoridad2.demo@itba.edu.ar'),
    ('DNI', '40000103', 'Lucía Belén',    'Ibarra',   'autoridad3.demo@itba.edu.ar')
ON CONFLICT (mail_institucional) DO NOTHING;

-- Versiones anteriores de este seed hacían al docente demo "Director/a
-- de Carrera" de Gestión y Tecnología; ahora es el director adjunto.
DELETE FROM sga.autoridad a
USING sga.persona p, sga.cargo_institucional c
WHERE a.persona_id = p.id AND a.cargo_institucional_id = c.id
  AND p.mail_institucional = 'docente.demo@itba.edu.ar' AND c.nombre = 'Director/a de Carrera';

INSERT INTO sga.autoridad (persona_id, cargo_institucional_id, escuela_id, fecha_desde)
SELECT p.id, c.id, e.id, DATE '2025-03-01'
FROM (VALUES
    ('autoridad1.demo@itba.edu.ar', 'Rector/a', NULL),
    ('admin.demo@itba.edu.ar', 'Secretario/a Académico/a', NULL),
    ('autoridad2.demo@itba.edu.ar', 'Director/a', 'Escuela de Gestión y Tecnología'),
    ('docente.demo@itba.edu.ar', 'Director/a Adjunto/a', 'Escuela de Gestión y Tecnología'),
    ('autoridad2.demo@itba.edu.ar', 'Director/a', 'Escuela de Ingeniería y Gestión'),
    ('autoridad3.demo@itba.edu.ar', 'Director/a', 'Escuela de Admisión'),
    ('autoridad2.demo@itba.edu.ar', 'Director/a', 'Escuela de Ingeniería y Tecnología'),
    ('autoridad1.demo@itba.edu.ar', 'Director/a', 'Escuela de Posgrado')
) AS x (mail, cargo, escuela)
JOIN sga.persona p ON p.mail_institucional = x.mail
JOIN sga.cargo_institucional c ON c.nombre = x.cargo
LEFT JOIN sga.escuela e ON e.nombre = x.escuela
WHERE NOT EXISTS (
    SELECT 1 FROM sga.autoridad a
    WHERE a.persona_id = p.id AND a.cargo_institucional_id = c.id
      AND a.escuela_id IS NOT DISTINCT FROM e.id
);

-- Encuesta de desempeño del docente demo en 71.38 comisión A
INSERT INTO sga.encuesta (tipo, nombre, docente_comision_id, fecha_inicio, fecha_fin)
SELECT 'DESEMPENO_DOCENTE', 'Desempeño docente - 2C 2026', dc.id, DATE '2026-10-01', DATE '2026-11-30'
FROM sga.docente_comision dc
JOIN sga.docente d ON d.id = dc.docente_id
JOIN sga.persona p ON p.id = d.persona_id AND p.mail_institucional = 'docente.demo@itba.edu.ar'
WHERE NOT EXISTS (SELECT 1 FROM sga.encuesta e WHERE e.docente_comision_id = dc.id AND e.nombre = 'Desempeño docente - 2C 2026');

INSERT INTO sga.encuesta (tipo, nombre, descripcion, fecha_inicio, fecha_fin)
SELECT 'ALUMNOS', 'Encuesta de servicios 2026',
       'Queremos saber cómo funcionan la biblioteca, los laboratorios y el SGA. Es anónima.',
       DATE '2026-10-01', DATE '2026-11-30'
WHERE NOT EXISTS (SELECT 1 FROM sga.encuesta WHERE nombre = 'Encuesta de servicios 2026');

INSERT INTO sga.encuesta_pregunta (encuesta_id, orden, texto, tipo)
SELECT e.id, q.orden, q.texto, q.tipo
FROM sga.encuesta e
JOIN (VALUES
    (1, 'Explica los temas con claridad', 'ESCALA'),
    (2, 'Responde las consultas y está disponible', 'ESCALA'),
    (3, 'Cumple con los horarios y el programa de la materia', 'ESCALA'),
    (4, 'Las evaluaciones son coherentes con lo dado en clase', 'ESCALA'),
    (5, 'Valoración general del docente', 'ESCALA'),
    (6, 'Comentarios (opcional)', 'TEXTO')
) AS q (orden, texto, tipo) ON e.nombre = 'Desempeño docente - 2C 2026'
UNION ALL
SELECT e.id, q.orden, q.texto, q.tipo
FROM sga.encuesta e
JOIN (VALUES
    (1, 'Biblioteca y espacios de estudio', 'ESCALA'),
    (2, 'Laboratorios y equipamiento', 'ESCALA'),
    (3, 'Facilidad de uso del SGA', 'ESCALA'),
    (4, '¿Qué mejorarías?', 'TEXTO')
) AS q (orden, texto, tipo) ON e.nombre = 'Encuesta de servicios 2026'
ON CONFLICT (encuesta_id, orden) DO NOTHING;

COMMIT;

SELECT e.nombre, e.tipo, count(q.id) AS preguntas
FROM sga.encuesta e
LEFT JOIN sga.encuesta_pregunta q ON q.encuesta_id = e.id
GROUP BY e.id, e.nombre, e.tipo
ORDER BY e.id;
