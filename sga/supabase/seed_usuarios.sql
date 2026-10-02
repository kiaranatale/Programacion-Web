-- =====================================================================
-- Personas de prueba para el login (correr DESPUÉS de seed.sql)
-- Crea un alumno, un docente y un administrativo con sus roles. Cada
-- persona se vincula sola con su usuario de Auth por el mail, sin
-- importar qué se cree primero (ver 20261002000000_auth_vinculo_persona).
--
-- Los usuarios de Auth se crean desde el dashboard:
-- Authentication → Users → Add user → Create new user, con estos mails y
-- tildando "Auto Confirm User".
--
-- Se puede correr más de una vez: cada INSERT ignora lo que ya existe.
-- =====================================================================

BEGIN;

INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional)
VALUES
    ('DNI', '40000001', 'Ana',   'Alumna',         'alumno.demo@itba.edu.ar'),
    ('DNI', '40000002', 'Diego', 'Docente',        'docente.demo@itba.edu.ar'),
    ('DNI', '40000003', 'Laura', 'Administrativa', 'admin.demo@itba.edu.ar')
ON CONFLICT (mail_institucional) DO NOTHING;

INSERT INTO sga.persona_rol (persona_id, rol)
SELECT p.id, x.rol::sga.tipo_rol_persona
FROM (VALUES
    ('alumno.demo@itba.edu.ar',  'ALUMNO'),
    ('docente.demo@itba.edu.ar', 'DOCENTE'),
    ('admin.demo@itba.edu.ar',   'ADMINISTRATIVO')
) AS x (mail, rol)
JOIN sga.persona p ON p.mail_institucional = x.mail
ON CONFLICT (persona_id, rol) DO NOTHING;

-- Legajo del alumno en el plan de seed.sql
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'DEMO-001', pl.id
FROM sga.persona p
JOIN sga.plan_estudio pl ON pl.codigo = 'INF-2023'
WHERE p.mail_institucional = 'alumno.demo@itba.edu.ar'
ON CONFLICT (persona_id) DO NOTHING;

-- El docente dicta la comisión A de Programación Web (72.40)
INSERT INTO sga.docente (persona_id)
SELECT id FROM sga.persona WHERE mail_institucional = 'docente.demo@itba.edu.ar'
ON CONFLICT (persona_id) DO NOTHING;

INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, co.id
FROM sga.docente d
JOIN sga.persona p   ON p.id = d.persona_id
JOIN sga.materia m   ON m.codigo = '72.40'
JOIN sga.curso c     ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
WHERE p.mail_institucional = 'docente.demo@itba.edu.ar'
ON CONFLICT (docente_id, comision_id) DO NOTHING;

-- El alumno cursa Programación Web en esa comisión
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id, docente_id)
SELECT l.id, c.id, co.id, d.id
FROM sga.legajo l
JOIN sga.materia m   ON m.codigo = '72.40'
JOIN sga.curso c     ON c.materia_id = m.id AND c.anio = 2026 AND c.periodo = '2C'
JOIN sga.comision co ON co.curso_id = c.id AND co.nombre = 'A'
JOIN sga.persona pd  ON pd.mail_institucional = 'docente.demo@itba.edu.ar'
JOIN sga.docente d   ON d.persona_id = pd.id
WHERE l.numero_legajo = 'DEMO-001'
ON CONFLICT (legajo_id, curso_id) DO NOTHING;

COMMIT;

-- auth_user_id queda vacío hasta que exista el usuario de Auth con ese mail
SELECT p.mail_institucional, pr.rol, p.auth_user_id IS NOT NULL AS vinculado
FROM sga.persona p
JOIN sga.persona_rol pr ON pr.persona_id = p.id
WHERE p.mail_institucional LIKE '%.demo@itba.edu.ar'
ORDER BY pr.rol;
