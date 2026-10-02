-- =====================================================================
-- Auth ↔ persona
-- Vincula automáticamente cada usuario de Supabase Auth con su
-- sga.persona usando el mail institucional. Funciona en los dos órdenes:
--   - se crea el usuario de Auth y la persona ya existía;
--   - se carga la persona y el usuario de Auth ya existía.
-- Solo vincula mails confirmados, para que nadie pueda tomar la persona
-- de otro registrándose con su mail sin poder recibirlo.
-- =====================================================================

CREATE FUNCTION sga.vincular_auth_con_persona()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.email IS NULL OR NEW.email_confirmed_at IS NULL THEN
        RETURN NEW;
    END IF;

    UPDATE sga.persona
    SET auth_user_id = NEW.id
    WHERE lower(mail_institucional) = lower(NEW.email)
      AND auth_user_id IS NULL;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vincular_auth_con_persona
AFTER INSERT OR UPDATE OF email, email_confirmed_at
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION sga.vincular_auth_con_persona();

CREATE FUNCTION sga.vincular_persona_con_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.auth_user_id IS NULL THEN
        SELECT u.id
        INTO NEW.auth_user_id
        FROM auth.users u
        WHERE lower(u.email) = lower(NEW.mail_institucional)
          AND u.email_confirmed_at IS NOT NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vincular_persona_con_auth
BEFORE INSERT OR UPDATE OF mail_institucional
ON sga.persona
FOR EACH ROW
EXECUTE FUNCTION sga.vincular_persona_con_auth();

-- Personas y usuarios que ya existían antes de esta migración
UPDATE sga.persona p
SET auth_user_id = u.id
FROM auth.users u
WHERE p.auth_user_id IS NULL
  AND u.email_confirmed_at IS NOT NULL
  AND lower(u.email) = lower(p.mail_institucional);

-- =====================================================================
-- Triggers de notas bajo RLS
-- Las funciones de negocio corrían con los permisos de quien dispara el
-- trigger. Un docente puede actualizar notas de sus comisiones, pero no
-- legajos: al cargar una nota final, el UPDATE de
-- legajo.rendimiento_academico afectaba 0 filas sin dar error. Como
-- SECURITY DEFINER corren con los permisos del dueño del schema; la fila
-- que las dispara ya pasó por RLS (el docente solo puede tocar notas de
-- comisiones que dicta).
-- =====================================================================

ALTER FUNCTION sga.procesar_nota_final()
    SECURITY DEFINER SET search_path = sga, pg_temp;

ALTER FUNCTION sga.recalcular_rendimiento_academico()
    SECURITY DEFINER SET search_path = sga, pg_temp;
