-- Prueba del circuito de documentación (20261004000002_documentacion_carga):
-- el alumno sube, Administración rechaza/aprueba, y nadie más puede
-- cambiar el estado. Requiere Supabase (schema auth y roles).
--
-- Corre dentro de una transacción con ROLLBACK final: no modifica la base.

BEGIN;

INSERT INTO sga.escuela (nombre) VALUES ('Escuela de Prueba Doc');
INSERT INTO sga.carrera (codigo, nombre_oficial, escuela_id)
SELECT 'DOC', 'Carrera de Prueba Doc', id FROM sga.escuela WHERE nombre = 'Escuela de Prueba Doc';
INSERT INTO sga.plan_estudio (carrera_id, codigo, creditos_totales, vigencia_desde)
SELECT id, 'PLN-DOC', 10, DATE '2020-01-01' FROM sga.carrera WHERE codigo = 'DOC';
INSERT INTO sga.documento_requerido (nombre) VALUES ('Documento de Prueba Doc');

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('77777777-7777-7777-7777-777777777771', 'alumno.doc@test.local', now()),
    ('77777777-7777-7777-7777-777777777772', 'admin.doc@test.local', now());
INSERT INTO sga.persona (tipo_documento, nro_documento, nombre, apellido, mail_institucional) VALUES
    ('DNI', '92000001', 'Alumno', 'Doc', 'alumno.doc@test.local'),
    ('DNI', '92000002', 'Admin', 'Doc', 'admin.doc@test.local');
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ALUMNO' FROM sga.persona WHERE nro_documento = '92000001';
INSERT INTO sga.persona_rol (persona_id, rol)
SELECT id, 'ADMINISTRATIVO' FROM sga.persona WHERE nro_documento = '92000002';
INSERT INTO sga.legajo (persona_id, numero_legajo, plan_estudio_id)
SELECT p.id, 'DOC-001', pl.id FROM sga.persona p, sga.plan_estudio pl
WHERE p.nro_documento = '92000001' AND pl.codigo = 'PLN-DOC';

CREATE TEMP TABLE doc_ids AS
SELECT
    (SELECT id FROM sga.legajo WHERE numero_legajo = 'DOC-001') AS legajo,
    (SELECT id FROM sga.documento_requerido WHERE nombre = 'Documento de Prueba Doc') AS documento;
GRANT SELECT ON doc_ids TO authenticated;

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

-- ---------- Alumno: sube el documento ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "77777777-7777-7777-7777-777777777771"}';

SELECT sga.cargar_documento(documento, 'dni.pdf', legajo || '/' || documento || '/dni.pdf') FROM doc_ids;

-- No puede registrar un archivo en la carpeta de otro legajo
SELECT pg_temp.espera_error(
    format('SELECT sga.cargar_documento(%s, %L, %L)', documento, 'x.pdf', (legajo + 999) || '/' || documento || '/x.pdf'),
    'no corresponde a tu legajo')
FROM doc_ids;

-- No puede validarse el documento él mismo (RLS: no tiene UPDATE)
UPDATE sga.documento_legajo SET estado = 'VALIDADO' WHERE nombre_archivo = 'dni.pdf';

-- Ni revisar documentos
SELECT pg_temp.espera_error(
    format('SELECT sga.revisar_documento(%s, true)', (SELECT id FROM sga.documento_legajo WHERE nombre_archivo = 'dni.pdf')),
    'Solo Administración');

DO $$
BEGIN
    IF (SELECT estado FROM sga.documento_legajo WHERE nombre_archivo = 'dni.pdf') <> 'CARGADO' THEN
        RAISE EXCEPTION 'Doc: el alumno no debería poder cambiar el estado de su documento';
    END IF;
END;
$$;

RESET ROLE;
RESET request.jwt.claims;

-- ---------- Administración: rechaza (con motivo) ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "77777777-7777-7777-7777-777777777772"}';

SELECT pg_temp.espera_error(
    format('SELECT sga.revisar_documento(%s, false, %L)', (SELECT id FROM sga.documento_legajo WHERE nombre_archivo = 'dni.pdf'), ''),
    'motivo del rechazo');
SELECT sga.revisar_documento((SELECT id FROM sga.documento_legajo WHERE nombre_archivo = 'dni.pdf'), false, 'Ilegible');

RESET ROLE;
RESET request.jwt.claims;

DO $$
BEGIN
    IF (SELECT estado FROM sga.documento_legajo WHERE nombre_archivo = 'dni.pdf') <> 'RECHAZADO' THEN
        RAISE EXCEPTION 'Doc: el documento debería quedar RECHAZADO';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM sga.notificacion n JOIN sga.persona p ON p.id = n.persona_id
        WHERE p.nro_documento = '92000001' AND n.mensaje LIKE '%rechazado: Ilegible%'
    ) THEN
        RAISE EXCEPTION 'Doc: el alumno debería recibir una notificación del rechazo';
    END IF;
END;
$$;

-- ---------- Alumno: vuelve a subir; Administración aprueba ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "77777777-7777-7777-7777-777777777771"}';

DO $$
DECLARE v_anterior TEXT;
BEGIN
    SELECT sga.cargar_documento(documento, 'dni2.pdf', legajo || '/' || documento || '/dni2.pdf') INTO v_anterior FROM doc_ids;
    IF v_anterior NOT LIKE '%/dni.pdf' THEN
        RAISE EXCEPTION 'Doc: al reemplazar debería devolver la ruta del archivo anterior (devolvió %)', v_anterior;
    END IF;
END;
$$;

RESET ROLE;
RESET request.jwt.claims;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "77777777-7777-7777-7777-777777777772"}';

SELECT sga.revisar_documento((SELECT id FROM sga.documento_legajo WHERE nombre_archivo = 'dni2.pdf'), true);

RESET ROLE;
RESET request.jwt.claims;

-- ---------- Alumno: ya no puede eliminar ni reemplazar ----------
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "77777777-7777-7777-7777-777777777771"}';

SELECT pg_temp.espera_error(format('SELECT sga.eliminar_documento(%s)', documento), 'ya fue validado') FROM doc_ids;
SELECT pg_temp.espera_error(
    format('SELECT sga.cargar_documento(%s, %L, %L)', documento, 'x.pdf', legajo || '/' || documento || '/x.pdf'),
    'ya fue validado')
FROM doc_ids;

RESET ROLE;
RESET request.jwt.claims;

DO $$
BEGIN
    IF (SELECT estado FROM sga.documento_legajo WHERE nombre_archivo = 'dni2.pdf') <> 'VALIDADO' THEN
        RAISE EXCEPTION 'Doc: el documento debería quedar VALIDADO';
    END IF;
END;
$$;

ROLLBACK;

SELECT 'sga documentacion test passed' AS result;
