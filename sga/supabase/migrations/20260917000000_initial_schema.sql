-- =====================================================================
-- SGA (Sistema de Gestión Académica) — ITBA
-- Rediseño completo, independiente de SecAdmision.
-- Persona es la entidad raíz: un mismo individuo puede ser alumno,
-- docente, ayudante y/o administrativo simultáneamente.
-- =====================================================================

CREATE SCHEMA sga;

-- =====================================================================
-- ENUMS
-- =====================================================================

CREATE TYPE sga.tipo_documento AS ENUM (
    'DNI', 'PASAPORTE', 'LIBRETA_CIVICA', 'LIBRETA_DE_ENROLAMIENTO',
    'CEDULA_DE_IDENTIDAD', 'CUIL', 'CUIT', 'CDI', 'OTRO'
);

CREATE TYPE sga.genero AS ENUM ('HOMBRE', 'MUJER', 'OTRO');

CREATE TYPE sga.tipo_rol_persona AS ENUM (
    'ALUMNO', 'DOCENTE', 'AYUDANTE', 'ADMINISTRATIVO'
);

CREATE TYPE sga.nivel_academico AS ENUM ('GRADO', 'POSGRADO');

CREATE TYPE sga.tipo_inhibicion AS ENUM (
    'ARANCEL', 'ENCUESTA', 'DOCUMENTACION', 'OTRO'
);

CREATE TYPE sga.estado_documento AS ENUM (
    'NO_CARGADO', 'CARGADO', 'VALIDADO', 'RECHAZADO'
);

CREATE TYPE sga.tipo_beca_descuento AS ENUM ('BECA', 'DESCUENTO');

CREATE TYPE sga.estado_factura AS ENUM (
    'PENDIENTE', 'PAGADA', 'VENCIDA', 'ANULADA'
);

CREATE TYPE sga.estado_orden_pago AS ENUM (
    'PENDIENTE', 'PAGADO', 'EXPIRADO', 'CANCELADO'
);

CREATE TYPE sga.tipo_requisito_correlativa AS ENUM (
    'PARA_CURSAR', 'PARA_RENDIR'
);

CREATE TYPE sga.estado_requerido_correlativa AS ENUM ('REGULAR', 'APROBADA');

CREATE TYPE sga.estado_inscripcion_curso AS ENUM (
    'CURSANDO', 'CURSADA_APROBADA', 'APROBADA', 'DESAPROBADA', 'ABANDONADA'
);

CREATE TYPE sga.dia_semana AS ENUM (
    'LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO'
);

CREATE TYPE sga.modalidad_horario AS ENUM (
    'PRESENCIAL', 'VIRTUAL_SINCRONICO', 'VIRTUAL_ASINCRONICO'
);

CREATE TYPE sga.tipo_encuesta AS ENUM ('ALUMNOS', 'DESEMPENO_DOCENTE');

CREATE TYPE sga.estado_encuesta AS ENUM (
    'PROGRAMADA', 'ACTIVA', 'FINALIZADA'
);

-- =====================================================================
-- IDENTIDAD — persona y roles
-- =====================================================================

CREATE TABLE sga.persona (
    id SERIAL PRIMARY KEY,
    tipo_documento sga.tipo_documento NOT NULL,
    nro_documento VARCHAR(32) NOT NULL,
    nombre VARCHAR NOT NULL,
    apellido VARCHAR NOT NULL,
    fecha_nacimiento DATE,
    lugar_nacimiento VARCHAR,
    genero sga.genero,
    nacionalidad VARCHAR,
    cuil VARCHAR,
    titulo_antes_nombre VARCHAR,
    titulo_despues_nombre VARCHAR,
    mail_institucional VARCHAR NOT NULL,
    mail_particular VARCHAR,
    codigo_credencial VARCHAR,

    CONSTRAINT uq_persona_documento
        UNIQUE (tipo_documento, nro_documento),
    CONSTRAINT uq_persona_mail_institucional
        UNIQUE (mail_institucional),
    CONSTRAINT ck_persona_documento_normalizado
        CHECK (nro_documento = btrim(nro_documento) AND nro_documento <> '')
);

CREATE TABLE sga.persona_rol (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    rol sga.tipo_rol_persona NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_persona_rol
        UNIQUE (persona_id, rol)
);

CREATE INDEX ix_persona_rol_persona_id ON sga.persona_rol (persona_id);

-- =====================================================================
-- INSTITUCIONAL — escuelas, departamentos, autoridades
-- =====================================================================

CREATE TABLE sga.escuela (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_escuela_nombre UNIQUE (nombre)
);

CREATE TABLE sga.departamento (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_departamento_nombre UNIQUE (nombre)
    -- Nota: se asume que un departamento es transversal y no pertenece
    -- a una única escuela (ej. Ciencias Básicas dicta para varias
    -- escuelas). Asunción documentada, no confirmada con Secretaría.
);

CREATE TABLE sga.cargo_institucional (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,

    CONSTRAINT uq_cargo_institucional_nombre UNIQUE (nombre)
);

CREATE TABLE sga.autoridad (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    cargo_institucional_id INTEGER NOT NULL
        REFERENCES sga.cargo_institucional (id) ON DELETE RESTRICT,
    escuela_id INTEGER
        REFERENCES sga.escuela (id) ON DELETE RESTRICT,
    fecha_desde DATE NOT NULL,
    fecha_hasta DATE,

    CONSTRAINT ck_autoridad_rango_fechas
        CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);

CREATE INDEX ix_autoridad_persona_id ON sga.autoridad (persona_id);
CREATE INDEX ix_autoridad_escuela_id ON sga.autoridad (escuela_id);

CREATE TABLE sga.cronograma_academico (
    id SERIAL PRIMARY KEY,
    anio INTEGER NOT NULL,
    nombre VARCHAR NOT NULL,
    url_archivo VARCHAR NOT NULL,

    CONSTRAINT uq_cronograma_academico_anio_nombre
        UNIQUE (anio, nombre)
);

CREATE TABLE sga.notificacion (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    tipo VARCHAR NOT NULL,
    mensaje TEXT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT now(),
    leida BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_notificacion_persona_id ON sga.notificacion (persona_id);

CREATE TABLE sga.mensaje (
    id SERIAL PRIMARY KEY,
    persona_emisor_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    persona_receptor_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    asunto VARCHAR,
    cuerpo TEXT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT now(),
    leido BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_mensaje_persona_emisor_id ON sga.mensaje (persona_emisor_id);
CREATE INDEX ix_mensaje_persona_receptor_id ON sga.mensaje (persona_receptor_id);

-- =====================================================================
-- PLAN DE ESTUDIOS
-- =====================================================================

CREATE TABLE sga.carrera (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR NOT NULL,
    nombre_oficial VARCHAR NOT NULL,
    escuela_id INTEGER NOT NULL
        REFERENCES sga.escuela (id) ON DELETE RESTRICT,
    nivel sga.nivel_academico NOT NULL DEFAULT 'GRADO',
    nivel_informatico VARCHAR,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_carrera_codigo UNIQUE (codigo),
    CONSTRAINT uq_carrera_nombre_oficial UNIQUE (nombre_oficial),
    CONSTRAINT ck_carrera_codigo_no_vacio
        CHECK (codigo = btrim(codigo) AND codigo <> '')
);

CREATE INDEX ix_carrera_escuela_id ON sga.carrera (escuela_id);

CREATE TABLE sga.plan_estudio (
    id SERIAL PRIMARY KEY,
    carrera_id INTEGER NOT NULL
        REFERENCES sga.carrera (id) ON DELETE RESTRICT,
    codigo VARCHAR NOT NULL,
    creditos_totales INTEGER NOT NULL,
    vigencia_desde DATE NOT NULL,
    vigencia_hasta DATE,

    CONSTRAINT uq_plan_estudio_carrera_codigo
        UNIQUE (carrera_id, codigo),
    CONSTRAINT ck_plan_estudio_creditos_positivos
        CHECK (creditos_totales > 0),
    CONSTRAINT ck_plan_estudio_rango_fechas
        CHECK (vigencia_hasta IS NULL OR vigencia_hasta >= vigencia_desde)
);

CREATE INDEX ix_plan_estudio_carrera_id ON sga.plan_estudio (carrera_id);

CREATE TABLE sga.materia (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR NOT NULL,
    nombre VARCHAR NOT NULL,
    departamento_id INTEGER NOT NULL
        REFERENCES sga.departamento (id) ON DELETE RESTRICT,
    creditos INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_materia_codigo UNIQUE (codigo),
    CONSTRAINT ck_materia_creditos_positivos CHECK (creditos > 0)
);

CREATE INDEX ix_materia_departamento_id ON sga.materia (departamento_id);

CREATE TABLE sga.plan_materia (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER NOT NULL
        REFERENCES sga.plan_estudio (id) ON DELETE RESTRICT,
    materia_id INTEGER NOT NULL
        REFERENCES sga.materia (id) ON DELETE RESTRICT,
    anio_sugerido SMALLINT,
    cuatrimestre_sugerido SMALLINT,

    CONSTRAINT uq_plan_materia UNIQUE (plan_id, materia_id)
);

CREATE INDEX ix_plan_materia_materia_id ON sga.plan_materia (materia_id);

CREATE TABLE sga.correlativa (
    id SERIAL PRIMARY KEY,
    materia_id INTEGER NOT NULL
        REFERENCES sga.materia (id) ON DELETE RESTRICT,
    materia_requerida_id INTEGER NOT NULL
        REFERENCES sga.materia (id) ON DELETE RESTRICT,
    tipo_requisito sga.tipo_requisito_correlativa NOT NULL,
    estado_requerido sga.estado_requerido_correlativa NOT NULL,

    CONSTRAINT uq_correlativa
        UNIQUE (materia_id, materia_requerida_id, tipo_requisito),
    CONSTRAINT ck_correlativa_no_autorreferencia
        CHECK (materia_id <> materia_requerida_id)
);

CREATE INDEX ix_correlativa_materia_id ON sga.correlativa (materia_id);
CREATE INDEX ix_correlativa_materia_requerida_id
    ON sga.correlativa (materia_requerida_id);

-- =====================================================================
-- LEGAJO — el alumno y todo lo que cuelga de su identidad académica
-- =====================================================================

CREATE TABLE sga.legajo (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    numero_legajo VARCHAR NOT NULL,
    plan_estudio_id INTEGER NOT NULL
        REFERENCES sga.plan_estudio (id) ON DELETE RESTRICT,
    fecha_registracion DATE NOT NULL DEFAULT CURRENT_DATE,
    rendimiento_academico NUMERIC(5, 2),
    condicional_especial BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_legajo_persona UNIQUE (persona_id),
    CONSTRAINT uq_legajo_numero UNIQUE (numero_legajo)
    -- El plan queda fijo desde el ingreso (no migra). rendimiento_academico
    -- y condicional_especial (regla SMA) son campos derivados, recalculados
    -- por trigger en cada carga de nota_final — ver triggers_sga.sql.
);

CREATE INDEX ix_legajo_plan_estudio_id ON sga.legajo (plan_estudio_id);

CREATE TABLE sga.titulo_previo (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    fecha DATE,
    titulo VARCHAR NOT NULL,
    institucion VARCHAR,
    pais VARCHAR,
    nivel VARCHAR,
    descripcion TEXT
);

CREATE INDEX ix_titulo_previo_legajo_id ON sga.titulo_previo (legajo_id);

CREATE TABLE sga.dato_familiar (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    nombre VARCHAR NOT NULL,
    parentesco VARCHAR,
    vive BOOLEAN,
    graduado_itba BOOLEAN NOT NULL DEFAULT FALSE,
    email VARCHAR,
    profesion VARCHAR
);

CREATE INDEX ix_dato_familiar_legajo_id ON sga.dato_familiar (legajo_id);

CREATE TABLE sga.hito_academico (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    tipo VARCHAR NOT NULL,
    descripcion TEXT,
    fecha_evento DATE NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX ix_hito_academico_legajo_id ON sga.hito_academico (legajo_id);

CREATE TABLE sga.inhibicion (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    tipo sga.tipo_inhibicion NOT NULL,
    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,
    observaciones TEXT,

    CONSTRAINT ck_inhibicion_rango_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
    -- Bloquea inscripción/rendición de finales, no bloquea cursada.
);

CREATE INDEX ix_inhibicion_legajo_id ON sga.inhibicion (legajo_id);

CREATE TABLE sga.excepcion (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    tipo VARCHAR NOT NULL,
    descripcion TEXT NOT NULL,
    autorizante_persona_id INTEGER
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE
    -- Registro genérico: correlatividad, cupo, plazo, etc.
);

CREATE INDEX ix_excepcion_legajo_id ON sga.excepcion (legajo_id);

CREATE TABLE sga.documento_requerido (
    id SERIAL PRIMARY KEY,
    carrera_id INTEGER
        REFERENCES sga.carrera (id) ON DELETE RESTRICT,
    nivel sga.nivel_academico,
    nombre VARCHAR NOT NULL,
    categoria VARCHAR NOT NULL DEFAULT 'Académica',
    obligatoria BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_documento_requerido
        UNIQUE (carrera_id, nivel, nombre)
    -- carrera_id y nivel nullable: NULL = aplica a todas las carreras/niveles.
);

CREATE TABLE sga.documento_legajo (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    documento_requerido_id INTEGER NOT NULL
        REFERENCES sga.documento_requerido (id) ON DELETE RESTRICT,
    nombre_archivo VARCHAR,
    estado sga.estado_documento NOT NULL DEFAULT 'NO_CARGADO',
    fecha_carga TIMESTAMP,

    CONSTRAINT uq_documento_legajo
        UNIQUE (legajo_id, documento_requerido_id)
);

CREATE INDEX ix_documento_legajo_legajo_id ON sga.documento_legajo (legajo_id);

-- =====================================================================
-- FACTURACIÓN
-- =====================================================================

CREATE TABLE sga.arancel_credito (
    id SERIAL PRIMARY KEY,
    carrera_id INTEGER NOT NULL
        REFERENCES sga.carrera (id) ON DELETE RESTRICT,
    valor_credito NUMERIC(12, 2) NOT NULL,
    vigencia_desde DATE NOT NULL,
    vigencia_hasta DATE,

    CONSTRAINT uq_arancel_credito UNIQUE (carrera_id, vigencia_desde),
    CONSTRAINT ck_arancel_credito_valor_positivo
        CHECK (valor_credito > 0),
    CONSTRAINT ck_arancel_credito_rango_fechas
        CHECK (vigencia_hasta IS NULL OR vigencia_hasta >= vigencia_desde)
);

CREATE INDEX ix_arancel_credito_carrera_id ON sga.arancel_credito (carrera_id);

CREATE TABLE sga.item_facturable (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR NOT NULL,
    nombre VARCHAR NOT NULL,
    monto NUMERIC(12, 2) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_item_facturable_codigo UNIQUE (codigo)
);

CREATE TABLE sga.item_facturable_legajo (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    item_facturable_id INTEGER NOT NULL
        REFERENCES sga.item_facturable (id) ON DELETE RESTRICT,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_hasta DATE,
    motivo_baja TEXT,

    CONSTRAINT uq_item_facturable_legajo
        UNIQUE (legajo_id, item_facturable_id)
    -- Activo por default; se da de baja manualmente (vía mail a
    -- Secretaría) seteando activo=FALSE y fecha_hasta.
);

CREATE INDEX ix_item_facturable_legajo_legajo_id
    ON sga.item_facturable_legajo (legajo_id);

CREATE TABLE sga.beca_descuento (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    tipo sga.tipo_beca_descuento NOT NULL,

    CONSTRAINT uq_beca_descuento_nombre UNIQUE (nombre)
);

CREATE TABLE sga.beca_descuento_legajo (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    beca_descuento_id INTEGER NOT NULL
        REFERENCES sga.beca_descuento (id) ON DELETE RESTRICT,
    monto NUMERIC(12, 2) NOT NULL,
    fecha_desde DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_hasta DATE,
    autorizante_persona_id INTEGER
        REFERENCES sga.persona (id) ON DELETE RESTRICT,

    CONSTRAINT ck_beca_descuento_legajo_monto_positivo
        CHECK (monto > 0),
    CONSTRAINT ck_beca_descuento_legajo_rango_fechas
        CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);

CREATE INDEX ix_beca_descuento_legajo_legajo_id
    ON sga.beca_descuento_legajo (legajo_id);

CREATE TABLE sga.factura (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    periodo CHAR(7) NOT NULL,
    creditos_cursados INTEGER NOT NULL DEFAULT 0,
    valor_credito_aplicado NUMERIC(12, 2) NOT NULL,
    monto_creditos NUMERIC(12, 2) NOT NULL,
    monto_adicionales NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_descuentos NUMERIC(12, 2) NOT NULL DEFAULT 0,
    monto_total NUMERIC(12, 2) NOT NULL,
    fecha_emision DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_vencimiento DATE NOT NULL,
    estado sga.estado_factura NOT NULL DEFAULT 'PENDIENTE',

    CONSTRAINT uq_factura_legajo_periodo UNIQUE (legajo_id, periodo),
    CONSTRAINT ck_factura_periodo_formato
        CHECK (periodo ~ '^\d{4}-(0[1-9]|1[0-2])$')
);

CREATE INDEX ix_factura_legajo_id ON sga.factura (legajo_id);

CREATE TABLE sga.factura_detalle (
    id SERIAL PRIMARY KEY,
    factura_id INTEGER NOT NULL
        REFERENCES sga.factura (id) ON DELETE RESTRICT,
    tipo VARCHAR NOT NULL,
    referencia_item_facturable_id INTEGER
        REFERENCES sga.item_facturable (id) ON DELETE RESTRICT,
    referencia_beca_descuento_id INTEGER
        REFERENCES sga.beca_descuento (id) ON DELETE RESTRICT,
    descripcion VARCHAR,
    monto NUMERIC(12, 2) NOT NULL
);

CREATE INDEX ix_factura_detalle_factura_id ON sga.factura_detalle (factura_id);

CREATE TABLE sga.orden_pago (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    monto_total NUMERIC(12, 2) NOT NULL,
    estado sga.estado_orden_pago NOT NULL DEFAULT 'PENDIENTE',
    external_preference_id VARCHAR,
    external_payment_id VARCHAR,
    qr_data TEXT,
    qr_image_url VARCHAR,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT now(),
    fecha_expiracion TIMESTAMP,
    fecha_pago TIMESTAMP
);

CREATE INDEX ix_orden_pago_legajo_id ON sga.orden_pago (legajo_id);

CREATE TABLE sga.orden_pago_factura (
    id SERIAL PRIMARY KEY,
    orden_pago_id INTEGER NOT NULL
        REFERENCES sga.orden_pago (id) ON DELETE RESTRICT,
    factura_id INTEGER NOT NULL
        REFERENCES sga.factura (id) ON DELETE RESTRICT,

    CONSTRAINT uq_orden_pago_factura UNIQUE (orden_pago_id, factura_id)
);

CREATE INDEX ix_orden_pago_factura_factura_id
    ON sga.orden_pago_factura (factura_id);

CREATE TABLE sga.evento_webhook_mp (
    id SERIAL PRIMARY KEY,
    orden_pago_id INTEGER
        REFERENCES sga.orden_pago (id) ON DELETE RESTRICT,
    payload JSONB NOT NULL,
    fecha_recepcion TIMESTAMP NOT NULL DEFAULT now(),
    procesado BOOLEAN NOT NULL DEFAULT FALSE
);

-- =====================================================================
-- AULAS / INFRAESTRUCTURA
-- =====================================================================

CREATE TABLE sga.edificio (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR NOT NULL,
    nombre VARCHAR NOT NULL,
    direccion VARCHAR,

    CONSTRAINT uq_edificio_codigo UNIQUE (codigo)
);

CREATE TABLE sga.aula (
    id SERIAL PRIMARY KEY,
    edificio_id INTEGER NOT NULL
        REFERENCES sga.edificio (id) ON DELETE RESTRICT,
    codigo VARCHAR NOT NULL,
    capacidad INTEGER NOT NULL,

    CONSTRAINT uq_aula_edificio_codigo UNIQUE (edificio_id, codigo),
    CONSTRAINT ck_aula_capacidad_positiva CHECK (capacidad > 0)
);

CREATE INDEX ix_aula_edificio_id ON sga.aula (edificio_id);

-- =====================================================================
-- CURSADA
-- =====================================================================

CREATE TABLE sga.curso (
    id SERIAL PRIMARY KEY,
    materia_id INTEGER NOT NULL
        REFERENCES sga.materia (id) ON DELETE RESTRICT,
    anio INTEGER NOT NULL,
    periodo VARCHAR NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    coordinado BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_curso_materia_periodo
        UNIQUE (materia_id, anio, periodo),
    CONSTRAINT ck_curso_rango_fechas
        CHECK (fecha_fin > fecha_inicio)
);

CREATE INDEX ix_curso_materia_id ON sga.curso (materia_id);

CREATE TABLE sga.comision (
    id SERIAL PRIMARY KEY,
    curso_id INTEGER NOT NULL
        REFERENCES sga.curso (id) ON DELETE RESTRICT,
    nombre VARCHAR NOT NULL,
    cupo INTEGER,

    CONSTRAINT uq_comision_curso_nombre UNIQUE (curso_id, nombre),
    CONSTRAINT ck_comision_cupo_positivo
        CHECK (cupo IS NULL OR cupo > 0)
    -- A diferencia de core.comision (admisión), acá el cupo no está
    -- fijo en 24: depende del aula asignada en horario_comision.
);

CREATE INDEX ix_comision_curso_id ON sga.comision (curso_id);

CREATE TABLE sga.horario_comision (
    id SERIAL PRIMARY KEY,
    comision_id INTEGER NOT NULL
        REFERENCES sga.comision (id) ON DELETE RESTRICT,
    dia_semana sga.dia_semana NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    aula_id INTEGER
        REFERENCES sga.aula (id) ON DELETE RESTRICT,
    modalidad sga.modalidad_horario NOT NULL DEFAULT 'PRESENCIAL',

    CONSTRAINT ck_horario_comision_rango_horario
        CHECK (hora_fin > hora_inicio)
    -- aula_id nullable: virtual asincrónico no ocupa aula física.
);

CREATE INDEX ix_horario_comision_comision_id
    ON sga.horario_comision (comision_id);
CREATE INDEX ix_horario_comision_aula_id ON sga.horario_comision (aula_id);

CREATE TABLE sga.evento_academico (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR NOT NULL,
    tipo VARCHAR,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    aula_id INTEGER
        REFERENCES sga.aula (id) ON DELETE RESTRICT,

    CONSTRAINT ck_evento_academico_rango_horario
        CHECK (hora_fin > hora_inicio)
);

CREATE INDEX ix_evento_academico_aula_id ON sga.evento_academico (aula_id);

CREATE TABLE sga.examen_final (
    id SERIAL PRIMARY KEY,
    curso_id INTEGER NOT NULL
        REFERENCES sga.curso (id) ON DELETE RESTRICT,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    aula_id INTEGER
        REFERENCES sga.aula (id) ON DELETE RESTRICT,

    CONSTRAINT ck_examen_final_rango_horario
        CHECK (hora_fin > hora_inicio)
);

CREATE INDEX ix_examen_final_curso_id ON sga.examen_final (curso_id);
CREATE INDEX ix_examen_final_aula_id ON sga.examen_final (aula_id);

-- =====================================================================
-- DOCENTES
-- =====================================================================

CREATE TABLE sga.docente (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    fecha_ingreso_sad DATE,
    tipo_contratacion VARCHAR,
    designacion VARCHAR,
    horas_semanales INTEGER,

    CONSTRAINT uq_docente_persona UNIQUE (persona_id),
    CONSTRAINT ck_docente_horas_no_negativas
        CHECK (horas_semanales IS NULL OR horas_semanales >= 0)
);

CREATE TABLE sga.docente_comision (
    id SERIAL PRIMARY KEY,
    docente_id INTEGER NOT NULL
        REFERENCES sga.docente (id) ON DELETE RESTRICT,
    comision_id INTEGER NOT NULL
        REFERENCES sga.comision (id) ON DELETE RESTRICT,

    CONSTRAINT uq_docente_comision UNIQUE (docente_id, comision_id)
);

CREATE INDEX ix_docente_comision_comision_id
    ON sga.docente_comision (comision_id);

CREATE TABLE sga.ausencia_docente (
    id SERIAL PRIMARY KEY,
    docente_id INTEGER NOT NULL
        REFERENCES sga.docente (id) ON DELETE RESTRICT,
    tipo_ausencia VARCHAR,
    fecha_inicio DATE,
    fecha_fin DATE,
    motivo TEXT,
    estado VARCHAR,
    observaciones TEXT,

    CONSTRAINT ck_ausencia_docente_rango_fechas
        CHECK (
            fecha_inicio IS NULL
            OR fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        )
);

CREATE INDEX ix_ausencia_docente_docente_id ON sga.ausencia_docente (docente_id);

CREATE TABLE sga.evaluacion_docente (
    id SERIAL PRIMARY KEY,
    docente_comision_id INTEGER NOT NULL
        REFERENCES sga.docente_comision (id) ON DELETE RESTRICT,
    calificacion NUMERIC(5, 2),
    fecha_calculo TIMESTAMP,

    CONSTRAINT uq_evaluacion_docente_docente_comision
        UNIQUE (docente_comision_id)
    -- calificacion es un valor derivado, recalculado por trigger al
    -- cerrarse la encuesta de desempeño asociada — ver triggers_sga.sql.
);

-- =====================================================================
-- ENCUESTAS
-- =====================================================================

CREATE TABLE sga.encuesta (
    id SERIAL PRIMARY KEY,
    tipo sga.tipo_encuesta NOT NULL,
    nombre VARCHAR NOT NULL,
    docente_comision_id INTEGER
        REFERENCES sga.docente_comision (id) ON DELETE RESTRICT,
    estado sga.estado_encuesta NOT NULL DEFAULT 'PROGRAMADA',
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,

    CONSTRAINT ck_encuesta_rango_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT ck_encuesta_docente_comision_solo_desempeno
        CHECK (
            (tipo = 'DESEMPENO_DOCENTE' AND docente_comision_id IS NOT NULL)
            OR (tipo = 'ALUMNOS' AND docente_comision_id IS NULL)
        )
);

CREATE INDEX ix_encuesta_docente_comision_id
    ON sga.encuesta (docente_comision_id);

CREATE TABLE sga.encuesta_respuesta (
    id SERIAL PRIMARY KEY,
    encuesta_id INTEGER NOT NULL
        REFERENCES sga.encuesta (id) ON DELETE RESTRICT,
    persona_id INTEGER NOT NULL
        REFERENCES sga.persona (id) ON DELETE RESTRICT,
    puntaje NUMERIC(5, 2),
    respuestas JSONB,
    fecha_respuesta TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT uq_encuesta_respuesta UNIQUE (encuesta_id, persona_id)
);

CREATE INDEX ix_encuesta_respuesta_encuesta_id
    ON sga.encuesta_respuesta (encuesta_id);

-- =====================================================================
-- EXÁMENES ESPECIALES (idiomas, práctica laboral, etc.)
-- Equivalentes a una materia dentro del plan, con intentos limitados.
-- =====================================================================

CREATE TABLE sga.examen_especial (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR NOT NULL,
    nombre VARCHAR NOT NULL,
    intentos_maximos SMALLINT NOT NULL DEFAULT 3,
    vigencia_meses INTEGER,

    CONSTRAINT uq_examen_especial_codigo UNIQUE (codigo),
    CONSTRAINT ck_examen_especial_intentos_positivos
        CHECK (intentos_maximos > 0)
);

CREATE TABLE sga.examen_especial_intento (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    examen_especial_id INTEGER NOT NULL
        REFERENCES sga.examen_especial (id) ON DELETE RESTRICT,
    numero_intento SMALLINT NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    nota NUMERIC(5, 2),
    aprobado BOOLEAN,
    fecha_vencimiento DATE,

    CONSTRAINT uq_examen_especial_intento
        UNIQUE (legajo_id, examen_especial_id, numero_intento)
);

CREATE INDEX ix_examen_especial_intento_legajo_id
    ON sga.examen_especial_intento (legajo_id);

-- =====================================================================
-- INSCRIPCIÓN A CURSADA Y CALIFICACIONES
-- Modelo simplificado: el docente carga UNA nota de cursada consolidada
-- (no instancias parciales sueltas) y una nota por cada intento de final
-- (hasta 3), que se promedian 50/50 cuando el final aprueba.
-- =====================================================================

CREATE TABLE sga.inscripcion_curso (
    id SERIAL PRIMARY KEY,
    legajo_id INTEGER NOT NULL
        REFERENCES sga.legajo (id) ON DELETE RESTRICT,
    curso_id INTEGER NOT NULL
        REFERENCES sga.curso (id) ON DELETE RESTRICT,
    comision_id INTEGER NOT NULL
        REFERENCES sga.comision (id) ON DELETE RESTRICT,
    estado sga.estado_inscripcion_curso NOT NULL DEFAULT 'CURSANDO',
    nota_cursada NUMERIC(5, 2),
    fecha_carga_cursada TIMESTAMP,
    docente_id INTEGER
        REFERENCES sga.docente (id) ON DELETE RESTRICT,
    nota_definitiva NUMERIC(5, 2),

    CONSTRAINT uq_inscripcion_curso UNIQUE (legajo_id, curso_id)
);

CREATE INDEX ix_inscripcion_curso_legajo_id
    ON sga.inscripcion_curso (legajo_id);
CREATE INDEX ix_inscripcion_curso_comision_id
    ON sga.inscripcion_curso (comision_id);

CREATE TABLE sga.inscripcion_examen_final (
    id SERIAL PRIMARY KEY,
    inscripcion_curso_id INTEGER NOT NULL
        REFERENCES sga.inscripcion_curso (id) ON DELETE RESTRICT,
    examen_final_id INTEGER NOT NULL
        REFERENCES sga.examen_final (id) ON DELETE RESTRICT,
    numero_intento SMALLINT NOT NULL,
    nota_final NUMERIC(5, 2),
    fecha_carga_final TIMESTAMP,
    docente_id INTEGER
        REFERENCES sga.docente (id) ON DELETE RESTRICT,

    CONSTRAINT uq_inscripcion_examen_final
        UNIQUE (inscripcion_curso_id, numero_intento),
    CONSTRAINT ck_inscripcion_examen_final_numero_intento
        CHECK (numero_intento BETWEEN 1 AND 3)
);

CREATE INDEX ix_inscripcion_examen_final_inscripcion_curso_id
    ON sga.inscripcion_examen_final (inscripcion_curso_id);
