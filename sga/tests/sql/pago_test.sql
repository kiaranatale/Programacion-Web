-- Prueba del pago con Mercado Pago (20261010000000_pago_mercado_pago):
-- solo el dueño inicia el pago de su factura, un intento pendiente por
-- factura, y solo service_role registra pagos (idempotente y con control
-- de monto). Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Pago');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'PAG', 'Carrera de Prueba Pago', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Pago';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-PAG', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'PAG';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('cccccccc-0000-0000-0000-000000000001', 'alumno1.pag@test.local', now()),
    ('cccccccc-0000-0000-0000-000000000002', 'alumno2.pag@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '97000001', 'Uno', 'Pago', 'alumno1.pag@test.local'),
    ('DNI', '97000002', 'Dos', 'Pago', 'alumno2.pag@test.local');
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'PAG-' || right(p.nro_documento, 1), pl.id
FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('97000001', '97000002') AND pl.codigo = 'PLN-PAG';
INSERT INTO sga.factura (legajo_id, periodo, valor_credito_aplicado, monto_creditos, monto_total, fecha_vencimiento)
SELECT id, '2026-10', 1000, 5000, 5000, DATE '2026-10-10' FROM sga.legajo WHERE numero_legajo = 'PAG-1';

CREATE TEMP TABLE pag_ids (clave TEXT PRIMARY KEY, id INTEGER);
INSERT INTO pag_ids SELECT 'factura', f.id FROM sga.factura f JOIN sga.legajo l ON l.id = f.legajo_id WHERE l.numero_legajo = 'PAG-1';
GRANT SELECT, INSERT, UPDATE ON pag_ids TO authenticated, service_role;

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

SET LOCAL ROLE authenticated;

-- ---------- Otro alumno no puede pagar la factura ajena ----------
SET LOCAL request.jwt.claims TO '{"sub": "cccccccc-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error(format('SELECT * FROM sga.iniciar_pago_factura(%s)', id), 'no es tuya') FROM pag_ids WHERE clave = 'factura';

-- ---------- El dueño inicia dos veces: el primer intento se cancela ----------
SET LOCAL request.jwt.claims TO '{"sub": "cccccccc-0000-0000-0000-000000000001"}';
INSERT INTO pag_ids SELECT 'orden1', orden_pago_id FROM sga.iniciar_pago_factura((SELECT id FROM pag_ids WHERE clave = 'factura'));
SELECT sga.guardar_preferencia_mp((SELECT id FROM pag_ids WHERE clave = 'orden1'), 'pref-1', 'https://mp/1');
INSERT INTO pag_ids SELECT 'orden2', orden_pago_id FROM sga.iniciar_pago_factura((SELECT id FROM pag_ids WHERE clave = 'factura'));

DO $$
BEGIN
    IF (SELECT estado FROM sga.orden_pago WHERE id = (SELECT id FROM pag_ids WHERE clave = 'orden1')) <> 'CANCELADO'
        OR (SELECT estado FROM sga.orden_pago WHERE id = (SELECT id FROM pag_ids WHERE clave = 'orden2')) <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Pago: debería quedar un solo intento pendiente';
    END IF;
    IF (SELECT monto_total FROM sga.orden_pago WHERE id = (SELECT id FROM pag_ids WHERE clave = 'orden2')) <> 5000 THEN
        RAISE EXCEPTION 'Pago: la orden debería ser por el total de la factura';
    END IF;
END;
$$;

-- El alumno no puede registrar pagos ni tocar la orden
SELECT pg_temp.espera_error(format('SELECT sga.registrar_pago_mp(%s, %L, %L, 5000, %L)', id, 'x', 'approved', '{}'), 'permission denied') FROM pag_ids WHERE clave = 'orden2';
SELECT pg_temp.espera_error(format('SELECT sga.guardar_preferencia_mp(%s, %L, %L)', id, 'p', 'u'), 'ya no está pendiente') FROM pag_ids WHERE clave = 'orden1';

-- ---------- El servidor (service_role) registra pagos ----------
RESET ROLE;
SET LOCAL ROLE service_role;
DO $$
DECLARE v_orden INTEGER := (SELECT id FROM pag_ids WHERE clave = 'orden2');
BEGIN
    -- Pendiente en Mercado Pago: no cambia nada
    IF sga.registrar_pago_mp(v_orden, '111', 'in_process', 5000, '{}') <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Pago: un pago en proceso no debería marcar la orden';
    END IF;
    -- Aprobado pero por menos: no se da por pagada
    IF sga.registrar_pago_mp(v_orden, '112', 'approved', 100, '{}') <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Pago: un pago por menos del total no debería marcar la orden';
    END IF;
    IF sga.registrar_pago_mp(v_orden, '113', 'approved', 5000, '{"id": 113}') <> 'PAGADO' THEN
        RAISE EXCEPTION 'Pago: el pago aprobado debería marcar la orden';
    END IF;
    -- Repetido (webhook + vuelta del alumno): idempotente
    IF sga.registrar_pago_mp(v_orden, '113', 'approved', 5000, '{"id": 113}') <> 'PAGADO' THEN
        RAISE EXCEPTION 'Pago: registrar dos veces debería ser idempotente';
    END IF;
END;
$$;
RESET ROLE;

DO $$
BEGIN
    IF (SELECT estado FROM sga.factura WHERE id = (SELECT id FROM pag_ids WHERE clave = 'factura')) <> 'PAGADA' THEN
        RAISE EXCEPTION 'Pago: la factura debería quedar PAGADA';
    END IF;
    IF (SELECT external_payment_id FROM sga.orden_pago WHERE id = (SELECT id FROM pag_ids WHERE clave = 'orden2')) <> '113' THEN
        RAISE EXCEPTION 'Pago: no se guardó el id del pago';
    END IF;
    IF (SELECT count(*) FROM sga.evento_webhook_mp WHERE orden_pago_id = (SELECT id FROM pag_ids WHERE clave = 'orden2')) <> 4 THEN
        RAISE EXCEPTION 'Pago: deberían quedar registrados los 4 avisos';
    END IF;
END;
$$;

-- Pagada: ya no se puede volver a pagar
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "cccccccc-0000-0000-0000-000000000001"}';
SELECT pg_temp.espera_error(format('SELECT * FROM sga.iniciar_pago_factura(%s)', id), 'no tiene saldo') FROM pag_ids WHERE clave = 'factura';

ROLLBACK;
