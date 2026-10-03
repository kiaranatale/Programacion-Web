-- =====================================================================
-- Datos que muestra el SGA actual en el detalle de una carrera:
--   - "Nombre de la Carrera" además del "Nombre Oficial" (suelen
--     coincidir, pero son campos distintos).
--   - "Versión" de cada plan de estudio.
-- =====================================================================

ALTER TABLE sga.carrera ADD COLUMN nombre VARCHAR;
UPDATE sga.carrera SET nombre = nombre_oficial WHERE nombre IS NULL;
ALTER TABLE sga.carrera ALTER COLUMN nombre SET NOT NULL;

ALTER TABLE sga.plan_estudio
    ADD COLUMN version SMALLINT NOT NULL DEFAULT 1,
    ADD CONSTRAINT ck_plan_estudio_version_positiva CHECK (version > 0);

-- Si no se indica, el nombre de la carrera es su nombre oficial.
CREATE FUNCTION sga.completar_nombre_carrera()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.nombre := COALESCE(NULLIF(btrim(NEW.nombre), ''), NEW.nombre_oficial);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_completar_nombre_carrera
BEFORE INSERT OR UPDATE OF nombre, nombre_oficial
ON sga.carrera
FOR EACH ROW
EXECUTE FUNCTION sga.completar_nombre_carrera();
