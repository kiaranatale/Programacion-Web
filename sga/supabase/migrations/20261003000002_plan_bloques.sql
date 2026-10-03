-- =====================================================================
-- Estructura real de un plan de estudios (según el SGA actual):
--   - Bloques con requisito: "Básico - Aprobar todos los ítems (suma 192
--     créditos)", "Electivas Gestión - Juntar 18 créditos", etc.
--   - Huecos de electivas dentro de la grilla año/cuatrimestre
--     ("Electivas Orientación - 18 créditos" en Año 1 - Cuatrimestre 2).
--   - Créditos requeridos: mínimo de créditos aprobados para cursar.
--   - Correlativas propias de cada plan (la misma materia puede tener
--     correlativas distintas en otro plan).
--   - Títulos que otorga el plan y su requisito.
--   - Materias de 0 créditos.
-- =====================================================================

-- Hay materias obligatorias de 0 créditos (Inglés I y II en el A22).
ALTER TABLE sga.materia DROP CONSTRAINT ck_materia_creditos_positivos;
ALTER TABLE sga.materia
    ADD CONSTRAINT ck_materia_creditos_no_negativos CHECK (creditos >= 0);

CREATE TYPE sga.requisito_bloque AS ENUM ('APROBAR_TODOS', 'JUNTAR_CREDITOS');

CREATE TABLE sga.plan_bloque (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER NOT NULL
        REFERENCES sga.plan_estudio (id) ON DELETE CASCADE,
    nombre VARCHAR NOT NULL,
    requisito sga.requisito_bloque NOT NULL,
    creditos INTEGER NOT NULL,
    orden SMALLINT NOT NULL DEFAULT 1,

    CONSTRAINT uq_plan_bloque UNIQUE (plan_id, nombre),
    CONSTRAINT ck_plan_bloque_creditos_no_negativos CHECK (creditos >= 0)
);

CREATE INDEX ix_plan_bloque_plan_id ON sga.plan_bloque (plan_id);

-- Bloque al que pertenece cada materia del plan (NULL en planes cargados
-- antes de esta migración) y créditos aprobados necesarios para cursarla.
ALTER TABLE sga.plan_materia
    ADD COLUMN bloque_id INTEGER
        REFERENCES sga.plan_bloque (id) ON DELETE SET NULL,
    ADD COLUMN creditos_requeridos INTEGER NOT NULL DEFAULT 0,
    ADD CONSTRAINT ck_plan_materia_creditos_requeridos
        CHECK (creditos_requeridos >= 0);

CREATE INDEX ix_plan_materia_bloque_id ON sga.plan_materia (bloque_id);

-- Hueco de electivas en la grilla: "cursar N créditos del bloque X en
-- este año/cuatrimestre".
CREATE TABLE sga.plan_hueco_electiva (
    id SERIAL PRIMARY KEY,
    bloque_id INTEGER NOT NULL
        REFERENCES sga.plan_bloque (id) ON DELETE CASCADE,
    anio_sugerido SMALLINT NOT NULL,
    cuatrimestre_sugerido SMALLINT NOT NULL,
    creditos INTEGER NOT NULL,

    CONSTRAINT uq_plan_hueco_electiva
        UNIQUE (bloque_id, anio_sugerido, cuatrimestre_sugerido),
    CONSTRAINT ck_plan_hueco_electiva_creditos_positivos CHECK (creditos > 0)
);

-- Correlativas por plan. plan_id NULL = vale para todos los planes.
ALTER TABLE sga.correlativa
    ADD COLUMN plan_id INTEGER
        REFERENCES sga.plan_estudio (id) ON DELETE CASCADE;

ALTER TABLE sga.correlativa DROP CONSTRAINT uq_correlativa;
ALTER TABLE sga.correlativa
    ADD CONSTRAINT uq_correlativa
    UNIQUE NULLS NOT DISTINCT (plan_id, materia_id, materia_requerida_id, tipo_requisito);

CREATE INDEX ix_correlativa_plan_id ON sga.correlativa (plan_id);

CREATE TABLE sga.plan_titulo (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER NOT NULL
        REFERENCES sga.plan_estudio (id) ON DELETE CASCADE,
    tipo VARCHAR NOT NULL DEFAULT 'Principal',
    nombre VARCHAR NOT NULL,
    requisito VARCHAR,

    CONSTRAINT uq_plan_titulo UNIQUE (plan_id, nombre)
);

-- Catálogos académicos: misma política que el resto (lectura para
-- cualquier usuario autenticado, escritura solo administrativos).
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['plan_bloque', 'plan_hueco_electiva', 'plan_titulo'] LOOP
        EXECUTE format('ALTER TABLE sga.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('ALTER TABLE sga.%I FORCE ROW LEVEL SECURITY', t);
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR SELECT TO authenticated USING (true)',
            t || '_select_autenticados', t);
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin())',
            t || '_admin_all', t);
    END LOOP;
END;
$$;
