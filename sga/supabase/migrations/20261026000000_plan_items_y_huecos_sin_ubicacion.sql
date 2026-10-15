-- =====================================================================
-- Dos casos del plan I22 del SGA actual:
--   - Bloques "Aprobar N item(s) (suma X créditos)": elegir N materias de
--     una lista (p. ej. "Gestión de datos (obligatoria)": 71.78 o 71.88).
--     requisito APROBAR_ITEMS con plan_bloque.items = N.
--   - Huecos de electivas sin año ni cuatrimestre sugerido: el SGA los
--     lista aparte, bajo "Contenido:", dentro del bloque obligatorio.
-- =====================================================================

ALTER TYPE sga.requisito_bloque ADD VALUE IF NOT EXISTS 'APROBAR_ITEMS';

ALTER TABLE sga.plan_bloque ADD COLUMN items INTEGER;
ALTER TABLE sga.plan_bloque ADD CONSTRAINT ck_plan_bloque_items_positivos
    CHECK (items IS NULL OR items > 0);

ALTER TABLE sga.plan_hueco_electiva ALTER COLUMN anio_sugerido DROP NOT NULL;
ALTER TABLE sga.plan_hueco_electiva ALTER COLUMN cuatrimestre_sugerido DROP NOT NULL;
ALTER TABLE sga.plan_hueco_electiva DROP CONSTRAINT uq_plan_hueco_electiva;
ALTER TABLE sga.plan_hueco_electiva ADD CONSTRAINT uq_plan_hueco_electiva
    UNIQUE NULLS NOT DISTINCT (bloque_id, anio_sugerido, cuatrimestre_sugerido);
