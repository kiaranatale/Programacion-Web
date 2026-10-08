-- =====================================================================
-- Plan AER 25 de Ingeniería Aeroespacial, como figura en el SGA actual:
-- activo desde el segundo cuatrimestre de 2025, todavía sin materias,
-- solo con su título. Correr DESPUÉS de seed.sql.
--
-- Se puede correr más de una vez.
-- =====================================================================

BEGIN;

INSERT INTO sga.plan_estudio (carrera_id, codigo, version, creditos_totales, vigencia_desde)
SELECT id, 'AER 25', 1, 0, DATE '2025-08-01'
FROM sga.carrera WHERE codigo = 'AER'
ON CONFLICT (carrera_id, codigo) DO NOTHING;

INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)
SELECT p.id, 'Principal', 'Ingeniero/a Aeroespacial', 'Aprobar AER 25 (sumar 0 créditos)'
FROM sga.plan_estudio p
JOIN sga.carrera c ON c.id = p.carrera_id
WHERE c.codigo = 'AER' AND p.codigo = 'AER 25'
ON CONFLICT (plan_id, nombre) DO NOTHING;

COMMIT;
