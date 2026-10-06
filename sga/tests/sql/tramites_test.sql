-- Prueba de Trámites (20261017000000_tramites): envío, cancelación,
-- comentarios, gestión de Administración (asignación) y visibilidad. Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Tra');
INSERT INTO sga.departamento (nombre) VALUES ('Departamento de Prueba Tra');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'TRA', 'Carrera de Prueba Tra', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Tra';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-TRA', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'TRA';
INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)
SELECT 'TRA.01', 'Materia TRA.01', id, 6 FROM sga.departamento WHERE nombre = 'Departamento de Prueba Tra';

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('efefefef-0000-0000-0000-000000000001', 'a1.tra@test.local', now()),
    ('efefefef-0000-0000-0000-000000000002', 'a2.tra@test.local', now()),
    ('efefefef-0000-0000-0000-000000000009', 'admin.tra@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '99400001', 'Alumno1', 'Tra', 'a1.tra@test.local'),
    ('DNI', '99400002', 'Alumno2', 'Tra', 'a2.tra@test.local'),
    ('DNI', '99400009', 'Admin', 'Tra', 'admin.tra@test.local');
INSERT INTO sga.persona_rol (persona_id, rol) SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '99400009';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'TRA-' || right(p.nro_documento, 1), pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento IN ('99400001', '99400002') AND pl.codigo = 'PLN-TRA';
CREATE FUNCTION pg_temp.espera_error(p_sql TEXT, p_texto TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%' || p_texto || '%' THEN
            RAISE EXCEPTION 'Error inesperado: % (se esperaba "%")', SQLERRM, p_texto;
        END IF;
        RETURN;
    END;
    RAISE EXCEPTION 'Se esperaba un error "%" y no lo hubo: %', p_texto, p_sql;
END;
$$;
CREATE TEMP TABLE tra (clave TEXT PRIMARY KEY, id INTEGER);
GRANT SELECT, INSERT ON tra TO authenticated;
CREATE FUNCTION pg_temp.t(c TEXT) RETURNS INTEGER LANGUAGE sql AS $$ SELECT id FROM tra WHERE clave = c $$;
GRANT EXECUTE ON FUNCTION pg_temp.t(TEXT) TO authenticated;

SET LOCAL ROLE authenticated;

-- Alumno 1: envía trámites, cancela uno y comenta otro
SET LOCAL request.jwt.claims TO '{"sub": "efefefef-0000-0000-0000-000000000001"}';
INSERT INTO tra SELECT 'equiv', sga.iniciar_tramite('Equivalencia de Análisis I', 'ACADEMICA', 'Aprobada en la UBA');
INSERT INTO tra SELECT 'pago', sga.iniciar_tramite('Consulta por factura de agosto', 'ADMINISTRATIVA', 'Figura impaga');
INSERT INTO tra SELECT 'otro', sga.iniciar_tramite('Pedido de prueba', 'ACADEMICA', 'Texto');
SELECT pg_temp.espera_error($$SELECT sga.iniciar_tramite('  ', 'ACADEMICA', 'x')$$, 'título');
SELECT pg_temp.espera_error($$SELECT sga.iniciar_tramite('x', 'OTRA', 'x')$$, 'destino');
SELECT pg_temp.espera_error($$SELECT sga.iniciar_tramite('x', 'ACADEMICA', ' ')$$, 'descripción');
SELECT pg_temp.espera_error(format('SELECT sga.iniciar_tramite(%L, %L, %L)', 'x', 'ACADEMICA', repeat('a', 8001)), '8000');
SELECT sga.cancelar_tramite(pg_temp.t('otro'));
SELECT pg_temp.espera_error($$SELECT sga.cancelar_tramite(pg_temp.t('otro'))$$, 'nadie tomó');
SELECT pg_temp.espera_error($$SELECT sga.comentar_tramite(pg_temp.t('otro'), 'hola')$$, 'cerrado');
SELECT pg_temp.espera_error($$SELECT sga.cambiar_estado_tramite(pg_temp.t('equiv'), 'RESUELTO', NULL)$$, 'Solo Administración');
SELECT sga.comentar_tramite(pg_temp.t('equiv'), 'Adjunto el programa por mail');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.tramite_listado) <> 3 THEN
        RAISE EXCEPTION 'Trámites: el alumno 1 debería ver sus 3 trámites';
    END IF;
    IF (SELECT enviado_por FROM sga.tramite_listado WHERE id = pg_temp.t('equiv')) <> 'Tra, Alumno1' THEN
        RAISE EXCEPTION 'Trámites: el listado debería mostrar quién lo envió';
    END IF;
    IF (SELECT count(*) FROM sga.tramite_movimiento_listado WHERE tramite_id = pg_temp.t('equiv')) <> 2 THEN
        RAISE EXCEPTION 'Trámites: el historial debería tener el envío y el comentario';
    END IF;
END;
$$;

-- Alumno 2: no ve ni toca trámites ajenos
SET LOCAL request.jwt.claims TO '{"sub": "efefefef-0000-0000-0000-000000000002"}';
SELECT pg_temp.espera_error($$SELECT sga.cancelar_tramite(pg_temp.t('equiv'))$$, 'No tenés ese trámite');
SELECT pg_temp.espera_error($$SELECT sga.comentar_tramite(pg_temp.t('equiv'), 'x')$$, 'No tenés ese trámite');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.tramite) + (SELECT count(*) FROM sga.tramite_listado) + (SELECT count(*) FROM sga.tramite_movimiento_listado) <> 0 THEN
        RAISE EXCEPTION 'Trámites: el alumno 2 no debería ver trámites ajenos';
    END IF;
END;
$$;

-- Administración: toma (queda asignado), comenta, rechaza con motivo y resuelve
SET LOCAL request.jwt.claims TO '{"sub": "efefefef-0000-0000-0000-000000000009"}';
SELECT sga.cambiar_estado_tramite(pg_temp.t('equiv'), 'EN_CURSO', NULL);
SELECT sga.comentar_tramite(pg_temp.t('equiv'), 'Recibimos el programa');
SELECT pg_temp.espera_error($$SELECT sga.cambiar_estado_tramite(pg_temp.t('equiv'), 'RECHAZADO', '')$$, 'motivo');
SELECT pg_temp.espera_error($$SELECT sga.cambiar_estado_tramite(pg_temp.t('equiv'), 'EN_CURSO', NULL)$$, 'No se puede pasar');
SELECT pg_temp.espera_error($$SELECT sga.cambiar_estado_tramite(pg_temp.t('otro'), 'RESUELTO', NULL)$$, 'No se puede pasar');
SELECT sga.cambiar_estado_tramite(pg_temp.t('equiv'), 'RECHAZADO', 'Los contenidos no alcanzan');
SELECT sga.cambiar_estado_tramite(pg_temp.t('pago'), 'RESUELTO', 'Ya figura pagada');
DO $$
BEGIN
    IF (SELECT count(*) FROM sga.tramite_listado WHERE numero_legajo = 'TRA-1') <> 3 THEN
        RAISE EXCEPTION 'Trámites: Administración debería ver los trámites del alumno';
    END IF;
    IF (SELECT count(*) FROM sga.tramite_listado WHERE numero_legajo = 'TRA-1' AND asignado_a = 'Tra, Admin') <> 2 THEN
        RAISE EXCEPTION 'Trámites: los trámites gestionados quedan asignados a quien los tomó';
    END IF;
    IF (SELECT count(*) FROM sga.notificacion n JOIN sga.persona p ON p.id = n.persona_id
        WHERE p.nro_documento = '99400001' AND n.tipo = 'TRAMITE') <> 4 THEN
        RAISE EXCEPTION 'Trámites: el alumno 1 debería tener 4 notificaciones (tomado, comentario, rechazo, resuelto)';
    END IF;
END;
$$;

ROLLBACK;
