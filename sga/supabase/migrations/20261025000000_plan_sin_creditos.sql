-- =====================================================================
-- Planes recién creados sin materias cargadas (como AER 25 en el SGA
-- actual, "Aprobar AER 25 (sumar 0 créditos)"): se permite un plan con
-- 0 créditos totales.
-- =====================================================================

ALTER TABLE sga.plan_estudio DROP CONSTRAINT ck_plan_estudio_creditos_positivos;
ALTER TABLE sga.plan_estudio ADD CONSTRAINT ck_plan_estudio_creditos_no_negativos
    CHECK (creditos_totales >= 0);
