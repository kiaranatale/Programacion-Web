-- =====================================================================
-- Facturas impagas de la alumna demo para probar el pago con Mercado
-- Pago (correr DESPUÉS de seed_legajo_demo.sql).
--
--   - 2026-09: vencida.
--   - 2026-10: pendiente.
--   Cada una con sus renglones: créditos y ADITBA.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.factura (legajo_id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos,
                         monto_adicionales, monto_total, fecha_emision, fecha_vencimiento, estado)
SELECT l.id, x.periodo, 6, 72004, 432024, 1500, 433524, x.emision, x.vence, x.estado::sga.estado_factura
FROM sga.legajo l
CROSS JOIN (VALUES
    ('2026-09', DATE '2026-09-01', DATE '2026-09-10', 'VENCIDA'),
    ('2026-10', DATE '2026-10-01', DATE '2026-10-12', 'PENDIENTE')
) AS x (periodo, emision, vence, estado)
WHERE l.numero_legajo = 'DEMO-001'
ON CONFLICT (legajo_id, periodo) DO NOTHING;

INSERT INTO sga.factura_detalle (factura_id, tipo, referencia_item_facturable_id, descripcion, monto)
SELECT f.id, x.tipo, i.id, x.descripcion, x.monto
FROM sga.factura f
JOIN sga.legajo l ON l.id = f.legajo_id AND l.numero_legajo = 'DEMO-001'
CROSS JOIN (VALUES
    ('CREDITOS', NULL, '6 créditos × $ 72.004,00', 432024),
    ('ADICIONAL', 'ADITBA', 'ADITBA (Padre)', 1500)
) AS x (tipo, item, descripcion, monto)
LEFT JOIN sga.item_facturable i ON i.codigo = x.item
WHERE f.periodo IN ('2026-09', '2026-10')
  AND NOT EXISTS (SELECT 1 FROM sga.factura_detalle d WHERE d.factura_id = f.id AND d.tipo = x.tipo);

COMMIT;

SELECT f.periodo, f.estado, f.monto_total, count(d.id) AS renglones
FROM sga.factura f
JOIN sga.legajo l ON l.id = f.legajo_id AND l.numero_legajo = 'DEMO-001'
LEFT JOIN sga.factura_detalle d ON d.factura_id = f.id
GROUP BY f.id, f.periodo, f.estado, f.monto_total
ORDER BY f.periodo;
