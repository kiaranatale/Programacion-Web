-- =====================================================================
-- Eventos académicos con inscripción de ejemplo (correr DESPUÉS de
-- seed_docencia.sql).
--
--   - La charla de bienvenida de seed.sql (09/10) pasa a tener inscripción
--     con cupo de 60.
--   - Taller de armado de CV (14/10): cupo de 2, ya completo con dos
--     alumnos ficticios.
--   - Feria de empresas (21/10): sin cupo, inscripción hasta el 20/10.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

UPDATE sga.evento_academico
SET con_inscripcion = TRUE, cupo = 60,
    descripcion = 'Presentación de la vida en el ITBA para quienes empiezan: servicios, organizaciones estudiantiles y recorrida por la sede.'
WHERE nombre = 'Charla de bienvenida a ingresantes' AND fecha = DATE '2026-10-09' AND NOT con_inscripcion;

INSERT INTO sga.evento_academico (nombre, tipo, descripcion, fecha, hora_inicio, hora_fin, aula_id, cupo, con_inscripcion, inscripcion_hasta)
SELECT x.nombre, x.tipo, x.descripcion, x.fecha, x.desde, x.hasta,
       (SELECT a.id FROM sga.aula a JOIN sga.edificio e ON e.id = a.edificio_id WHERE e.codigo = 'SEDE-DM' AND a.codigo = x.aula),
       x.cupo, TRUE, x.cierre
FROM (VALUES
    ('Taller de armado de CV', 'Taller', 'Cómo armar un CV y un perfil profesional para tu primera búsqueda laboral.',
     DATE '2026-10-14', TIME '18:00', TIME '20:00', '304', 2, NULL::TIMESTAMPTZ),
    ('Feria de empresas 2026', 'Jornada', 'Empresas del sector presentan sus programas de pasantías y jóvenes profesionales.',
     DATE '2026-10-21', TIME '10:00', TIME '17:00', '101', NULL, TIMESTAMPTZ '2026-10-20 23:59-03')
) AS x (nombre, tipo, descripcion, fecha, desde, hasta, aula, cupo, cierre)
WHERE NOT EXISTS (SELECT 1 FROM sga.evento_academico ev WHERE ev.nombre = x.nombre AND ev.fecha = x.fecha);

-- Dos alumnos ficticios completan el taller de CV
INSERT INTO sga.evento_inscripcion (evento_id, persona_id)
SELECT ev.id, p.id
FROM sga.evento_academico ev, sga.persona p
WHERE ev.nombre = 'Taller de armado de CV' AND p.mail_institucional IN ('bruno.demo@itba.edu.ar', 'carla.demo@itba.edu.ar')
ON CONFLICT DO NOTHING;

COMMIT;

SELECT ev.nombre, to_char(ev.fecha, 'DD/MM/YYYY') AS fecha, ev.cupo,
       (SELECT count(*) FROM sga.evento_inscripcion i WHERE i.evento_id = ev.id) AS inscriptos
FROM sga.evento_academico ev
WHERE ev.con_inscripcion
ORDER BY ev.fecha;
