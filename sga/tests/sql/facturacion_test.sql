-- Prueba de la facturación automática (20261021000000_facturacion):
-- importe por créditos × valor vigente + adicionales − becas, sin
-- duplicar, vencimiento, vencidas y permisos.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Fac');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Fac');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id) SELECT 'FAC', 'Carrera Fac', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Fac';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde) SELECT id, 'PLN-FAC', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'FAC';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT x.c, 'Materia ' || x.c, d.id, x.cr FROM sga.departamento d, (VALUES ('FAC.01', 6), ('FAC.02', 3), ('FAC.03', 9)) AS x (c, cr)
WHERE d.nombre = 'Departamento de Prueba Fac';
-- FAC.01 y FAC.02 en 2040 1C (mar-jul); FAC.03 en 2040 2C (ago-dic)
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT m.id, 2040, x.p, x.d, x.h FROM sga.materia m
JOIN (VALUES ('FAC.01', '1C', DATE '2040-03-01', DATE '2040-07-15'), ('FAC.02', '1C', DATE '2040-03-01', DATE '2040-07-15'),
             ('FAC.03', '2C', DATE '2040-08-01', DATE '2040-12-15')) AS x (c, p, d, h) ON x.c = m.codigo;
INSERT INTO sga.comision (curso_id, nombre) SELECT c.id, 'A' FROM sga.curso c WHERE c.anio = 2040;

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('d4d4d4d4-0000-0000-0000-000000000001', 'a1.fac@test.local', now()),
    ('d4d4d4d4-0000-0000-0000-000000000002', 'a2.fac@test.local', now()),
    ('d4d4d4d4-0000-0000-0000-000000000009', 'admin.fac@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99800001', 'Alumno1', 'Fac', 'a1.fac@test.local'),
    ('DNI', '99800002', 'Alumno2', 'Fac', 'a2.fac@test.local'),
    ('DNI', '99800009', 'Admin', 'Fac', 'admin.fac@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99800009';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'FAC-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99800001', '99800002') AND pl.codigo = 'PLN-FAC';
-- Alumno 1 cursa FAC.01 y FAC.02 (9 créditos); alumno 2 solo FAC.03 (2C)
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id FROM sga.legajo l, sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE (l.numero_legajo = 'FAC-1' AND m.codigo IN ('FAC.01', 'FAC.02')) OR (l.numero_legajo = 'FAC-2' AND m.codigo = 'FAC.03');
-- Adicional y beca del alumno 1 (los legajos nuevos reciben los adicionales activos por trigger: los apagamos)
UPDATE sga.item_facturable_legajo SET activo = FALSE WHERE legajo_id IN (SELECT id FROM sga.legajo WHERE numero_legajo LIKE 'FAC-%');
INSERT INTO sga.item_facturable (codigo, nombre, monto, activo) VALUES ('FAC-ADI', 'Adicional Fac', 1000, TRUE);
UPDATE sga.item_facturable_legajo SET activo = FALSE
WHERE item_facturable_id = (SELECT id FROM sga.item_facturable WHERE codigo = 'FAC-ADI')
  AND legajo_id NOT IN (SELECT id FROM sga.legajo WHERE numero_legajo = 'FAC-1');
UPDATE sga.item_facturable_legajo SET fecha_desde = DATE '2040-01-01'
WHERE item_facturable_id = (SELECT id FROM sga.item_facturable WHERE codigo = 'FAC-ADI');
INSERT INTO sga.beca_descuento (nombre, tipo) VALUES ('Beca Fac', 'BECA');
INSERT INTO sga.beca_descuento_legajo (legajo_id, beca_descuento_id, monto, fecha_desde)
SELECT l.id, b.id, 500, DATE '2040-01-01' FROM sga.legajo l, sga.beca_descuento b WHERE l.numero_legajo = 'FAC-1' AND b.nombre = 'Beca Fac';
-- Valor del crédito: 100 desde 2040, 200 desde junio 2040
INSERT INTO sga.valor_credito (vigente_desde, monto) VALUES (DATE '2040-01-01', 100), (DATE '2040-06-01', 200);

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

-- Abril 2040: solo el alumno 1; 9 × 100 + 1000 − 500 = 1400; vence el 10
DO $$
BEGIN
    IF sga.generar_facturas_mes('2040-04') <> 1 THEN
        RAISE EXCEPTION 'Facturación: en abril debería facturar solo al alumno 1';
    END IF;
    IF sga.generar_facturas_mes('2040-04') <> 0 THEN
        RAISE EXCEPTION 'Facturación: correrla de nuevo no duplica';
    END IF;
    IF (SELECT monto_total::TEXT || '|' || creditos_cursados || '|' || fecha_vencimiento FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id
        WHERE l.numero_legajo = 'FAC-1' AND f.periodo = '2040-04') <> '1400.00|9|2040-04-10' THEN
        RAISE EXCEPTION 'Facturación: abril debería ser 1400 por 9 créditos, vence 10/04';
    END IF;
    IF (SELECT count(*) || '|' || sum(monto) FROM sga.factura_detalle d JOIN sga.factura f ON f.id = d.factura_id JOIN sga.legajo l ON l.id = f.legajo_id
        WHERE l.numero_legajo = 'FAC-1' AND f.periodo = '2040-04') <> '3|1400.00' THEN
        RAISE EXCEPTION 'Facturación: el detalle tiene créditos, adicional y beca (negativa) y suma el total';
    END IF;
END;
$$;
-- Julio 2040: valor nuevo (200) para el alumno 1; agosto: el alumno 2 entra (9 × 200)
DO $$
BEGIN
    PERFORM sga.generar_facturas_mes('2040-07');
    PERFORM sga.generar_facturas_mes('2040-08');
    IF (SELECT valor_credito_aplicado FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'FAC-1' AND f.periodo = '2040-07') <> 200 THEN
        RAISE EXCEPTION 'Facturación: julio usa el valor vigente (200)';
    END IF;
    IF (SELECT monto_total FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'FAC-2' AND f.periodo = '2040-08') <> 1800 THEN
        RAISE EXCEPTION 'Facturación: agosto del alumno 2 = 9 × 200';
    END IF;
    IF EXISTS (SELECT 1 FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'FAC-1' AND f.periodo = '2040-08') THEN
        RAISE EXCEPTION 'Facturación: el alumno 1 no cursa en agosto';
    END IF;
END;
$$;

-- Vencidas, y la factura del mes en curso al entrar el alumno (su propio legajo)
UPDATE sga.factura SET fecha_vencimiento = sga.hoy() - 1
WHERE periodo = '2040-04' AND legajo_id = (SELECT id FROM sga.legajo WHERE numero_legajo = 'FAC-1');
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2099, '1C', sga.hoy() - 30, sga.hoy() + 30 FROM sga.materia WHERE codigo = 'FAC.03';
INSERT INTO sga.comision (curso_id, nombre) SELECT id, 'A' FROM sga.curso WHERE anio = 2099;
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id FROM sga.legajo l, sga.comision co JOIN sga.curso c ON c.id = co.curso_id
WHERE l.numero_legajo IN ('FAC-1', 'FAC-2') AND c.anio = 2099;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "d4d4d4d4-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.generar_facturas_mes('2040-09')$$, 'permission denied');
SELECT pg_temp.espera_error($$SELECT sga.actualizar_facturacion()$$, 'Solo Administración');
SELECT pg_temp.espera_error($$SELECT * FROM sga.facturas_para_gestionar(NULL, NULL, '')$$, 'Solo Administración');
SELECT pg_temp.espera_error($$INSERT INTO sga.valor_credito (vigente_desde, monto) VALUES (DATE '2041-01-01', 1)$$, 'row-level security');
SELECT sga.asegurar_mi_factura();
DO $$
BEGIN
    IF (SELECT estado FROM sga.factura WHERE periodo = '2040-04') <> 'VENCIDA' THEN
        RAISE EXCEPTION 'Facturación: la impaga con vencimiento pasado queda vencida';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.factura WHERE periodo = to_char(sga.hoy(), 'YYYY-MM')) THEN
        RAISE EXCEPTION 'Facturación: al entrar, el alumno tiene su factura del mes';
    END IF;
    IF (SELECT count(*) FROM sga.notificacion WHERE tipo = 'FACTURA') < 1 THEN
        RAISE EXCEPTION 'Facturación: el alumno recibe el aviso de la factura';
    END IF;
END;
$$;

-- Administración: cambia el valor, actualiza (factura al alumno 2 del mes en curso) y lista
SET LOCAL request.jwt.claims TO '{"sub": "d4d4d4d4-0000-0000-0000-000000000009"}';
INSERT INTO sga.valor_credito (vigente_desde, monto) VALUES (DATE '2041-01-01', 300);
SELECT sga.actualizar_facturacion();
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.facturas_para_gestionar(to_char(sga.hoy(), 'YYYY-MM'), NULL, 'fac-')) <> 2 THEN
        RAISE EXCEPTION 'Facturación: en el mes en curso deberían estar facturados los 2 alumnos';
    END IF;
    IF (SELECT count(*) FROM sga.facturas_para_gestionar(NULL, 'VENCIDA', 'FAC-1')) <> 1 THEN
        RAISE EXCEPTION 'Facturación: el filtro por estado encuentra la vencida';
    END IF;
END;
$$;

ROLLBACK;
