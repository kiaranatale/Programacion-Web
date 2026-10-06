-- =====================================================================
-- Trámites de ejemplo de la alumna demo (correr DESPUÉS de
-- seed_usuarios.sql): uno rechazado y uno resuelto por el administrativo
-- demo, con su historial, y uno pendiente que nadie tomó.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

WITH alumna AS (SELECT id FROM sga.persona WHERE mail_institucional = 'alumno.demo@itba.edu.ar'),
admin AS (SELECT id FROM sga.persona WHERE mail_institucional = 'admin.demo@itba.edu.ar'),
nuevos AS (
    INSERT INTO sga.tramite (persona_id, titulo, destino, descripcion, estado, asignado_persona_id, fecha_creacion, fecha_actualizacion)
    SELECT alumna.id, x.titulo, x.destino, x.descripcion, x.estado,
           CASE WHEN x.estado = 'PENDIENTE' THEN NULL ELSE admin.id END, x.creado, x.creado + INTERVAL '2 days'
    FROM alumna, admin, (VALUES
        ('Excepción por superposición de materias', 'ACADEMICA',
         'Solicito cursar 61.15 y 81.76 aunque se superponen media hora los martes.', 'RECHAZADO', TIMESTAMPTZ '2026-02-13 20:00-03'),
        ('Constancia de alumno regular para la obra social', 'ADMINISTRATIVA',
         'Necesito una constancia de alumno regular para presentar en mi obra social.', 'RESUELTO', TIMESTAMPTZ '2026-08-20 10:15-03'),
        ('Consulta por inscripción a materias del 1C 2027', 'ACADEMICA',
         '¿Puedo solicitar una materia electiva de otra carrera en la primera inscripción?', 'PENDIENTE', TIMESTAMPTZ '2026-10-05 18:40-03')
    ) AS x (titulo, destino, descripcion, estado, creado)
    WHERE NOT EXISTS (SELECT 1 FROM sga.tramite t WHERE t.persona_id = alumna.id AND t.titulo = x.titulo)
    RETURNING id, persona_id, estado, asignado_persona_id, fecha_creacion
)
INSERT INTO sga.tramite_movimiento (tramite_id, fecha, autor_persona_id, estado, comentario)
SELECT n.id, n.fecha_creacion, n.persona_id, 'PENDIENTE', NULL FROM nuevos n
UNION ALL
SELECT n.id, n.fecha_creacion + INTERVAL '1 day', n.asignado_persona_id, 'EN_CURSO', NULL FROM nuevos n WHERE n.estado <> 'PENDIENTE'
UNION ALL
SELECT n.id, n.fecha_creacion + INTERVAL '2 days', n.asignado_persona_id, n.estado,
       CASE n.estado
           WHEN 'RECHAZADO' THEN 'La superposición supera lo permitido por el reglamento.'
           ELSE 'La constancia está disponible en Secretaría Administrativa y te la enviamos por mail.'
       END
FROM nuevos n WHERE n.estado <> 'PENDIENTE';

COMMIT;
