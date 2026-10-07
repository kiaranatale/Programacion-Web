-- Prueba de la oferta de cursos (20261020000000_oferta_cursos): cursos,
-- comisiones, cupos, horarios con control de aula y borrado.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Ofe');
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT x.c, 'Materia ' || x.c, d.id, 6 FROM sga.departamento d, (VALUES ('OFE.01'), ('OFE.02'), ('OFE.03')) AS x (c)
WHERE d.nombre = 'Departamento de Prueba Ofe';
INSERT INTO sga.edificio (codigo, nombre) VALUES ('OFE-SEDE', 'Sede de Prueba Ofe');
INSERT INTO sga.aula (edificio_id, codigo, capacidad) SELECT id, '101', 40 FROM sga.edificio WHERE codigo = 'OFE-SEDE';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('c3c3c3c3-0000-0000-0000-000000000009', 'admin.ofe@test.local', now()),
    ('c3c3c3c3-0000-0000-0000-000000000001', 'alumno.ofe@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99700009', 'Admin', 'Ofe', 'admin.ofe@test.local'),
    ('DNI', '99700001', 'Alumno', 'Ofe', 'alumno.ofe@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99700009';

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
CREATE TEMP TABLE ofe (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON ofe TO authenticated;
CREATE FUNCTION pg_temp.o(c TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM ofe WHERE clave = c $$;
CREATE FUNCTION pg_temp.sede() RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM sga.edificio WHERE codigo = 'OFE-SEDE' $$;
GRANT EXECUTE ON FUNCTION pg_temp.o(TEXT), pg_temp.sede() TO authenticated;

SET LOCAL ROLE authenticated;

SET LOCAL request.jwt.claims TO '{"sub": "c3c3c3c3-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.crear_curso('OFE.01', 2031, '1C', DATE '2031-03-01', DATE '2031-07-01')$$, 'Solo Administración');

SET LOCAL request.jwt.claims TO '{"sub": "c3c3c3c3-0000-0000-0000-000000000009"}';
SELECT pg_temp.espera_error($$SELECT sga.crear_curso('NO.EXISTE', 2031, '1C', DATE '2031-03-01', DATE '2031-07-01')$$, 'No existe la materia');
SELECT pg_temp.espera_error($$SELECT sga.crear_curso('OFE.01', 2031, '1C', DATE '2031-07-01', DATE '2031-03-01')$$, 'fechas');
INSERT INTO ofe SELECT 'c1', sga.crear_curso('OFE.01', 2031, '1C', DATE '2031-03-01', DATE '2031-07-01');
INSERT INTO ofe SELECT 'c2', sga.crear_curso('OFE.02', 2031, '1C', DATE '2031-03-01', DATE '2031-07-01');
INSERT INTO ofe SELECT 'c3', sga.crear_curso('OFE.03', 2031, '2C', DATE '2031-08-01', DATE '2031-12-01');
SELECT pg_temp.espera_error($$SELECT sga.crear_curso('OFE.01', 2031, '1C', DATE '2031-03-02', DATE '2031-07-01')$$, 'ya tiene curso');

INSERT INTO ofe SELECT 'c1a', sga.crear_comision(pg_temp.o('c1'), ' a ', 30);
INSERT INTO ofe SELECT 'c2a', sga.crear_comision(pg_temp.o('c2'), 'A', NULL);
INSERT INTO ofe SELECT 'c3a', sga.crear_comision(pg_temp.o('c3'), 'A', 20);
SELECT pg_temp.espera_error($$SELECT sga.crear_comision(pg_temp.o('c1'), 'A', 10)$$, 'Ya hay una comisión A');
SELECT pg_temp.espera_error($$SELECT sga.crear_comision(pg_temp.o('c1'), 'B', 0)$$, 'mayor que cero');

-- Horarios: presencial pide aula; el aula no se pisa en el mismo cuatrimestre
SELECT pg_temp.espera_error($$SELECT sga.agregar_horario(pg_temp.o('c1a'), 'LUNES', '09:00', '12:00', 'PRESENCIAL', pg_temp.sede(), '')$$, 'necesita aula');
SELECT pg_temp.espera_error($$SELECT sga.agregar_horario(pg_temp.o('c1a'), 'LUNES', '09:00', '12:00', 'PRESENCIAL', pg_temp.sede(), '999')$$, 'No existe el aula');
SELECT pg_temp.espera_error($$SELECT sga.agregar_horario(pg_temp.o('c1a'), 'LUNES', '12:00', '09:00', 'PRESENCIAL', pg_temp.sede(), '101')$$, 'no es válido');
INSERT INTO ofe SELECT 'h1', sga.agregar_horario(pg_temp.o('c1a'), 'LUNES', '09:00', '12:00', 'PRESENCIAL', pg_temp.sede(), '101');
SELECT pg_temp.espera_error($$SELECT sga.agregar_horario(pg_temp.o('c2a'), 'LUNES', '11:00', '13:00', 'PRESENCIAL', pg_temp.sede(), '101')$$, 'ya está ocupada a esa hora por OFE.01 comisión A');
-- Contiguo, otro día, otro cuatrimestre o virtual: se puede
SELECT sga.agregar_horario(pg_temp.o('c2a'), 'LUNES', '12:00', '14:00', 'PRESENCIAL', pg_temp.sede(), '101');
SELECT sga.agregar_horario(pg_temp.o('c2a'), 'MARTES', '09:00', '12:00', 'PRESENCIAL', pg_temp.sede(), '101');
SELECT sga.agregar_horario(pg_temp.o('c3a'), 'LUNES', '09:00', '12:00', 'PRESENCIAL', pg_temp.sede(), '101');
SELECT sga.agregar_horario(pg_temp.o('c2a'), 'LUNES', '09:00', '12:00', 'VIRTUAL_ASINCRONICO', NULL, NULL);

-- Cupo y borrado con inscriptos
RESET ROLE;
INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Ofe');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id) SELECT 'OFE', 'Carrera Ofe', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Ofe';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde) SELECT id, 'PLN-OFE', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'OFE';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'OFE-1', pl.id FROM sga.persona p, sga.plan_estudio pl WHERE p.nro_documento = '99700001' AND pl.codigo = 'PLN-OFE';
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id FROM sga.legajo l, sga.comision co WHERE l.numero_legajo = 'OFE-1' AND co.id = (SELECT id FROM ofe WHERE clave = 'c1a');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "c3c3c3c3-0000-0000-0000-000000000009"}';
SELECT sga.cambiar_cupo_comision(pg_temp.o('c1a'), 1);
SELECT pg_temp.espera_error($$SELECT sga.cambiar_cupo_comision(pg_temp.o('c1a'), 0)$$, 'mayor que cero');
SELECT pg_temp.espera_error($$SELECT sga.borrar_comision(pg_temp.o('c1a'))$$, 'ya tiene inscripciones');
SELECT pg_temp.espera_error($$SELECT sga.borrar_curso(pg_temp.o('c1'))$$, 'ya tiene inscripciones');
SELECT sga.borrar_horario(pg_temp.o('h1'));
SELECT sga.borrar_curso(pg_temp.o('c3'));
DO $$
BEGIN
    IF (SELECT cupo FROM sga.comision WHERE id = pg_temp.o('c1a')) <> 1 THEN
        RAISE EXCEPTION 'Oferta: el cupo debería ser 1';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.curso WHERE id = pg_temp.o('c3')) THEN
        RAISE EXCEPTION 'Oferta: el curso sin inscriptos se borra con sus comisiones y horarios';
    END IF;
    IF (SELECT count(*) FROM sga.horario_comision WHERE comision_id = pg_temp.o('c2a')) <> 3 THEN
        RAISE EXCEPTION 'Oferta: OFE.02 A debería tener 3 horarios';
    END IF;
END;
$$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "c3c3c3c3-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.cambiar_cupo_comision(pg_temp.o('c2a'), 10)$$, 'Solo Administración');

ROLLBACK;
