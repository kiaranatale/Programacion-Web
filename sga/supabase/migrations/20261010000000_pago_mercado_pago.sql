-- =====================================================================
-- Pago de facturas con Mercado Pago (Checkout Pro).
--
--   1. El alumno inicia el pago de una factura propia pendiente o vencida
--      (iniciar_pago_factura): se crea una orden de pago; si la factura
--      tenía otra orden pendiente, esa se cancela.
--   2. La app crea la preferencia en Mercado Pago y la guarda
--      (guardar_preferencia_mp) con el link de pago.
--   3. Al volver de Mercado Pago o al llegar el webhook, el servidor
--      consulta el pago a la API de Mercado Pago y lo registra
--      (registrar_pago_mp, solo service_role): si está aprobado y el monto
--      coincide, la orden pasa a PAGADO y el trigger existente marca las
--      facturas como PAGADA. Es idempotente.
-- =====================================================================

ALTER TABLE sga.orden_pago ADD COLUMN checkout_url VARCHAR;
ALTER TABLE sga.orden_pago ADD COLUMN estado_mp VARCHAR;

CREATE FUNCTION sga.iniciar_pago_factura(p_factura_id INTEGER)
RETURNS TABLE (orden_pago_id INTEGER, monto NUMERIC, periodo TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_factura sga.factura%ROWTYPE;
    v_orden INTEGER;
BEGIN
    SELECT * INTO v_factura FROM sga.factura WHERE id = p_factura_id;
    IF NOT FOUND OR v_factura.legajo_id IS DISTINCT FROM sga.legajo_actual_id() THEN
        RAISE EXCEPTION 'La factura no es tuya' USING ERRCODE = '42501';
    END IF;
    IF v_factura.estado NOT IN ('PENDIENTE', 'VENCIDA') THEN
        RAISE EXCEPTION 'La factura no tiene saldo para pagar' USING ERRCODE = '23514';
    END IF;

    -- Un solo intento pendiente por factura: el anterior se cancela
    UPDATE sga.orden_pago op SET estado = 'CANCELADO'
    WHERE op.estado = 'PENDIENTE'
      AND op.id IN (SELECT opf.orden_pago_id FROM sga.orden_pago_factura opf WHERE opf.factura_id = p_factura_id);

    INSERT INTO sga.orden_pago (legajo_id, monto_total, fecha_expiracion)
    VALUES (v_factura.legajo_id, v_factura.monto_total, now() + INTERVAL '1 day')
    RETURNING id INTO v_orden;
    INSERT INTO sga.orden_pago_factura (orden_pago_id, factura_id) VALUES (v_orden, p_factura_id);

    RETURN QUERY SELECT v_orden, v_factura.monto_total, v_factura.periodo::TEXT;
END;
$$;

CREATE FUNCTION sga.guardar_preferencia_mp(p_orden_pago_id INTEGER, p_preference_id TEXT, p_checkout_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE sga.orden_pago
    SET external_preference_id = p_preference_id, checkout_url = p_checkout_url
    WHERE id = p_orden_pago_id AND legajo_id = sga.legajo_actual_id() AND estado = 'PENDIENTE';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de pago no es tuya o ya no está pendiente' USING ERRCODE = '42501';
    END IF;
END;
$$;

-- Lo llama el servidor con service_role después de consultar el pago a
-- la API de Mercado Pago (nunca con datos que mande el navegador).
-- Devuelve el estado de la orden después de registrar.
CREATE FUNCTION sga.registrar_pago_mp(
    p_orden_pago_id INTEGER,
    p_payment_id TEXT,
    p_estado_mp TEXT,
    p_monto NUMERIC,
    p_payload JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_orden sga.orden_pago%ROWTYPE;
BEGIN
    INSERT INTO sga.evento_webhook_mp (orden_pago_id, payload, procesado)
    VALUES ((SELECT id FROM sga.orden_pago WHERE id = p_orden_pago_id), p_payload, FALSE);

    SELECT * INTO v_orden FROM sga.orden_pago WHERE id = p_orden_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN 'DESCONOCIDA';
    END IF;
    IF v_orden.estado = 'PAGADO' THEN
        RETURN 'PAGADO';
    END IF;

    UPDATE sga.orden_pago SET estado_mp = p_estado_mp, external_payment_id = p_payment_id WHERE id = v_orden.id;

    -- Aprobado y por el monto completo: pagada (aunque la orden se haya
    -- cancelado por un intento posterior, la plata entró)
    IF p_estado_mp = 'approved' AND round(p_monto, 2) >= round(v_orden.monto_total, 2) THEN
        UPDATE sga.orden_pago SET estado = 'PAGADO', fecha_pago = now() WHERE id = v_orden.id;
        UPDATE sga.evento_webhook_mp SET procesado = TRUE
        WHERE id = (SELECT max(id) FROM sga.evento_webhook_mp WHERE orden_pago_id = v_orden.id);
        RETURN 'PAGADO';
    END IF;

    RETURN v_orden.estado::TEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.iniciar_pago_factura(INTEGER),
    sga.guardar_preferencia_mp(INTEGER, TEXT, TEXT),
    sga.registrar_pago_mp(INTEGER, TEXT, TEXT, NUMERIC, JSONB)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    sga.iniciar_pago_factura(INTEGER),
    sga.guardar_preferencia_mp(INTEGER, TEXT, TEXT)
TO authenticated;

GRANT EXECUTE ON FUNCTION sga.registrar_pago_mp(INTEGER, TEXT, TEXT, NUMERIC, JSONB) TO service_role;
