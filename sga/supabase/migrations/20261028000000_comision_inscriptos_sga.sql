-- =====================================================================
-- Comisiones bajadas del SGA actual (scripts/comisiones_a_csv.js):
-- cuántos inscriptos tenía cada una al momento de bajarla ("48 / 48").
-- El armador de horarios lo usa para avisar que una comisión está llena.
-- Es una foto: las inscripciones hechas en este sistema se cuentan
-- aparte (vista comision_inscriptos).
-- =====================================================================

ALTER TABLE sga.comision
    ADD COLUMN inscriptos_sga INTEGER,
    ADD CONSTRAINT ck_comision_inscriptos_sga CHECK (inscriptos_sga IS NULL OR inscriptos_sga >= 0);

COMMENT ON COLUMN sga.comision.inscriptos_sga IS
    'Inscriptos en el SGA actual cuando se bajaron las comisiones (NULL: sin dato)';
