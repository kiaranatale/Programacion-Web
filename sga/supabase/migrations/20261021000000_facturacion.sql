-- =====================================================================
-- Facturación automática. Administración solo fija el valor del crédito;
-- las facturas se generan solas.
--
--   - valor_credito: valor del crédito con su fecha de vigencia (la
--     factura usa el vigente al primer día del mes).
--   - generar_facturas_mes(periodo[, legajo]): una factura por alumno que
--     cursa en ese mes = créditos de sus materias CURSANDO cuyas fechas
--     tocan el mes × valor del crédito + adicionales activos − becas y
--     descuentos vigentes. Vence el día 10. Nunca duplica (quien ya tiene
--     factura del período se saltea; si se emite después del 10, vence
--     a los 10 días), así que se puede correr cuantas
--     veces haga falta. Avisa a cada alumno.
--   - Cuándo corre:
--       * todos los días, si la base tiene pg_cron (Supabase lo trae; se
--         programa abajo si la extensión está disponible);
--       * además, al entrar a Estado de cuenta (la del propio alumno,
--         asegurar_mi_factura()) y a Administración → Facturación
--         (actualizar_facturacion()), por si no hay pg_cron.
--   - Las PENDIENTE con el vencimiento pasado quedan VENCIDA en esas
--     mismas pasadas.
-- =====================================================================

CREATE TABLE sga.valor_credito (
    id SERIAL PRIMARY KEY,
    vigente_desde DATE NOT NULL UNIQUE,
    monto NUMERIC(12, 2) NOT NULL,

    CONSTRAINT ck_valor_credito_monto CHECK (monto > 0)
);

INSERT INTO sga.valor_credito (vigente_desde, monto) VALUES (DATE '2026-01-01', 72004);

ALTER TABLE sga.valor_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.valor_credito FORCE ROW LEVEL SECURITY;
CREATE POLICY valor_credito_select ON sga.valor_credito FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY valor_credito_admin_all ON sga.valor_credito
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON sga.valor_credito TO authenticated;

CREATE FUNCTION sga.formato_pesos(p NUMERIC)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT '$ ' || replace(replace(replace(to_char(p, 'FM999G999G990D00'), ',', '#'), '.', ','), '#', '.');
$$;

-- p_periodo: 'AAAA-MM'. p_legajo_id NULL = todos. Devuelve cuántas emitió.
CREATE FUNCTION sga.generar_facturas_mes(p_periodo TEXT, p_legajo_id INTEGER DEFAULT NULL)
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
          AND NOT EXISTS (SELECT 1 FROM sga.factura f WHERE f.legajo_id = l.id AND f.periodo = p_periodo)
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
        ON CONFLICT (legajo_id, periodo) DO NOTHING
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

CREATE FUNCTION sga.marcar_facturas_vencidas(p_legajo_id INTEGER DEFAULT NULL)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_cantidad INTEGER;
BEGIN
    UPDATE sga.factura SET estado = 'VENCIDA'
    WHERE estado = 'PENDIENTE' AND fecha_vencimiento < sga.hoy() AND (p_legajo_id IS NULL OR legajo_id = p_legajo_id);
    GET DIAGNOSTICS v_cantidad = ROW_COUNT;
    RETURN v_cantidad;
END;
$$;

-- La pasada diaria: factura el mes en curso y marca vencidas.
CREATE FUNCTION sga.facturacion_diaria()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_emitidas INTEGER;
BEGIN
    v_emitidas := sga.generar_facturas_mes(to_char(sga.hoy(), 'YYYY-MM'));
    PERFORM sga.marcar_facturas_vencidas();
    RETURN v_emitidas;
END;
$$;

-- El alumno, al entrar a su estado de cuenta: su factura del mes y sus vencidas.
CREATE FUNCTION sga.asegurar_mi_factura()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo INTEGER := sga.legajo_actual_id();
BEGIN
    IF v_legajo IS NULL THEN
        RETURN;
    END IF;
    PERFORM sga.generar_facturas_mes(to_char(sga.hoy(), 'YYYY-MM'), v_legajo);
    PERFORM sga.marcar_facturas_vencidas(v_legajo);
END;
$$;

-- Administración, al entrar a Facturación.
CREATE FUNCTION sga.actualizar_facturacion()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM sga.validar_admin();
    RETURN sga.facturacion_diaria();
END;
$$;

-- Administración: facturas con el alumno, para el listado.
CREATE FUNCTION sga.facturas_para_gestionar(p_periodo TEXT, p_estado TEXT, p_texto TEXT)
RETURNS TABLE (
    id INTEGER,
    periodo TEXT,
    apellido TEXT,
    nombre TEXT,
    numero_legajo TEXT,
    creditos_cursados INTEGER,
    valor_credito_aplicado NUMERIC,
    monto_total NUMERIC,
    fecha_vencimiento DATE,
    estado TEXT,
    fecha_pago TIMESTAMP
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_q TEXT := '%' || lower(btrim(coalesce(p_texto, ''))) || '%';
BEGIN
    PERFORM sga.validar_admin();
    RETURN QUERY
    SELECT f.id, f.periodo::TEXT, pe.apellido::TEXT, pe.nombre::TEXT, l.numero_legajo::TEXT, f.creditos_cursados,
           f.valor_credito_aplicado, f.monto_total, f.fecha_vencimiento, f.estado::TEXT,
           (SELECT max(o.fecha_pago) FROM sga.orden_pago_factura opf JOIN sga.orden_pago o ON o.id = opf.orden_pago_id
            WHERE opf.factura_id = f.id AND o.estado = 'PAGADO')
    FROM sga.factura f
    JOIN sga.legajo l ON l.id = f.legajo_id
    JOIN sga.persona pe ON pe.id = l.persona_id
    WHERE (p_periodo IS NULL OR f.periodo = p_periodo)
      AND (p_estado IS NULL OR f.estado::TEXT = p_estado)
      AND lower(pe.apellido || ' ' || pe.nombre || ' ' || l.numero_legajo) LIKE v_q
    ORDER BY f.periodo DESC, pe.apellido, pe.nombre
    LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.formato_pesos(NUMERIC),
    sga.generar_facturas_mes(TEXT, INTEGER),
    sga.marcar_facturas_vencidas(INTEGER),
    sga.facturacion_diaria(),
    sga.asegurar_mi_factura(),
    sga.actualizar_facturacion(),
    sga.facturas_para_gestionar(TEXT, TEXT, TEXT)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    sga.asegurar_mi_factura(),
    sga.actualizar_facturacion(),
    sga.facturas_para_gestionar(TEXT, TEXT, TEXT)
TO authenticated;

-- Pasada diaria a las 03:05 (hora de Buenos Aires = 06:05 UTC), solo si
-- la base tiene pg_cron (Supabase sí; el Postgres de CI no).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
        PERFORM cron.schedule('sga-facturacion-diaria', '5 6 * * *', 'SELECT sga.facturacion_diaria()');
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Sin permisos para pg_cron: las facturas se generan igual al entrar
    -- a Estado de cuenta o a Facturación.
    RAISE NOTICE 'No se pudo programar la facturación diaria: %', SQLERRM;
END;
$$;
