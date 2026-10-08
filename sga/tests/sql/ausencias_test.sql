-- Prueba de ausencias docentes (20261022000000_ausencias_docentes):
-- informar (solo en comisiones propias), avisos a alumnos, cancelar,
-- revisión de Administración y visibilidad.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Aus');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Aus');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id) SELECT 'AUS', 'Carrera Aus', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Aus';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde) SELECT id, 'PLN-AUS', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'AUS';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT x.c, 'Materia ' || x.c, d.id, 6 FROM sga.departamento d, (VALUES ('AUS.01'), ('AUS.02')) AS x (c) WHERE d.nombre = 'Departamento de Prueba Aus';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2026, '2C', sga.hoy() - 30, sga.hoy() + 60 FROM sga.materia WHERE codigo LIKE 'AUS.%';
INSERT INTO sga.comision (curso_id, nombre)
SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo LIKE 'AUS.%';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('e5e5e5e5-0000-0000-0000-000000000001', 'doc.aus@test.local', now()),
    ('e5e5e5e5-0000-0000-0000-000000000002', 'alu.aus@test.local', now()),
    ('e5e5e5e5-0000-0000-0000-000000000003', 'otro.aus@test.local', now()),
    ('e5e5e5e5-0000-0000-0000-000000000009', 'admin.aus@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99900001', 'Docente', 'Aus', 'doc.aus@test.local'),
    ('DNI', '99900002', 'Alumno', 'Aus', 'alu.aus@test.local'),
    ('DNI', '99900003', 'Otro', 'Aus', 'otro.aus@test.local'),
    ('DNI', '99900009', 'Admin', 'Aus', 'admin.aus@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99900009';
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'DOCENTE' FROM sga.persona WHERE nro_documento = '99900001';
INSERT INTO sga.docente (persona_id) SELECT id FROM sga.persona WHERE nro_documento = '99900001';
-- El docente dicta solo AUS.01 A
INSERT INTO sga.docente_comision (docente_id, comision_id)
SELECT d.id, co.id FROM sga.docente d JOIN sga.persona p ON p.id = d.persona_id, sga.comision co
JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE p.nro_documento = '99900001' AND m.codigo = 'AUS.01';
-- El alumno cursa AUS.01 A; "otro" cursa AUS.02 A
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'AUS-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99900002', '99900003') AND pl.codigo = 'PLN-AUS';
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id FROM sga.legajo l, sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE (l.numero_legajo = 'AUS-2' AND m.codigo = 'AUS.01') OR (l.numero_legajo = 'AUS-3' AND m.codigo = 'AUS.02');

CREATE FUNCTION pg_temp.espera_error(p_sql TEXT, p_texto TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%' || p_texto || '%' THEN
            RAISE EXCEPTION 'Error inesperado: % (se esperaba "%")', SQLERRM, p_texto;
        END IF;
        RETURN;
    END;
    RAISE EXCEPTION 'Se esperaba un error "%" y no lo hubo: %', p_texto, p_sql;
END;
$$;
CREATE FUNCTION pg_temp.com(c TEXT) RETURNS INTEGER LANGUAGE sql SECURITY DEFINER AS $$
    SELECT co.id FROM sga.comision co JOIN sga.curso cu ON cu.id = co.curso_id JOIN sga.materia m ON m.id = cu.materia_id WHERE m.codigo = c
$$;
CREATE TEMP TABLE aus (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON aus TO authenticated;
CREATE FUNCTION pg_temp.a(c TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM aus WHERE clave = c $$;
GRANT EXECUTE ON FUNCTION pg_temp.com(TEXT), pg_temp.a(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- Un alumno no puede informar ausencias
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('PERSONAL', sga.hoy() + 1, sga.hoy() + 1, NULL, ARRAY[pg_temp.com('AUS.01')])$$, 'no es docente');

SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('PERSONAL', sga.hoy() + 1, sga.hoy() + 1, NULL, ARRAY[pg_temp.com('AUS.02')])$$, 'comisiones que dictás');
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('PERSONAL', sga.hoy() - 5, sga.hoy() - 2, NULL, ARRAY[pg_temp.com('AUS.01')])$$, 'ya pasó');
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('PERSONAL', sga.hoy() + 3, sga.hoy() + 1, NULL, ARRAY[pg_temp.com('AUS.01')])$$, 'no son válidas');
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('VACACIONES', sga.hoy() + 1, sga.hoy() + 1, NULL, ARRAY[pg_temp.com('AUS.01')])$$, 'tipo de ausencia');
SELECT pg_temp.espera_error($$SELECT sga.informar_ausencia('PERSONAL', sga.hoy() + 1, sga.hoy() + 1, NULL, ARRAY[]::INTEGER[])$$, 'al menos una comisión');
INSERT INTO aus SELECT 'congreso', sga.informar_ausencia('CONGRESO', sga.hoy() + 2, sga.hoy() + 4, 'Congreso de prueba', ARRAY[pg_temp.com('AUS.01')]);
INSERT INTO aus SELECT 'hoy', sga.informar_ausencia('ENFERMEDAD', sga.hoy(), sga.hoy(), NULL, ARRAY[pg_temp.com('AUS.01')]);
SELECT pg_temp.espera_error($$SELECT sga.cancelar_ausencia(pg_temp.a('hoy'))$$, 'todavía no empezó');
SELECT pg_temp.espera_error($$SELECT sga.revisar_ausencia(pg_temp.a('hoy'), TRUE, NULL)$$, 'Solo Administración');
SELECT pg_temp.espera_error($$SELECT * FROM sga.ausencias_docentes(FALSE)$$, 'Solo Administración');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.ausencias_docentes(TRUE)) <> 2 THEN
        RAISE EXCEPTION 'Ausencias: el docente ve sus 2 ausencias';
    END IF;
END;
$$;

-- El alumno de AUS.01 recibe los avisos y las ve; el de AUS.02 no
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000002"}';
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.notificacion WHERE tipo = 'AUSENCIA' AND mensaje LIKE 'Sin clase de AUS.01%') <> 2 THEN
        RAISE EXCEPTION 'Ausencias: el alumno de AUS.01 debería tener 2 avisos';
    END IF;
    IF (SELECT count(*) FROM sga.clases_suspendidas_para_mi()) <> 2 THEN
        RAISE EXCEPTION 'Ausencias: el alumno ve 2 clases suspendidas';
    END IF;
    IF (SELECT count(*) FROM sga.ausencia_docente) + (SELECT count(*) FROM sga.ausencias_docentes(TRUE)) <> 0 THEN
        RAISE EXCEPTION 'Ausencias: el alumno no lee las ausencias de los docentes';
    END IF;
END;
$$;
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000003"}';
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.notificacion WHERE tipo = 'AUSENCIA') + (SELECT count(*) FROM sga.clases_suspendidas_para_mi()) <> 0 THEN
        RAISE EXCEPTION 'Ausencias: el alumno de AUS.02 no recibe nada';
    END IF;
END;
$$;

-- El docente cancela la futura: se avisa y deja de figurar
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000001"}';
SELECT sga.cancelar_ausencia(pg_temp.a('congreso'));
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000002"}';
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.clases_suspendidas_para_mi()) <> 1 THEN
        RAISE EXCEPTION 'Ausencias: la cancelada deja de figurar';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.notificacion WHERE mensaje LIKE 'Hay clase de AUS.01%canceló%') THEN
        RAISE EXCEPTION 'Ausencias: se avisa que hay clase';
    END IF;
END;
$$;

-- Administración revisa
SET LOCAL request.jwt.claims TO '{"sub": "e5e5e5e5-0000-0000-0000-000000000009"}';
SELECT pg_temp.espera_error($$SELECT sga.revisar_ausencia(pg_temp.a('hoy'), FALSE, ' ')$$, 'por qué no se justifica');
SELECT pg_temp.espera_error($$SELECT sga.revisar_ausencia(pg_temp.a('congreso'), TRUE, NULL)$$, 'cancelada');
SELECT sga.revisar_ausencia(pg_temp.a('hoy'), TRUE, 'Presentó certificado');
DO $$
BEGIN
    IF (SELECT estado || '|' || comisiones FROM sga.ausencias_docentes(FALSE) WHERE id = pg_temp.a('hoy')) <> 'JUSTIFICADA|AUS.01 A' THEN
        RAISE EXCEPTION 'Ausencias: Administración la ve justificada con su comisión';
    END IF;
END;
$$;

ROLLBACK;
