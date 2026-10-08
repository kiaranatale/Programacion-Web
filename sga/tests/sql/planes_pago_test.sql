-- Prueba de planes de pago (20261023000000_planes_de_pago): pedido sobre
-- facturas vencidas, cancelación, rechazo, aprobación con cuotas y que la
-- facturación mensual siga emitiendo una factura por mes.
-- Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Ppg');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id) SELECT 'PPG', 'Carrera Ppg', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Ppg';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde) SELECT id, 'PLN-PPG', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'PPG';
INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('f6f6f6f6-0000-0000-0000-000000000001', 'a1.ppg@test.local', now()),
    ('f6f6f6f6-0000-0000-0000-000000000002', 'a2.ppg@test.local', now()),
    ('f6f6f6f6-0000-0000-0000-000000000009', 'admin.ppg@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99910001', 'Alumno1', 'Ppg', 'a1.ppg@test.local'),
    ('DNI', '99910002', 'Alumno2', 'Ppg', 'a2.ppg@test.local'),
    ('DNI', '99910009', 'Admin', 'Ppg', 'admin.ppg@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99910009';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'PPG-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99910001', '99910002') AND pl.codigo = 'PLN-PPG';
-- Alumno 1: dos facturas vencidas (1000 y 2000) y una paga; alumno 2: nada vencido
INSERT INTO sga.factura (legajo_id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos, monto_total, fecha_emision, fecha_vencimiento, estado)
SELECT l.id, x.p, 1, x.m, x.m, x.m, DATE '2026-01-01', DATE '2026-01-10', x.e::sga.estado_factura
FROM sga.legajo l, (VALUES ('2026-01', 1000, 'VENCIDA'), ('2026-02', 2000, 'PENDIENTE'), ('2026-03', 500, 'PAGADA')) AS x (p, m, e)
WHERE l.numero_legajo = 'PPG-1';

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
CREATE TEMP TABLE ppg (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON ppg TO authenticated;
CREATE FUNCTION pg_temp.p(c TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM ppg WHERE clave = c $$;
GRANT EXECUTE ON FUNCTION pg_temp.p(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error($$SELECT sga.solicitar_plan_pago(3, NULL)$$, 'No tenés facturas vencidas');

SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error($$SELECT sga.solicitar_plan_pago(12, NULL)$$, 'entre 2 y 6');
-- Pide, cancela, vuelve a pedir
INSERT INTO ppg SELECT 'primero', sga.solicitar_plan_pago(2, 'Me quedé sin trabajo');
SELECT pg_temp.espera_error($$SELECT sga.solicitar_plan_pago(3, NULL)$$, 'esperando respuesta');
SELECT sga.cancelar_plan_pago(pg_temp.p('primero'));
INSERT INTO ppg SELECT 'rechazado', sga.solicitar_plan_pago(2, NULL);
SELECT pg_temp.espera_error($$SELECT sga.resolver_plan_pago(pg_temp.p('rechazado'), TRUE, NULL)$$, 'Solo Administración');
DO $$
BEGIN
    -- La de febrero estaba PENDIENTE pero ya venció: también entra (3000 en total)
    IF (SELECT monto_total FROM sga.planes_de_pago(TRUE) WHERE id = pg_temp.p('rechazado')) <> 3000 THEN
        RAISE EXCEPTION 'Planes: el pedido incluye las dos vencidas (3000)';
    END IF;
END;
$$;

SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000009"}';
SELECT pg_temp.espera_error($$SELECT sga.resolver_plan_pago(pg_temp.p('rechazado'), FALSE, '')$$, 'motivo del rechazo');
SELECT sga.resolver_plan_pago(pg_temp.p('rechazado'), FALSE, 'Primero regularizá la documentación');
SELECT pg_temp.espera_error($$SELECT sga.resolver_plan_pago(pg_temp.p('rechazado'), TRUE, NULL)$$, 'ya fue resuelto');

SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000001"}';
INSERT INTO ppg SELECT 'aprobado', sga.solicitar_plan_pago(3, NULL);
SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000009"}';
SELECT sga.resolver_plan_pago(pg_temp.p('aprobado'), TRUE, NULL);
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'PPG-1' AND f.estado = 'ANULADA'
        AND f.motivo_anulacion LIKE 'Incluida en el plan de pago%') <> 2 THEN
        RAISE EXCEPTION 'Planes: las 2 vencidas quedan anuladas por el plan';
    END IF;
    IF (SELECT count(*) || '|' || sum(monto_total) || '|' || min(fecha_vencimiento - date_trunc('month', fecha_vencimiento)::DATE)
        FROM sga.factura WHERE plan_pago_id = pg_temp.p('aprobado')) <> '3|3000.00|9' THEN
        RAISE EXCEPTION 'Planes: 3 cuotas que suman 3000 y vencen el 10';
    END IF;
    IF (SELECT string_agg(monto_total::TEXT, ',' ORDER BY cuota_numero) FROM sga.factura WHERE plan_pago_id = pg_temp.p('aprobado')) <> '1000.00,1000.00,1000.00' THEN
        RAISE EXCEPTION 'Planes: cuotas iguales';
    END IF;
END;
$$;

-- La facturación mensual sigue emitiendo la factura del mes aunque haya una cuota ese mes
RESET ROLE;
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Ppg');
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos) SELECT 'PPG.01', 'Materia PPG.01', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Ppg';
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT id, 2099, '1C', sga.hoy() - 60, sga.hoy() + 120 FROM sga.materia WHERE codigo = 'PPG.01';
INSERT INTO sga.comision (curso_id, nombre) SELECT c.id, 'A' FROM sga.curso c JOIN sga.materia m ON m.id = c.materia_id WHERE m.codigo = 'PPG.01';
INSERT INTO sga.inscripcion_curso (legajo_id, curso_id, comision_id)
SELECT l.id, co.curso_id, co.id FROM sga.legajo l, sga.comision co JOIN sga.curso c ON c.id = co.curso_id JOIN sga.materia m ON m.id = c.materia_id
WHERE l.numero_legajo = 'PPG-1' AND m.codigo = 'PPG.01';
DO $$
DECLARE
    v_mes TEXT := to_char(date_trunc('month', sga.hoy() + INTERVAL '1 month'), 'YYYY-MM');
BEGIN
    IF sga.generar_facturas_mes(v_mes) < 1 THEN
        RAISE EXCEPTION 'Planes: el mes de la primera cuota igual tiene factura mensual';
    END IF;
    IF (SELECT count(*) FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'PPG-1' AND f.periodo = v_mes) <> 2 THEN
        RAISE EXCEPTION 'Planes: ese mes hay cuota + factura mensual';
    END IF;
    IF sga.generar_facturas_mes(v_mes) <> 0 THEN
        RAISE EXCEPTION 'Planes: la mensual no se duplica';
    END IF;
END;
$$;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000001"}';
DO $$
BEGIN
    IF (SELECT string_agg(estado || ':' || cuotas_pagas, ',' ORDER BY id) FROM sga.planes_de_pago(TRUE)) <> 'CANCELADO:0,RECHAZADO:0,APROBADO:0' THEN
        RAISE EXCEPTION 'Planes: el alumno ve sus 3 pedidos con su estado';
    END IF;
    IF (SELECT count(*) FROM sga.notificacion WHERE mensaje LIKE '%plan de pago%') <> 2 THEN
        RAISE EXCEPTION 'Planes: avisos de rechazo y aprobación';
    END IF;
END;
$$;
SET LOCAL request.jwt.claims TO '{"sub": "f6f6f6f6-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error($$SELECT * FROM sga.planes_de_pago(FALSE)$$, 'Solo Administración');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.plan_pago) + (SELECT count(*) FROM sga.planes_de_pago(TRUE)) <> 0 THEN
        RAISE EXCEPTION 'Planes: el alumno 2 no ve planes ajenos';
    END IF;
END;
$$;

ROLLBACK;
