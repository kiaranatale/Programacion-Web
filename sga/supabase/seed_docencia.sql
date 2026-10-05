-- =====================================================================
-- Datos para probar Docencia con el docente demo (correr DESPUÉS de
-- seed_usuarios.sql y seed_legajo_demo.sql).
--
--   - Cuatro alumnos ficticios más en su comisión A de Programación web
--     (2C 2026), para cargar notas de cursada. No tienen usuario.
--   - Programación web 1C 2026, comisión A, dictada por el docente demo,
--     con tres de esos alumnos con la cursada aprobada y una mesa de final
--     del 03/08/2026 para cargar las notas.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES
    ('DNI', '40000011', 'Bruno',   'Demo', 'bruno.demo@itba.edu.ar'),
    ('DNI', '40000012', 'Carla',   'Demo', 'carla.demo@itba.edu.ar'),
    ('DNI', '40000013', 'Elena',   'Demo', 'elena.demo@itba.edu.ar'),
    ('DNI', '40000014', 'Facundo', 'Demo', 'facundo.demo@itba.edu.ar')
ON CONFLICT (mail_institucional) DO NOTHING;

INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ALUMNO' FROM sga.persona WHERE nro_documento IN ('40000011', '40000012', '40000013', '40000014')
ON CONFLICT (persona_id, rol) DO NOTHING;

INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'DEMO-0' || right(p.nro_documento, 2), pl.id
FROM sga.persona p
JOIN sga.carrera ca ON ca.codigo = 'LAES'
JOIN sga.plan_estudio pl ON pl.carrera_id = ca.id AND pl.codigo = 'A22'
WHERE p.nro_documento IN ('40000011', '40000012', '40000013', '40000014')
ON CONFLICT (persona_id) DO NOTHING;

-- Cursan 71.38 2C 2026 comisión A
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, c.id, co.id
FROM sga.legajo l
JOIN sga.materia m ON m.codigo = '71.38'
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
WHERE l.numero_legajo IN ('DEMO-011', 'DEMO-012', 'DEMO-013', 'DEMO-014')
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

-- 71.38 1C 2026 (ya terminado), comisión A del docente demo
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin, activo, responsable_docente_id)
SELECT m.id, 2026, '1C', DATE '2026-03-09', DATE '2026-07-04', FALSE, d.id
FROM sga.materia m, sga.docente d JOIN sga.persona p ON p.id = d.persona_id
WHERE m.codigo = '71.38' AND p.mail_institucional = 'docente.demo@itba.edu.ar'
  AND NOT EXISTS (SELECT 1 FROM sga.curso c WHERE c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '1C');

INSERT INTO sga.comision (curso_id, nombre, cupo)
SELECT c.id, 'A', 40 FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
WHERE m.codigo = '71.38' AND c.anio = 2026 AND c.periodo = '1C'
  AND NOT EXISTS (SELECT 1 FROM sga.comision co WHERE co.curso_id = c.id AND co.nombre = 'A');

INSERT INTO sga.docente_comision (docente_id, comision_id, cargo)
SELECT d.id, co.id, 'Adjunto'
FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id
JOIN sga.materia m ON m.codigo = '71.38'
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '1C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
WHERE p.mail_institucional = 'docente.demo@itba.edu.ar'
ON CONFLICT (docente_id, comision_id) DO NOTHING;

-- Bruno, Carla y Elena la cursaron en el 1C con cursada aprobada
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, estado, nota_cursada, fecha_carga_cursada, docente_id)
SELECT l.id, c.id, co.id, 'CURSADA_APROBADA', x.nota, TIMESTAMP '2026-07-03 18:00', dc.docente_id
FROM (VALUES ('DEMO-011', 7), ('DEMO-012', 9), ('DEMO-013', 5)) AS x (legajo, nota)
JOIN sga.legajo l ON l.numero_legajo = x.legajo
JOIN sga.materia m ON m.codigo = '71.38'
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '1C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
JOIN sga.docente_comision dc ON dc.comision_id = co.id
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

-- Mesa de final del 03/08/2026 con los tres inscriptos, sin nota
INSERT INTO sga.examen_final (curso_id, fecha, hora_inicio, hora_fin)
SELECT c.id, DATE '2026-08-03', TIME '09:00', TIME '12:00'
FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id
WHERE m.codigo = '71.38' AND c.anio = 2026 AND c.periodo = '1C'
  AND NOT EXISTS (SELECT 1 FROM sga.examen_final ef WHERE ef.curso_id = c.id AND ef.fecha = DATE '2026-08-03');

INSERT INTO sga.inscripcion_examen_final (inscripcion_curso_id, examen_final_id, numero_intento)
SELECT ic.id, ef.id, 1
FROM sga.inscripcion_curso ic
JOIN sga.legajo l ON l.id = ic.legajo_id AND l.numero_legajo IN ('DEMO-011', 'DEMO-012', 'DEMO-013')
JOIN sga.examen_final ef ON ef.curso_id = ic.curso_id AND ef.fecha = DATE '2026-08-03'
WHERE NOT EXISTS (SELECT 1 FROM sga.inscripcion_examen_final x WHERE x.inscripcion_curso_id = ic.id);

COMMIT;

SELECT m.codigo, c.periodo, co.nombre AS comision,
       count(ic.id) AS inscriptos,
       (SELECT count(*) FROM sga.inscripcion_examen_final ief JOIN sga.examen_final ef ON ef.id = ief.examen_final_id
        WHERE ef.curso_id = c.id) AS inscriptos_a_final
FROM sga.comision co
JOIN sga.curso c ON c.id = co.curso_id
JOIN sga.materia m ON m.id = c.materia_id AND m.codigo = '71.38'
LEFT JOIN sga.inscripcion_curso ic ON ic.comision_id = co.id
WHERE c.anio = 2026 AND co.nombre = 'A'
GROUP BY m.codigo, c.id, c.periodo, co.nombre
ORDER BY c.periodo;
