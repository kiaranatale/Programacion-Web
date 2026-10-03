-- =====================================================================
-- Hoy en el ITBA: organizaciones y publicaciones de ejemplo (correr
-- DESPUÉS de seed_usuarios.sql).
--
-- Organizaciones ficticias; las reales las carga Administración desde
-- Administración → Organizaciones estudiantiles. El alumno demo queda
-- como miembro del Centro de Estudiantes para poder publicar.
--
-- Se puede correr más de una vez: cada INSERT ignora lo que ya existe.
-- =====================================================================

BEGIN;

INSERT INTO sga.organizacion (nombre, descripcion)
VALUES
    ('Centro de Estudiantes', 'Representación estudiantil, apuntes, becas y actividades para toda la comunidad.'),
    ('Club de Robótica', 'Proyectos de robótica y electrónica abiertos a todas las carreras.'),
    ('Grupo de Emprendedores', 'Charlas, mentorías y competencias de emprendimientos.')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO sga.organizacion_miembro (organizacion_id, persona_id)
SELECT o.id, p.id
FROM sga.organizacion o, sga.persona p
WHERE o.nombre = 'Centro de Estudiantes' AND p.mail_institucional = 'alumno.demo@itba.edu.ar'
ON CONFLICT DO NOTHING;

INSERT INTO sga.publicacion (organizacion_id, autor_persona_id, tipo, titulo, cuerpo, fecha_evento, hora_evento, lugar, creada)
SELECT o.id, p.id, x.tipo, x.titulo, x.cuerpo, x.fecha::DATE, x.hora::TIME, x.lugar, x.creada::TIMESTAMPTZ
FROM (VALUES
    ('Centro de Estudiantes', 'EVENTO', 'Bienvenida al segundo cuatrimestre',
     E'Te esperamos para arrancar el cuatrimestre: presentación de las organizaciones, mate y música.\n\nTraé a tus compañeros de primer año.',
     '2026-10-09', '17:00', 'Hall central - Sede Distrito Financiero', '2026-09-28 10:00-03'),
    ('Centro de Estudiantes', 'NOVEDAD', 'Banco de apuntes actualizado',
     E'Subimos resúmenes y finales resueltos de Análisis Matemático, Física y Programación.\n\nSi querés compartir los tuyos, escribinos.',
     NULL, NULL, NULL, '2026-09-30 12:30-03'),
    ('Club de Robótica', 'EVENTO', 'Taller introductorio de Arduino',
     E'Taller práctico de dos horas para quienes nunca usaron Arduino. Los kits los pone el club.\n\nCupo limitado: anotate respondiendo esta publicación.',
     '2026-10-16', '18:30', 'Laboratorio LAB-2', '2026-10-01 09:15-03'),
    ('Grupo de Emprendedores', 'EVENTO', 'Charla: cómo validar una idea en una semana',
     'Charla abierta con egresados que lanzaron sus emprendimientos. Al final hay ronda de preguntas.',
     '2026-10-22', '19:00', 'Aula 101', '2026-10-02 16:45-03')
) AS x (organizacion, tipo, titulo, cuerpo, fecha, hora, lugar, creada)
JOIN sga.organizacion o ON o.nombre = x.organizacion
LEFT JOIN sga.persona p ON p.mail_institucional = 'alumno.demo@itba.edu.ar' AND x.organizacion = 'Centro de Estudiantes'
WHERE NOT EXISTS (
    SELECT 1 FROM sga.publicacion pu WHERE pu.organizacion_id = o.id AND pu.titulo = x.titulo);

INSERT INTO sga.publicacion_comentario (publicacion_id, autor_persona_id, cuerpo)
SELECT pu.id, p.id, '¡Me anoto! ¿Hace falta llevar notebook?'
FROM sga.publicacion pu, sga.persona p
WHERE pu.titulo = 'Taller introductorio de Arduino' AND p.mail_institucional = 'alumno.demo@itba.edu.ar'
  AND NOT EXISTS (SELECT 1 FROM sga.publicacion_comentario c WHERE c.publicacion_id = pu.id);

COMMIT;

SELECT o.nombre AS organizacion, count(pu.id) AS publicaciones
FROM sga.organizacion o
LEFT JOIN sga.publicacion pu ON pu.organizacion_id = o.id
GROUP BY o.nombre
ORDER BY o.nombre;
