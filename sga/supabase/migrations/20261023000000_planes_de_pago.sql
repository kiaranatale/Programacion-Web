-- =====================================================================
-- Planes de pago: el alumno con facturas vencidas pide pagarlas en
-- cuotas; Administración aprueba o rechaza.
--
--   - plan_pago: SOLICITADO → APROBADO | RECHAZADO; SOLICITADO →
--     CANCELADO (el alumno). Se pide por todas las facturas vencidas, en
--     2 a 6 cuotas. Una solicitud a la vez.
--   - Al aprobar: las facturas incluidas (si siguen impagas) quedan
--     ANULADA con el motivo "Incluida en el plan de pago N.º X" y se crean
--     las cuotas como facturas (factura.plan_pago_id, cuota_numero), con
--     vencimiento el 10 de los meses siguientes. Se pagan con Mercado Pago
--     como cualquier factura.
--   - La factura mensual sigue siendo una por mes: la clave única pasa a
--     ser (legajo, período, plan) con NULLS NOT DISTINCT, así una cuota
--     puede caer en el mismo mes que la factura mensual.
-- =====================================================================

CREATE TABLE sga.plan_pago (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    cuotas INTEGER NOT NULL,
    monto_total NUMERIC(12, 2) NOT NULL,
    motivo TEXT,
    estado TEXT NOT NULL DEFAULT 'SOLICITADO',
    observaciones TEXT,
    fecha_solicitud TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_resolucion TIMESTAMPTZ,

    CONSTRAINT ck_plan_pago_cuotas CHECK (cuotas BETWEEN 2 AND 6),
    CONSTRAINT ck_plan_pago_estado CHECK (estado IN ('SOLICITADO', 'APROBADO', 'RECHAZADO', 'CANCELADO'))
);
CREATE INDEX ix_plan_pago_legajo_id ON sga.plan_pago (legajo_id);

CREATE TABLE sga.plan_pago_factura (
    plan_pago_id INTEGER NOT NULL REFERENCES sga.plan_pago (id) ON DELETE CASCADE,
    factura_id INTEGER NOT NULL REFERENCES sga.factura (id) ON DELETE RESTRICT,
    PRIMARY KEY (plan_pago_id, factura_id)
);

ALTER TABLE sga.factura
    ADD COLUMN plan_pago_id INTEGER REFERENCES sga.plan_pago (id) ON DELETE RESTRICT,
    ADD COLUMN cuota_numero INTEGER,
    ADD COLUMN motivo_anulacion TEXT,
    DROP CONSTRAINT uq_factura_legajo_periodo,
    ADD CONSTRAINT uq_factura_legajo_periodo UNIQUE NULLS NOT DISTINCT (legajo_id, periodo, plan_pago_id),
    ADD CONSTRAINT ck_factura_cuota CHECK ((plan_pago_id IS NULL) = (cuota_numero IS NULL));

ALTER TABLE sga.plan_pago ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.plan_pago FORCE ROW LEVEL SECURITY;
CREATE POLICY plan_pago_select ON sga.plan_pago
    FOR SELECT TO authenticated USING (legajo_id = sga.legajo_actual_id() OR sga.es_admin());
GRANT SELECT ON sga.plan_pago TO authenticated;

ALTER TABLE sga.plan_pago_factura ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.plan_pago_factura FORCE ROW LEVEL SECURITY;
CREATE POLICY plan_pago_factura_select ON sga.plan_pago_factura
    FOR SELECT TO authenticated USING (
        sga.es_admin() OR EXISTS (SELECT 1 FROM sga.plan_pago p WHERE p.id = plan_pago_id AND p.legajo_id = sga.legajo_actual_id())
    );
GRANT SELECT ON sga.plan_pago_factura TO authenticated;

-- La facturación mensual no tiene en cuenta las cuotas.
CREATE OR REPLACE FUNCTION sga.generar_facturas_mes(p_periodo TEXT, p_legajo_id INTEGER DEFAULT NULL)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_desde DATE := (p_periodo || '-01')::DATE;
    v_hasta DATE := ((p_periodo || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    v_vence DATE := (p_periodo || '-10')::DATE;
    v_valor NUMERIC;
    v_alumno RECORD;
    v_factura INTEGER;
    v_adicionales NUMERIC;
    v_descuentos NUMERIC;
    v_total NUMERIC;
    v_emitidas INTEGER := 0;
BEGIN
    SELECT monto INTO v_valor FROM sga.valor_credito WHERE vigente_desde <= v_desde ORDER BY vigente_desde DESC LIMIT 1;
    IF v_valor IS NULL THEN
        RETURN 0;
    END IF;

    FOR v_alumno IN
        SELECT l.id AS legajo_id, l.persona_id, sum(coalesce(m.creditos, 0))::INTEGER AS creditos
        FROM sga.legajo l
        JOIN sga.inscripcion_curso ic ON ic.legajo_id = l.id AND ic.estado = 'CURSANDO'
        JOIN sga.curso c ON c.id = ic.curso_id AND c.fecha_inicio <= v_hasta AND c.fecha_fin >= v_desde
        JOIN sga.materia m ON m.id = c.materia_id
        WHERE (p_legajo_id IS NULL OR l.id = p_legajo_id)
          AND NOT EXISTS (SELECT 1 FROM sga.factura f WHERE f.legajo_id = l.id AND f.periodo = p_periodo AND f.plan_pago_id IS NULL)
        GROUP BY l.id, l.persona_id
        HAVING sum(coalesce(m.creditos, 0)) > 0
    LOOP
        SELECT coalesce(sum(i.monto), 0) INTO v_adicionales
        FROM sga.item_facturable_legajo il JOIN sga.item_facturable i ON i.id = il.item_facturable_id
        WHERE il.legajo_id = v_alumno.legajo_id AND il.activo AND i.activo
          AND il.fecha_desde <= v_hasta AND (il.fecha_hasta IS NULL OR il.fecha_hasta >= v_desde);
        SELECT coalesce(sum(b.monto), 0) INTO v_descuentos
        FROM sga.beca_descuento_legajo b
        WHERE b.legajo_id = v_alumno.legajo_id AND b.fecha_desde <= v_hasta AND (b.fecha_hasta IS NULL OR b.fecha_hasta >= v_desde);
        v_total := greatest(v_alumno.creditos * v_valor + v_adicionales - v_descuentos, 0);

        INSERT INTO sga.factura (legajo_id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos,
                                 monto_adicionales, monto_descuentos, monto_total, fecha_emision, fecha_vencimiento)
        VALUES (v_alumno.legajo_id, p_periodo, v_alumno.creditos, v_valor, v_alumno.creditos * v_valor,
                v_adicionales, v_descuentos, v_total, greatest(sga.hoy(), v_desde),
                CASE WHEN sga.hoy() <= v_vence THEN v_vence ELSE sga.hoy() + 10 END)
        ON CONFLICT (legajo_id, periodo, plan_pago_id) DO NOTHING
        RETURNING id INTO v_factura;
        CONTINUE WHEN v_factura IS NULL;

        INSERT INTO sga.factura_detalle (factura_id, tipo, descripcion, monto)
        VALUES (v_factura, 'CREDITOS', format('%s créditos × %s', v_alumno.creditos, sga.formato_pesos(v_valor)), v_alumno.creditos * v_valor);
        INSERT INTO sga.factura_detalle (factura_id, tipo, referencia_item_facturable_id, descripcion, monto)
        SELECT v_factura, 'ADICIONAL', i.id, i.nombre, i.monto
        FROM sga.item_facturable_legajo il JOIN sga.item_facturable i ON i.id = il.item_facturable_id
        WHERE il.legajo_id = v_alumno.legajo_id AND il.activo AND i.activo
          AND il.fecha_desde <= v_hasta AND (il.fecha_hasta IS NULL OR il.fecha_hasta >= v_desde);
        INSERT INTO sga.factura_detalle (factura_id, tipo, referencia_beca_descuento_id, descripcion, monto)
        SELECT v_factura, bd.tipo::TEXT, bd.id, bd.nombre, -b.monto
        FROM sga.beca_descuento_legajo b JOIN sga.beca_descuento bd ON bd.id = b.beca_descuento_id
        WHERE b.legajo_id = v_alumno.legajo_id AND b.fecha_desde <= v_hasta AND (b.fecha_hasta IS NULL OR b.fecha_hasta >= v_desde);

        INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
        VALUES (v_alumno.persona_id, 'FACTURA',
                format('Se emitió tu factura de %s: %s', p_periodo, sga.formato_pesos(v_total)));
        v_emitidas := v_emitidas + 1;
    END LOOP;
    RETURN v_emitidas;
END;
$$;

-- Facturas que entran en un plan: vencidas, sin plan y sin pago en curso.
CREATE FUNCTION sga.facturas_para_plan(p_legajo_id INTEGER)
RETURNS SETOF sga.factura
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT f.* FROM sga.factura f
    WHERE f.legajo_id = p_legajo_id AND f.estado = 'VENCIDA'
      AND NOT EXISTS (
          SELECT 1 FROM sga.orden_pago_factura opf JOIN sga.orden_pago o ON o.id = opf.orden_pago_id
          WHERE opf.factura_id = f.id AND o.estado = 'PENDIENTE'
      )
    ORDER BY f.periodo;
$$;

CREATE FUNCTION sga.solicitar_plan_pago(p_cuotas INTEGER, p_motivo TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
    v_total NUMERIC;
    v_id INTEGER;
BEGIN
    IF v_legajo IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    IF p_cuotas IS NULL OR p_cuotas NOT BETWEEN 2 AND 6 THEN
        RAISE EXCEPTION 'Elegí entre 2 y 6 cuotas' USING ERRCODE = '23514';
    END IF;
    PERFORM 1 FROM sga.legajo WHERE id = v_legajo FOR UPDATE;
    IF EXISTS (SELECT 1 FROM sga.plan_pago WHERE legajo_id = v_legajo AND estado = 'SOLICITADO') THEN
        RAISE EXCEPTION 'Ya tenés un pedido de plan de pago esperando respuesta' USING ERRCODE = '23505';
    END IF;
    PERFORM sga.marcar_facturas_vencidas(v_legajo);
    SELECT sum(monto_total) INTO v_total FROM sga.facturas_para_plan(v_legajo);
    IF v_total IS NULL OR v_total <= 0 THEN
        RAISE EXCEPTION 'No tenés facturas vencidas para incluir en un plan' USING ERRCODE = '23514';
    END IF;
    INSERT INTO sga.plan_pago (legajo_id, cuotas, monto_total, motivo)
    VALUES (v_legajo, p_cuotas, v_total, NULLIF(btrim(p_motivo), '')) RETURNING id INTO v_id;
    INSERT INTO sga.plan_pago_factura (plan_pago_id, factura_id) SELECT v_id, f.id FROM sga.facturas_para_plan(v_legajo) f;
    RETURN v_id;
END;
$$;

CREATE FUNCTION sga.cancelar_plan_pago(p_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE sga.plan_pago SET estado = 'CANCELADO', fecha_resolucion = now()
    WHERE id = p_id AND legajo_id = sga.legajo_actual_id() AND estado = 'SOLICITADO';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No tenés un pedido pendiente con ese número' USING ERRCODE = '42501';
    END IF;
END;
$$;

CREATE FUNCTION sga.resolver_plan_pago(p_id INTEGER, p_aprobar BOOLEAN, p_observaciones TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_plan sga.plan_pago%ROWTYPE;
    v_persona INTEGER;
    v_total NUMERIC;
    v_cuota NUMERIC;
    v_mes DATE;
    i INTEGER;
BEGIN
    PERFORM sga.validar_admin();
    SELECT * INTO v_plan FROM sga.plan_pago WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El plan no existe' USING ERRCODE = 'P0002';
    END IF;
    IF v_plan.estado <> 'SOLICITADO' THEN
        RAISE EXCEPTION 'El pedido ya fue resuelto' USING ERRCODE = '23514';
    END IF;
    SELECT persona_id INTO v_persona FROM sga.legajo WHERE id = v_plan.legajo_id;

    IF NOT p_aprobar THEN
        IF NULLIF(btrim(p_observaciones), '') IS NULL THEN
            RAISE EXCEPTION 'Indicá el motivo del rechazo' USING ERRCODE = '23514';
        END IF;
        UPDATE sga.plan_pago SET estado = 'RECHAZADO', observaciones = btrim(p_observaciones), fecha_resolucion = now() WHERE id = p_id;
        INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
        VALUES (v_persona, 'FACTURA', format('Tu pedido de plan de pago N.º %s fue rechazado: %s', p_id, btrim(p_observaciones)));
        RETURN;
    END IF;

    -- Solo lo que siga impago (pudo haberse pagado mientras esperaba)
    DELETE FROM sga.plan_pago_factura pf USING sga.factura f
    WHERE pf.plan_pago_id = p_id AND f.id = pf.factura_id AND f.estado NOT IN ('PENDIENTE', 'VENCIDA');
    SELECT sum(f.monto_total) INTO v_total
    FROM sga.plan_pago_factura pf JOIN sga.factura f ON f.id = pf.factura_id WHERE pf.plan_pago_id = p_id;
    IF v_total IS NULL OR v_total <= 0 THEN
        UPDATE sga.plan_pago SET estado = 'CANCELADO', observaciones = 'Las facturas ya estaban pagas', fecha_resolucion = now() WHERE id = p_id;
        RAISE EXCEPTION 'Las facturas del pedido ya están pagas: se canceló el pedido' USING ERRCODE = '23514';
    END IF;

    UPDATE sga.orden_pago SET estado = 'CANCELADO'
    WHERE estado = 'PENDIENTE' AND id IN (
        SELECT opf.orden_pago_id FROM sga.orden_pago_factura opf JOIN sga.plan_pago_factura pf ON pf.factura_id = opf.factura_id
        WHERE pf.plan_pago_id = p_id);
    UPDATE sga.factura f SET estado = 'ANULADA', motivo_anulacion = format('Incluida en el plan de pago N.º %s', p_id)
    FROM sga.plan_pago_factura pf WHERE pf.plan_pago_id = p_id AND f.id = pf.factura_id;

    -- Cuotas iguales (la última ajusta el redondeo), vencen el 10 de los meses siguientes
    v_cuota := round(v_total / v_plan.cuotas, 2);
    v_mes := date_trunc('month', sga.hoy() + INTERVAL '1 month')::DATE;
    FOR i IN 1 .. v_plan.cuotas LOOP
        INSERT INTO sga.factura (legajo_id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos,
                                 monto_adicionales, monto_total, fecha_emision, fecha_vencimiento, plan_pago_id, cuota_numero)
        VALUES (v_plan.legajo_id, to_char(v_mes, 'YYYY-MM'), 0, 0, 0,
                CASE WHEN i < v_plan.cuotas THEN v_cuota ELSE v_total - v_cuota * (v_plan.cuotas - 1) END,
                CASE WHEN i < v_plan.cuotas THEN v_cuota ELSE v_total - v_cuota * (v_plan.cuotas - 1) END,
                sga.hoy(), v_mes + 9, p_id, i);
        INSERT INTO sga.factura_detalle (factura_id, tipo, descripcion, monto)
        SELECT currval(pg_get_serial_sequence('sga.factura', 'id')), 'PLAN_PAGO',
               format('Plan de pago N.º %s · cuota %s de %s', p_id, i, v_plan.cuotas),
               CASE WHEN i < v_plan.cuotas THEN v_cuota ELSE v_total - v_cuota * (v_plan.cuotas - 1) END;
        v_mes := (v_mes + INTERVAL '1 month')::DATE;
    END LOOP;

    UPDATE sga.plan_pago SET estado = 'APROBADO', monto_total = v_total, observaciones = NULLIF(btrim(p_observaciones), ''),
                             fecha_resolucion = now()
    WHERE id = p_id;
    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    VALUES (v_persona, 'FACTURA', format('Se aprobó tu plan de pago N.º %s: %s cuotas de %s', p_id, v_plan.cuotas, sga.formato_pesos(v_cuota)));
END;
$$;

-- Planes con el alumno y cuánto lleva pagado.
CREATE FUNCTION sga.planes_de_pago(p_solo_mios BOOLEAN)
RETURNS TABLE (
    id INTEGER,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    cuotas INTEGER,
    monto_total NUMERIC,
    motivo TEXT,
    estado TEXT,
    observaciones TEXT,
    fecha_solicitud TIMESTAMPTZ,
    facturas TEXT,
    cuotas_pagas INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT p_solo_mios THEN
        PERFORM sga.validar_admin();
    END IF;
    RETURN QUERY
    SELECT p.id, pe.apellido::TEXT, pe.nombre::TEXT, l.numero_legajo::TEXT, p.cuotas, p.monto_total, p.motivo, p.estado,
           p.observaciones, p.fecha_solicitud,
           (SELECT string_agg(f.periodo, ', ' ORDER BY f.periodo) FROM sga.plan_pago_factura pf JOIN sga.factura f ON f.id = pf.factura_id
            WHERE pf.plan_pago_id = p.id),
           (SELECT count(*) FROM sga.factura f WHERE f.plan_pago_id = p.id AND f.estado = 'PAGADA')::INTEGER
    FROM sga.plan_pago p
    JOIN sga.legajo l ON l.id = p.legajo_id
    JOIN sga.persona pe ON pe.id = l.persona_id
    WHERE (NOT p_solo_mios OR p.legajo_id = sga.legajo_actual_id())
    ORDER BY p.estado <> 'SOLICITADO', p.fecha_solicitud DESC
    LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.facturas_para_plan(INTEGER),
    sga.solicitar_plan_pago(INTEGER, TEXT),
    sga.cancelar_plan_pago(INTEGER),
    sga.resolver_plan_pago(INTEGER, BOOLEAN, TEXT),
    sga.planes_de_pago(BOOLEAN)
FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION sga.generar_facturas_mes(TEXT, INTEGER) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    sga.solicitar_plan_pago(INTEGER, TEXT),
    sga.cancelar_plan_pago(INTEGER),
    sga.resolver_plan_pago(INTEGER, BOOLEAN, TEXT),
    sga.planes_de_pago(BOOLEAN)
TO authenticated;
