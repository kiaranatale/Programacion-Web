-- =====================================================================
-- Huecos dentro de un bloque de electivas (plan M22 del SGA actual):
-- "Materias electivas - Juntar 42 créditos" no lista materias sino los
-- huecos "Área Complementaria" (3) y "Área Tecnológica" (36), que a su
-- vez son bloques con sus materias.
--
-- contenedor_bloque_id indica en qué bloque se muestra el hueco; NULL es
-- el comportamiento anterior (la grilla del bloque obligatorio que cubre
-- ese año y cuatrimestre).
-- =====================================================================

ALTER TABLE sga.plan_hueco_electiva
    ADD COLUMN contenedor_bloque_id INTEGER REFERENCES sga.plan_bloque (id) ON DELETE CASCADE;
