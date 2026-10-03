-- =====================================================================
-- Carga de documentación por el alumno y revisión por Administración.
--
--   NO_CARGADO ──(alumno sube)──▶ CARGADO ("Pendiente de validación")
--   CARGADO ──(administración)──▶ VALIDADO | RECHAZADO (con motivo)
--   RECHAZADO ──(alumno vuelve a subir)──▶ CARGADO
--
-- Los archivos van al bucket privado "documentacion" de Supabase Storage,
-- en <legajo_id>/<documento_requerido_id>/<archivo>. El alumno no escribe
-- documento_legajo directamente (podría marcarse VALIDADO): usa las
-- funciones de abajo, que solo permiten las transiciones de arriba.
-- =====================================================================

ALTER TABLE sga.documento_legajo
    ADD COLUMN ruta_archivo VARCHAR,
    ADD COLUMN observaciones TEXT,
    ADD COLUMN fecha_revision TIMESTAMP;

-- ---------------------------------------------------------------------
-- Bucket y políticas de Storage
-- ---------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documentacion', 'documentacion', FALSE, 5242880,
        ARRAY['application/pdf', 'image/png', 'image/jpeg'])
ON CONFLICT (id) DO NOTHING;

-- El primer nivel de la ruta es el legajo: cada alumno solo ve, sube y
-- borra en su carpeta; administración ve y borra todo.
CREATE POLICY documentacion_select ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'documentacion'
        AND ((storage.foldername(name))[1] = sga.legajo_actual_id()::TEXT OR sga.es_admin())
    );

CREATE POLICY documentacion_insert ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'documentacion'
        AND (storage.foldername(name))[1] = sga.legajo_actual_id()::TEXT
    );

CREATE POLICY documentacion_delete ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'documentacion'
        AND ((storage.foldername(name))[1] = sga.legajo_actual_id()::TEXT OR sga.es_admin())
    );

-- ---------------------------------------------------------------------
-- Funciones (SECURITY DEFINER: validan quién llama y qué transición pide)
-- ---------------------------------------------------------------------

-- El alumno registra un archivo ya subido a su carpeta. Devuelve la ruta
-- del archivo anterior (si lo reemplaza) para que la app lo borre.
CREATE FUNCTION sga.cargar_documento(
    p_documento_requerido_id INTEGER,
    p_nombre_archivo TEXT,
    p_ruta_archivo TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo_id INTEGER := sga.legajo_actual_id();
    v_actual sga.documento_legajo%ROWTYPE;
BEGIN
    IF v_legajo_id IS NULL THEN
        RAISE EXCEPTION 'Tu usuario no tiene un legajo de alumno' USING ERRCODE = '42501';
    END IF;
    IF p_ruta_archivo NOT LIKE v_legajo_id::TEXT || '/' || p_documento_requerido_id::TEXT || '/%' THEN
        RAISE EXCEPTION 'La ruta del archivo no corresponde a tu legajo' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sga.documento_requerido WHERE id = p_documento_requerido_id) THEN
        RAISE EXCEPTION 'El documento % no existe', p_documento_requerido_id USING ERRCODE = '23503';
    END IF;

    SELECT * INTO v_actual
    FROM sga.documento_legajo
    WHERE legajo_id = v_legajo_id AND documento_requerido_id = p_documento_requerido_id;

    IF v_actual.estado = 'VALIDADO' THEN
        RAISE EXCEPTION 'El documento ya fue validado y no se puede reemplazar' USING ERRCODE = '23514';
    END IF;

    INSERT INTO sga.documento_legajo
        (legajo_id, documento_requerido_id, nombre_archivo, ruta_archivo, estado, fecha_carga, observaciones, fecha_revision)
    VALUES
        (v_legajo_id, p_documento_requerido_id, p_nombre_archivo, p_ruta_archivo, 'CARGADO', now(), NULL, NULL)
    ON CONFLICT (legajo_id, documento_requerido_id) DO UPDATE
    SET nombre_archivo = EXCLUDED.nombre_archivo,
        ruta_archivo = EXCLUDED.ruta_archivo,
        estado = 'CARGADO',
        fecha_carga = now(),
        observaciones = NULL,
        fecha_revision = NULL;

    RETURN NULLIF(v_actual.ruta_archivo, p_ruta_archivo);
END;
$$;

-- El alumno elimina un documento todavía no validado. Devuelve la ruta
-- del archivo para que la app lo borre de Storage.
CREATE FUNCTION sga.eliminar_documento(p_documento_requerido_id INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_legajo_id INTEGER := sga.legajo_actual_id();
    v_actual sga.documento_legajo%ROWTYPE;
BEGIN
    SELECT * INTO v_actual
    FROM sga.documento_legajo
    WHERE legajo_id = v_legajo_id AND documento_requerido_id = p_documento_requerido_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No hay un documento cargado para eliminar' USING ERRCODE = 'P0002';
    END IF;
    IF v_actual.estado = 'VALIDADO' THEN
        RAISE EXCEPTION 'El documento ya fue validado y no se puede eliminar' USING ERRCODE = '23514';
    END IF;

    DELETE FROM sga.documento_legajo WHERE id = v_actual.id;
    RETURN v_actual.ruta_archivo;
END;
$$;

-- Administración aprueba o rechaza un documento pendiente. Al alumno le
-- llega una notificación (se ve en Inicio).
CREATE FUNCTION sga.revisar_documento(
    p_documento_legajo_id INTEGER,
    p_aprobado BOOLEAN,
    p_observaciones TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_doc sga.documento_legajo%ROWTYPE;
    v_nombre TEXT;
    v_persona_id INTEGER;
BEGIN
    IF NOT sga.es_admin() THEN
        RAISE EXCEPTION 'Solo Administración puede revisar documentación' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_doc FROM sga.documento_legajo WHERE id = p_documento_legajo_id;
    IF NOT FOUND OR v_doc.estado <> 'CARGADO' THEN
        RAISE EXCEPTION 'El documento no está pendiente de validación' USING ERRCODE = '23514';
    END IF;
    IF NOT p_aprobado AND NULLIF(btrim(p_observaciones), '') IS NULL THEN
        RAISE EXCEPTION 'Indicá el motivo del rechazo' USING ERRCODE = '23514';
    END IF;

    UPDATE sga.documento_legajo
    SET estado = CASE WHEN p_aprobado THEN 'VALIDADO'::sga.estado_documento ELSE 'RECHAZADO'::sga.estado_documento END,
        observaciones = NULLIF(btrim(p_observaciones), ''),
        fecha_revision = now()
    WHERE id = v_doc.id;

    SELECT dr.nombre, l.persona_id INTO v_nombre, v_persona_id
    FROM sga.documento_requerido dr, sga.legajo l
    WHERE dr.id = v_doc.documento_requerido_id AND l.id = v_doc.legajo_id;

    INSERT INTO sga.notificacion (persona_id, tipo, mensaje)
    VALUES (
        v_persona_id,
        'DOCUMENTACION',
        CASE WHEN p_aprobado
            THEN format('Tu documento "%s" fue validado', v_nombre)
            ELSE format('Tu documento "%s" fue rechazado: %s', v_nombre, btrim(p_observaciones))
        END
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION
    sga.cargar_documento(INTEGER, TEXT, TEXT),
    sga.eliminar_documento(INTEGER),
    sga.revisar_documento(INTEGER, BOOLEAN, TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    sga.cargar_documento(INTEGER, TEXT, TEXT),
    sga.eliminar_documento(INTEGER),
    sga.revisar_documento(INTEGER, BOOLEAN, TEXT)
TO authenticated;
