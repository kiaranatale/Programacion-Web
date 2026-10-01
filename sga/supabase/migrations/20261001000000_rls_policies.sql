-- =====================================================================
-- RLS — políticas de seguridad por fila basadas en sga.persona_rol
-- Reemplaza el acceso abierto por defecto de PostgREST en el schema
-- `sga` (ya expuesto en supabase/config.toml) por acceso restringido
-- por rol. Sin estas políticas, cualquier cliente con la clave anon
-- podía leer/escribir todas las tablas del schema.
-- =====================================================================

-- Vínculo entre persona (identidad de negocio) y el usuario de Supabase
-- Auth que inicia sesión. Nullable: personas sin cuenta (ej. cargadas
-- por migración de datos históricos) no pueden autenticarse todavía.
ALTER TABLE sga.persona
    ADD COLUMN auth_user_id UUID UNIQUE REFERENCES auth.users (id) ON DELETE SET NULL;

CREATE INDEX ix_persona_auth_user_id ON sga.persona (auth_user_id);

-- =====================================================================
-- Funciones helper — SECURITY DEFINER para poder leer sga.persona /
-- sga.persona_rol / sga.docente / sga.legajo desde dentro de una
-- política sin volver a pasar por RLS (evita recursión infinita).
-- =====================================================================

CREATE OR REPLACE FUNCTION sga.persona_actual_id()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT id FROM sga.persona WHERE auth_user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION sga.tiene_rol(p_rol sga.tipo_rol_persona)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM sga.persona_rol pr
        WHERE pr.persona_id = sga.persona_actual_id()
          AND pr.rol = p_rol
          AND pr.activo
    );
$$;

CREATE OR REPLACE FUNCTION sga.es_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT sga.tiene_rol('ADMINISTRATIVO');
$$;

CREATE OR REPLACE FUNCTION sga.docente_actual_id()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT id FROM sga.docente WHERE persona_id = sga.persona_actual_id();
$$;

CREATE OR REPLACE FUNCTION sga.legajo_actual_id()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT id FROM sga.legajo WHERE persona_id = sga.persona_actual_id();
$$;

-- Usada para darle a un docente acceso de lectura/escritura sobre las
-- inscripciones de las comisiones que efectivamente dicta.
CREATE OR REPLACE FUNCTION sga.es_docente_de_comision(p_comision_id INTEGER)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = sga, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM sga.docente_comision dc
        WHERE dc.comision_id = p_comision_id
          AND dc.docente_id = sga.docente_actual_id()
    );
$$;

GRANT EXECUTE ON FUNCTION
    sga.persona_actual_id(), sga.tiene_rol(sga.tipo_rol_persona),
    sga.es_admin(), sga.docente_actual_id(),
    sga.es_docente_de_comision(INTEGER)
TO authenticated;

-- =====================================================================
-- Catálogos institucionales / académicos — lectura para cualquier
-- usuario autenticado, escritura exclusiva de administrativos.
-- =====================================================================

DO $$
DECLARE
    t TEXT;
    catalogo_tablas TEXT[] := ARRAY[
        'escuela', 'departamento', 'cargo_institucional', 'autoridad',
        'cronograma_academico', 'carrera', 'plan_estudio', 'materia',
        'plan_materia', 'correlativa', 'aula', 'edificio', 'curso',
        'comision', 'horario_comision', 'evento_academico', 'examen_final',
        'examen_especial', 'encuesta', 'arancel_credito', 'item_facturable',
        'beca_descuento', 'documento_requerido'
    ];
BEGIN
    FOREACH t IN ARRAY catalogo_tablas LOOP
        EXECUTE format('ALTER TABLE sga.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('ALTER TABLE sga.%I FORCE ROW LEVEL SECURITY', t);
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR SELECT TO authenticated USING (true)',
            t || '_select_autenticados', t
        );
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR INSERT TO authenticated WITH CHECK (sga.es_admin())',
            t || '_insert_admin', t
        );
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR UPDATE TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin())',
            t || '_update_admin', t
        );
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR DELETE TO authenticated USING (sga.es_admin())',
            t || '_delete_admin', t
        );
    END LOOP;
END;
$$;

-- =====================================================================
-- Tablas colgadas de legajo_id — lectura exclusiva del propio alumno,
-- administrativos con acceso total. Ninguna permite escritura directa
-- del alumno (altas/bajas pasan por Secretaría o por lógica de backend
-- con service_role, que bypassea RLS).
-- =====================================================================

DO $$
DECLARE
    t TEXT;
    legajo_tablas TEXT[] := ARRAY[
        'titulo_previo', 'dato_familiar', 'hito_academico', 'inhibicion',
        'excepcion', 'documento_legajo', 'item_facturable_legajo',
        'beca_descuento_legajo', 'factura', 'orden_pago',
        'examen_especial_intento'
    ];
BEGIN
    FOREACH t IN ARRAY legajo_tablas LOOP
        EXECUTE format('ALTER TABLE sga.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('ALTER TABLE sga.%I FORCE ROW LEVEL SECURITY', t);
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR SELECT TO authenticated USING (legajo_id = sga.legajo_actual_id())',
            t || '_select_propio', t
        );
        EXECUTE format(
            'CREATE POLICY %I ON sga.%I FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin())',
            t || '_admin_all', t
        );
    END LOOP;
END;
$$;

-- Cuelgan de legajo_id vía una tabla intermedia (factura / orden_pago).
ALTER TABLE sga.factura_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.factura_detalle FORCE ROW LEVEL SECURITY;

CREATE POLICY factura_detalle_select_propia ON sga.factura_detalle
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM sga.factura f
            WHERE f.id = factura_detalle.factura_id
              AND f.legajo_id = sga.legajo_actual_id()
        )
    );

CREATE POLICY factura_detalle_admin_all ON sga.factura_detalle
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.orden_pago_factura ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.orden_pago_factura FORCE ROW LEVEL SECURITY;

CREATE POLICY orden_pago_factura_select_propia ON sga.orden_pago_factura
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM sga.orden_pago op
            WHERE op.id = orden_pago_factura.orden_pago_id
              AND op.legajo_id = sga.legajo_actual_id()
        )
    );

CREATE POLICY orden_pago_factura_admin_all ON sga.orden_pago_factura
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- Payloads crudos de Mercado Pago: solo administrativos (el backend que
-- procesa el webhook usa la service_role key, que bypassea RLS).
ALTER TABLE sga.evento_webhook_mp ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.evento_webhook_mp FORCE ROW LEVEL SECURITY;

CREATE POLICY evento_webhook_mp_admin_all ON sga.evento_webhook_mp
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- =====================================================================
-- Identidad y roles
-- =====================================================================

ALTER TABLE sga.persona ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.persona FORCE ROW LEVEL SECURITY;

-- Un docente puede ver los datos básicos de los alumnos inscriptos en
-- alguna de sus comisiones (para listados de curso, carga de notas, etc).
CREATE POLICY persona_select ON sga.persona
    FOR SELECT TO authenticated
    USING (
        auth_user_id = auth.uid()
        OR sga.es_admin()
        OR EXISTS (
            SELECT 1
            FROM sga.legajo l
            JOIN sga.inscripcion_curso ic ON ic.legajo_id = l.id
            WHERE l.persona_id = persona.id
              AND sga.es_docente_de_comision(ic.comision_id)
        )
    );

CREATE POLICY persona_insert_admin ON sga.persona
    FOR INSERT TO authenticated WITH CHECK (sga.es_admin());

CREATE POLICY persona_update_propia_o_admin ON sga.persona
    FOR UPDATE TO authenticated
    USING (auth_user_id = auth.uid() OR sga.es_admin())
    WITH CHECK (auth_user_id = auth.uid() OR sga.es_admin());

CREATE POLICY persona_delete_admin ON sga.persona
    FOR DELETE TO authenticated USING (sga.es_admin());

ALTER TABLE sga.persona_rol ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.persona_rol FORCE ROW LEVEL SECURITY;

CREATE POLICY persona_rol_select_propio ON sga.persona_rol
    FOR SELECT TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY persona_rol_admin_all ON sga.persona_rol
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- =====================================================================
-- Legajo
-- =====================================================================

ALTER TABLE sga.legajo ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.legajo FORCE ROW LEVEL SECURITY;

CREATE POLICY legajo_select_propio_o_docente ON sga.legajo
    FOR SELECT TO authenticated
    USING (
        persona_id = sga.persona_actual_id()
        OR EXISTS (
            SELECT 1
            FROM sga.inscripcion_curso ic
            WHERE ic.legajo_id = legajo.id
              AND sga.es_docente_de_comision(ic.comision_id)
        )
    );

CREATE POLICY legajo_admin_all ON sga.legajo
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- =====================================================================
-- Cursada / calificaciones — lectura propia o del docente a cargo;
-- escritura de notas limitada al docente de la comisión (regla de
-- negocio de triggers_sga.sql valida además que dicte esa comisión).
-- =====================================================================

ALTER TABLE sga.inscripcion_curso ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.inscripcion_curso FORCE ROW LEVEL SECURITY;

CREATE POLICY inscripcion_curso_select ON sga.inscripcion_curso
    FOR SELECT TO authenticated
    USING (
        legajo_id = sga.legajo_actual_id()
        OR sga.es_docente_de_comision(comision_id)
    );

CREATE POLICY inscripcion_curso_update_docente ON sga.inscripcion_curso
    FOR UPDATE TO authenticated
    USING (sga.es_docente_de_comision(comision_id))
    WITH CHECK (sga.es_docente_de_comision(comision_id));

-- Alta/baja de inscripciones (autogestión del alumno) queda pendiente
-- de diseño del flujo de inscripción — por ahora solo administrativos.
CREATE POLICY inscripcion_curso_admin_all ON sga.inscripcion_curso
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.inscripcion_examen_final ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.inscripcion_examen_final FORCE ROW LEVEL SECURITY;

CREATE POLICY inscripcion_examen_final_select ON sga.inscripcion_examen_final
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM sga.inscripcion_curso ic
            WHERE ic.id = inscripcion_examen_final.inscripcion_curso_id
              AND (
                  ic.legajo_id = sga.legajo_actual_id()
                  OR sga.es_docente_de_comision(ic.comision_id)
              )
        )
    );

CREATE POLICY inscripcion_examen_final_update_docente ON sga.inscripcion_examen_final
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM sga.inscripcion_curso ic
            WHERE ic.id = inscripcion_examen_final.inscripcion_curso_id
              AND sga.es_docente_de_comision(ic.comision_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM sga.inscripcion_curso ic
            WHERE ic.id = inscripcion_examen_final.inscripcion_curso_id
              AND sga.es_docente_de_comision(ic.comision_id)
        )
    );

CREATE POLICY inscripcion_examen_final_admin_all ON sga.inscripcion_examen_final
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- =====================================================================
-- Docentes
-- =====================================================================

ALTER TABLE sga.docente ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.docente FORCE ROW LEVEL SECURITY;

CREATE POLICY docente_select_propio ON sga.docente
    FOR SELECT TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY docente_admin_write ON sga.docente
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.docente_comision ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.docente_comision FORCE ROW LEVEL SECURITY;

CREATE POLICY docente_comision_select ON sga.docente_comision
    FOR SELECT TO authenticated
    USING (docente_id = sga.docente_actual_id() OR sga.es_admin());

CREATE POLICY docente_comision_admin_write ON sga.docente_comision
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.ausencia_docente ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.ausencia_docente FORCE ROW LEVEL SECURITY;

CREATE POLICY ausencia_docente_select ON sga.ausencia_docente
    FOR SELECT TO authenticated
    USING (docente_id = sga.docente_actual_id() OR sga.es_admin());

CREATE POLICY ausencia_docente_insert_propia ON sga.ausencia_docente
    FOR INSERT TO authenticated
    WITH CHECK (docente_id = sga.docente_actual_id() OR sga.es_admin());

CREATE POLICY ausencia_docente_admin_write ON sga.ausencia_docente
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.evaluacion_docente ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.evaluacion_docente FORCE ROW LEVEL SECURITY;

CREATE POLICY evaluacion_docente_select ON sga.evaluacion_docente
    FOR SELECT TO authenticated
    USING (
        sga.es_admin()
        OR EXISTS (
            SELECT 1 FROM sga.docente_comision dc
            WHERE dc.id = evaluacion_docente.docente_comision_id
              AND dc.docente_id = sga.docente_actual_id()
        )
    );

CREATE POLICY evaluacion_docente_admin_write ON sga.evaluacion_docente
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

-- =====================================================================
-- Notificaciones, mensajería y encuestas
-- =====================================================================

ALTER TABLE sga.notificacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.notificacion FORCE ROW LEVEL SECURITY;

CREATE POLICY notificacion_select_propia ON sga.notificacion
    FOR SELECT TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY notificacion_update_propia ON sga.notificacion
    FOR UPDATE TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_admin())
    WITH CHECK (persona_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY notificacion_admin_insert_delete ON sga.notificacion
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());

ALTER TABLE sga.mensaje ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.mensaje FORCE ROW LEVEL SECURITY;

CREATE POLICY mensaje_select_propio ON sga.mensaje
    FOR SELECT TO authenticated
    USING (
        persona_emisor_id = sga.persona_actual_id()
        OR persona_receptor_id = sga.persona_actual_id()
        OR sga.es_admin()
    );

CREATE POLICY mensaje_insert_propio ON sga.mensaje
    FOR INSERT TO authenticated
    WITH CHECK (persona_emisor_id = sga.persona_actual_id());

CREATE POLICY mensaje_update_receptor ON sga.mensaje
    FOR UPDATE TO authenticated
    USING (persona_receptor_id = sga.persona_actual_id() OR sga.es_admin())
    WITH CHECK (persona_receptor_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY mensaje_admin_delete ON sga.mensaje
    FOR DELETE TO authenticated USING (sga.es_admin());

ALTER TABLE sga.encuesta_respuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE sga.encuesta_respuesta FORCE ROW LEVEL SECURITY;

CREATE POLICY encuesta_respuesta_select_propia ON sga.encuesta_respuesta
    FOR SELECT TO authenticated
    USING (persona_id = sga.persona_actual_id() OR sga.es_admin());

CREATE POLICY encuesta_respuesta_insert_propia ON sga.encuesta_respuesta
    FOR INSERT TO authenticated
    WITH CHECK (persona_id = sga.persona_actual_id());

CREATE POLICY encuesta_respuesta_admin_write ON sga.encuesta_respuesta
    FOR ALL TO authenticated USING (sga.es_admin()) WITH CHECK (sga.es_admin());
