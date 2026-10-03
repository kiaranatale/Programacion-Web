-- =====================================================================
-- Autoridades y encuestas de ejemplo (correr DESPUÉS de
-- seed_usuarios.sql).
--
--   - Cargos institucionales habituales. Las autoridades reales las
--     designa Administración desde Académica → Autoridades; acá solo se
--     usan las personas demo.
--   - Una encuesta de desempeño del docente demo en su comisión de
--     Programación web y una encuesta general para alumnos, abiertas
--     durante octubre y noviembre de 2026.
--
-- Se puede correr más de una vez: no repite lo que ya existe.
-- =====================================================================

BEGIN;

INSERT INTO sga.cargo_institucional (nombre)
VALUES ('Rector/a'), ('Vicerrector/a Académico/a'), ('Secretario/a Académico/a'),
       ('Decano/a'), ('Director/a de Carrera'), ('Director/a de Departamento')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.autoridad (persona_id, cargo_institucional_id, escuela_id, fecha_desde)
SELECT p.id, c.id, e.id, DATE '2025-03-01'
FROM (VALUES
    ('admin.demo@itba.edu.ar', 'Secretario/a Académico/a', NULL),
    ('docente.demo@itba.edu.ar', 'Director/a de Carrera', 'Escuela de Gestión y Tecnología')
) AS x (mail, cargo, escuela)
JOIN sga.persona p ON p.mail_institucional = x.mail
JOIN sga.cargo_institucional c ON c.nombre = x.cargo
LEFT JOIN sga.escuela e ON e.nombre = x.escuela
WHERE NOT EXISTS (SELECT 1 FROM sga.autoridad a WHERE a.persona_id = p.id AND a.cargo_institucional_id = c.id);

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
