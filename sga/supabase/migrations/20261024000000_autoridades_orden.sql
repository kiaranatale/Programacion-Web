-- =====================================================================
-- Autoridades como en el SGA real: una lista en orden jerárquico
-- (Rector, Secretario Académico y después cada escuela con su director
-- y director adjunto), no alfabético.
--
--   - cargo_institucional.orden y escuela.orden definen ese orden (los
--     cargos o escuelas nuevos quedan al final hasta que se les asigne).
--   - autoridad_listado suma escuela_id, cargo_orden y escuela_orden.
-- =====================================================================

ALTER TABLE sga.cargo_institucional ADD COLUMN orden INTEGER NOT NULL DEFAULT 100;
ALTER TABLE sga.escuela ADD COLUMN orden INTEGER NOT NULL DEFAULT 100;

CREATE OR REPLACE VIEW sga.autoridad_listado AS
SELECT
    a.id,
    c.nombre AS cargo,
    p.apellido,
    p.nombre,
    p.mail_institucional,
    e.nombre AS escuela,
    a.fecha_desde,
    a.fecha_hasta,
    (a.fecha_hasta IS NULL OR a.fecha_hasta >= sga.hoy()) AS vigente,
    a.escuela_id,
    c.orden AS cargo_orden,
    e.orden AS escuela_orden
FROM sga.autoridad a
JOIN sga.cargo_institucional c ON c.id = a.cargo_institucional_id
JOIN sga.persona p ON p.id = a.persona_id
LEFT JOIN sga.escuela e ON e.id = a.escuela_id;
