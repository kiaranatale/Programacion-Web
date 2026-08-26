-- =====================================================================
-- Triggers de reglas de negocio — SGA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Máximo 3 intentos de final por cursada. Si el 3er intento
--    desaprueba, la cursada queda DESAPROBADA (hay que recursar,
--    se crea una inscripcion_curso nueva — no se reutiliza esta fila).
--    Si algún intento aprueba (nota_final >= 4), se calcula
--    nota_definitiva = promedio(nota_cursada, nota_final) y no se
--    permiten más intentos.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.procesar_nota_final()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_nota_cursada NUMERIC(5, 2);
BEGIN
    IF NEW.nota_final IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.nota_final >= 4 THEN
        SELECT nota_cursada
        INTO v_nota_cursada
        FROM sga.inscripcion_curso
        WHERE id = NEW.inscripcion_curso_id;

        UPDATE sga.inscripcion_curso
        SET nota_definitiva = ROUND((v_nota_cursada + NEW.nota_final) / 2, 2),
            estado = 'APROBADA'
        WHERE id = NEW.inscripcion_curso_id;
    ELSIF NEW.numero_intento = 3 THEN
        UPDATE sga.inscripcion_curso
        SET estado = 'DESAPROBADA'
        WHERE id = NEW.inscripcion_curso_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_procesar_nota_final
AFTER INSERT OR UPDATE OF nota_final
ON sga.inscripcion_examen_final
FOR EACH ROW
EXECUTE FUNCTION sga.procesar_nota_final();

CREATE FUNCTION sga.validar_numero_intento_final()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_intento SMALLINT;
    v_estado_actual sga.estado_inscripcion_curso;
BEGIN
    SELECT estado
    INTO v_estado_actual
    FROM sga.inscripcion_curso
    WHERE id = NEW.inscripcion_curso_id;

    IF v_estado_actual = 'DESAPROBADA' THEN
        RAISE EXCEPTION
            'La cursada % ya está desaprobada; no se pueden cargar más intentos de final',
            NEW.inscripcion_curso_id
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM sga.inscripcion_examen_final
        WHERE inscripcion_curso_id = NEW.inscripcion_curso_id
          AND nota_final >= 4
    ) THEN
        RAISE EXCEPTION
            'La cursada % ya tiene un intento de final aprobado; no se permiten más intentos',
            NEW.inscripcion_curso_id
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(MAX(numero_intento), 0)
    INTO v_max_intento
    FROM sga.inscripcion_examen_final
    WHERE inscripcion_curso_id = NEW.inscripcion_curso_id
      AND id IS DISTINCT FROM NEW.id;

    IF NEW.numero_intento <> v_max_intento + 1 THEN
        RAISE EXCEPTION
            'El número de intento debe ser consecutivo (esperado %, recibido %)',
            v_max_intento + 1,
            NEW.numero_intento
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_numero_intento_final
BEFORE INSERT
ON sga.inscripcion_examen_final
FOR EACH ROW
EXECUTE FUNCTION sga.validar_numero_intento_final();

-- ---------------------------------------------------------------------
-- 2) Un docente solo puede cargar nota_cursada de comisiones que dicta
--    (validado contra docente_comision).
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.validar_docente_dicta_comision()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.docente_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sga.docente_comision
        WHERE docente_id = NEW.docente_id
          AND comision_id = NEW.comision_id
    ) THEN
        RAISE EXCEPTION
            'El docente % no dicta la comisión % y no puede cargar su nota',
            NEW.docente_id,
            NEW.comision_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_docente_dicta_comision
BEFORE INSERT OR UPDATE OF docente_id, comision_id
ON sga.inscripcion_curso
FOR EACH ROW
EXECUTE FUNCTION sga.validar_docente_dicta_comision();

-- ---------------------------------------------------------------------
-- 3) La comisión de una inscripcion_curso debe pertenecer al curso
--    de esa misma inscripción.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.validar_comision_pertenece_a_curso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_curso_comision INTEGER;
BEGIN
    SELECT curso_id
    INTO v_curso_comision
    FROM sga.comision
    WHERE id = NEW.comision_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La comisión % no existe', NEW.comision_id
            USING ERRCODE = '23503';
    END IF;

    IF v_curso_comision <> NEW.curso_id THEN
        RAISE EXCEPTION
            'La comisión % no pertenece al curso %',
            NEW.comision_id,
            NEW.curso_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_comision_pertenece_a_curso
BEFORE INSERT OR UPDATE OF curso_id, comision_id
ON sga.inscripcion_curso
FOR EACH ROW
EXECUTE FUNCTION sga.validar_comision_pertenece_a_curso();

-- ---------------------------------------------------------------------
-- 4) El examen_final de una inscripcion_examen_final debe pertenecer
--    al mismo curso que la inscripcion_curso.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.validar_examen_final_pertenece_a_curso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_curso_inscripcion INTEGER;
    v_curso_examen INTEGER;
BEGIN
    SELECT curso_id
    INTO v_curso_inscripcion
    FROM sga.inscripcion_curso
    WHERE id = NEW.inscripcion_curso_id;

    SELECT curso_id
    INTO v_curso_examen
    FROM sga.examen_final
    WHERE id = NEW.examen_final_id;

    IF v_curso_inscripcion IS DISTINCT FROM v_curso_examen THEN
        RAISE EXCEPTION
            'El examen final % no corresponde al curso de la inscripción %',
            NEW.examen_final_id,
            NEW.inscripcion_curso_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_examen_final_pertenece_a_curso
BEFORE INSERT OR UPDATE OF inscripcion_curso_id, examen_final_id
ON sga.inscripcion_examen_final
FOR EACH ROW
EXECUTE FUNCTION sga.validar_examen_final_pertenece_a_curso();

-- ---------------------------------------------------------------------
-- 5) Regla SMA: rendimiento académico < 4 → condicional_especial = TRUE.
--    Se recalcula automáticamente en cada nota_definitiva cargada.
--    Asunción: rendimiento_academico = promedio de todas las
--    nota_definitiva no nulas del legajo.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.recalcular_rendimiento_academico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_legajo_id INTEGER;
    v_rendimiento NUMERIC(5, 2);
BEGIN
    SELECT legajo_id
    INTO v_legajo_id
    FROM sga.inscripcion_curso
    WHERE id = NEW.id;

    SELECT ROUND(AVG(nota_definitiva), 2)
    INTO v_rendimiento
    FROM sga.inscripcion_curso
    WHERE legajo_id = v_legajo_id
      AND nota_definitiva IS NOT NULL;

    UPDATE sga.legajo
    SET rendimiento_academico = v_rendimiento,
        condicional_especial = (v_rendimiento IS NOT NULL AND v_rendimiento < 4)
    WHERE id = v_legajo_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recalcular_rendimiento_academico
AFTER UPDATE OF nota_definitiva
ON sga.inscripcion_curso
FOR EACH ROW
WHEN (NEW.nota_definitiva IS DISTINCT FROM OLD.nota_definitiva)
EXECUTE FUNCTION sga.recalcular_rendimiento_academico();

-- ---------------------------------------------------------------------
-- 6) evaluacion_docente.calificacion se recalcula al cerrarse una
--    encuesta de tipo DESEMPENO_DOCENTE (estado -> FINALIZADA), como
--    promedio de encuesta_respuesta.puntaje.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.recalcular_evaluacion_docente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_promedio NUMERIC(5, 2);
BEGIN
    IF NEW.tipo <> 'DESEMPENO_DOCENTE' OR NEW.docente_comision_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT ROUND(AVG(puntaje), 2)
    INTO v_promedio
    FROM sga.encuesta_respuesta
    WHERE encuesta_id = NEW.id;

    INSERT INTO sga.evaluacion_docente (docente_comision_id, calificacion, fecha_calculo)
    VALUES (NEW.docente_comision_id, v_promedio, now())
    ON CONFLICT (docente_comision_id)
    DO UPDATE SET
        calificacion = EXCLUDED.calificacion,
        fecha_calculo = EXCLUDED.fecha_calculo;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recalcular_evaluacion_docente
AFTER UPDATE OF estado
ON sga.encuesta
FOR EACH ROW
WHEN (NEW.estado = 'FINALIZADA' AND OLD.estado IS DISTINCT FROM 'FINALIZADA')
EXECUTE FUNCTION sga.recalcular_evaluacion_docente();

-- ---------------------------------------------------------------------
-- 7) Un item_facturable nuevo se activa por default para todo alumno
--    con legajo existente al momento de crearlo (activo por default,
--    baja manual explícita después).
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.activar_item_facturable_para_legajos_existentes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO sga.item_facturable_legajo (legajo_id, item_facturable_id)
    SELECT id, NEW.id
    FROM sga.legajo;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_activar_item_facturable_para_legajos_existentes
AFTER INSERT
ON sga.item_facturable
FOR EACH ROW
EXECUTE FUNCTION sga.activar_item_facturable_para_legajos_existentes();

-- ---------------------------------------------------------------------
-- 8) Un nuevo legajo recibe automáticamente todos los item_facturable
--    activos vigentes (misma lógica, en sentido inverso).
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.activar_items_facturables_para_legajo_nuevo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO sga.item_facturable_legajo (legajo_id, item_facturable_id)
    SELECT NEW.id, id
    FROM sga.item_facturable
    WHERE activo = TRUE;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_activar_items_facturables_para_legajo_nuevo
AFTER INSERT
ON sga.legajo
FOR EACH ROW
EXECUTE FUNCTION sga.activar_items_facturables_para_legajo_nuevo();

-- ---------------------------------------------------------------------
-- 9) Una factura no puede estar en dos órdenes de pago PENDIENTE
--    simultáneamente.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.validar_factura_sin_orden_pendiente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_orden sga.estado_orden_pago;
BEGIN
    SELECT estado
    INTO v_estado_orden
    FROM sga.orden_pago
    WHERE id = NEW.orden_pago_id;

    IF v_estado_orden = 'PENDIENTE' AND EXISTS (
        SELECT 1
        FROM sga.orden_pago_factura opf
        JOIN sga.orden_pago op ON op.id = opf.orden_pago_id
        WHERE opf.factura_id = NEW.factura_id
          AND opf.id IS DISTINCT FROM NEW.id
          AND op.estado = 'PENDIENTE'
    ) THEN
        RAISE EXCEPTION
            'La factura % ya tiene una orden de pago pendiente',
            NEW.factura_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_factura_sin_orden_pendiente
BEFORE INSERT
ON sga.orden_pago_factura
FOR EACH ROW
EXECUTE FUNCTION sga.validar_factura_sin_orden_pendiente();

-- ---------------------------------------------------------------------
-- 10) Al confirmarse el pago de una orden (estado -> PAGADO), todas
--     las facturas cubiertas pasan a estado PAGADA.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.propagar_pago_a_facturas()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE sga.factura
    SET estado = 'PAGADA'
    WHERE id IN (
        SELECT factura_id
        FROM sga.orden_pago_factura
        WHERE orden_pago_id = NEW.id
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_propagar_pago_a_facturas
AFTER UPDATE OF estado
ON sga.orden_pago
FOR EACH ROW
WHEN (NEW.estado = 'PAGADO' AND OLD.estado IS DISTINCT FROM 'PAGADO')
EXECUTE FUNCTION sga.propagar_pago_a_facturas();

-- ---------------------------------------------------------------------
-- 11) Máximo de intentos de examen_especial según su catálogo.
-- ---------------------------------------------------------------------

CREATE FUNCTION sga.validar_intentos_examen_especial()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_intentos_maximos SMALLINT;
BEGIN
    SELECT intentos_maximos
    INTO v_intentos_maximos
    FROM sga.examen_especial
    WHERE id = NEW.examen_especial_id;

    IF NEW.numero_intento > v_intentos_maximos THEN
        RAISE EXCEPTION
            'Se superó el máximo de % intentos para este examen especial',
            v_intentos_maximos
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_intentos_examen_especial
BEFORE INSERT
ON sga.examen_especial_intento
FOR EACH ROW
EXECUTE FUNCTION sga.validar_intentos_examen_especial();
