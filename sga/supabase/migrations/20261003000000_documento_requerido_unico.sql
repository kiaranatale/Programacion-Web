-- =====================================================================
-- documento_requerido: carrera_id y nivel en NULL significan "aplica a
-- todas". Con UNIQUE común, dos NULL nunca son iguales y se podía cargar
-- el mismo documento general varias veces. NULLS NOT DISTINCT los trata
-- como iguales (Postgres 15+).
-- =====================================================================

ALTER TABLE sga.documento_requerido
    DROP CONSTRAINT uq_documento_requerido;

ALTER TABLE sga.documento_requerido
    ADD CONSTRAINT uq_documento_requerido
    UNIQUE NULLS NOT DISTINCT (carrera_id, nivel, nombre);
