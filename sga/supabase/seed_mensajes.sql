-- =====================================================================
-- Mensajes de ejemplo (correr DESPUÉS de seed_usuarios.sql).
--
--   - El docente demo escribe a su comisión A de Programación web.
--   - Administración escribe a todos los usuarios.
--
-- Se puede correr más de una vez: no repite mensajes con el mismo asunto.
-- =====================================================================

BEGIN;

INSERT INTO sga.mensaje (persona_emisor_id, asunto, cuerpo, destino_descripcion, fecha)
SELECT p.id, x.asunto, x.cuerpo, x.destino, x.fecha::TIMESTAMPTZ
FROM (VALUES
    ('docente.demo@itba.edu.ar', 'Bienvenida a Programación web',
     E'¡Hola! Les doy la bienvenida a la materia.\n\nEl material de la primera clase ya está disponible. Cualquier duda, respondan este mensaje.',
     'Alumnos de 71.38 - Programación web, comisión A', '2026-09-28 09:00-03'),
    ('admin.demo@itba.edu.ar', 'Inscripción a exámenes finales',
     E'La inscripción a los finales de diciembre abre el 16/11 y cierra el 27/11.\n\nRecordá tener la documentación al día.',
     'Todos los usuarios', '2026-10-01 11:30-03')
) AS x (mail, asunto, cuerpo, destino, fecha)
JOIN sga.persona p ON p.mail_institucional = x.mail
WHERE NOT EXISTS (SELECT 1 FROM sga.mensaje m WHERE m.asunto = x.asunto AND m.persona_emisor_id = p.id);

-- Destinatarios: los alumnos de la comisión A de 71.38 y todos los usuarios
INSERT INTO sga.mensaje_destinatario (mensaje_id, persona_id)
SELECT m.id, l.persona_id
FROM sga.mensaje m
JOIN sga.materia ma ON ma.codigo = '71.38'
JOIN sga.curso c ON c.materia_id = ma.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
JOIN sga.inscripcion_curso ic ON ic.comision_id = co.id AND ic.estado <> 'ABANDONADA'
JOIN sga.legajo l ON l.id = ic.legajo_id
WHERE m.asunto = 'Bienvenida a Programación web'
ON CONFLICT DO NOTHING;

INSERT INTO sga.mensaje_destinatario (mensaje_id, persona_id)
SELECT DISTINCT m.id, pr.persona_id
FROM sga.mensaje m
JOIN sga.persona_rol pr ON pr.activo AND pr.persona_id <> m.persona_emisor_id
WHERE m.asunto = 'Inscripción a exámenes finales'
ON CONFLICT DO NOTHING;

COMMIT;

SELECT m.asunto, count(d.persona_id) AS destinatarios
FROM sga.mensaje m
LEFT JOIN sga.mensaje_destinatario d ON d.mensaje_id = m.id
GROUP BY m.id, m.asunto
ORDER BY m.id;
