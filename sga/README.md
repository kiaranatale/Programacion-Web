# SGA — Sistema de Gestión Académica (ITBA)

Rediseño completo, desde cero, del sistema de gestión académica de la facultad.
Proyecto independiente de **SecAdmision** (el pipeline de datos de admisión
anterior) — no reemplaza ni depende de él, aunque reutiliza varios patrones
de diseño validados ahí (triggers para reglas de negocio, catálogos
protegidos, campos derivados en vez de carga manual).

## Estado actual

Disponible:

- Modelo de datos completo (schema `sga`) cubriendo los 6 dominios
  relevados: Identidad/Persona, Alumno-Legajo, Facturación, Plan de
  estudios/Cursada, Aulas/Infraestructura, Docentes, e Institucional.
- Triggers con las reglas de negocio principales (ver detalle abajo).
- Suite de smoke tests que valida el modelo contra un Postgres real.

Todavía no está implementado:

- Backend/API.
- Frontend.
- Vistas de solo-lectura (ocupación de aulas con alertas, agenda del día).
- Integración real con Mercado Pago (el modelo de datos para QR/órdenes de
  pago está listo, falta la lógica de aplicación).
- Migración del schema a Supabase (Auth + RLS por rol) — reemplaza el plan
  anterior de Postgres local con `docker-compose`/Alembic. Ver Roadmap.

## Roadmap (temario de la materia)

Este proyecto es el trabajo práctico integrador de Programación Web. La
mitad "Primer Parcial (programar)" del temario mapea directo a entregables
del SGA:

| Tema del temario | Entregable en el SGA |
|---|---|
| Bases de datos y Supabase: SQL, tablas, relaciones, CRUD, Auth, RLS | Migrar `ddl_sga.sql`/`triggers_sga.sql` a Supabase + políticas RLS por rol (`persona_rol`) |
| Autenticación y autorización: login, registro, roles, middleware, sesiones | Supabase Auth, roles alumno/docente/admin sobre `persona_rol` |
| Next.js completo: App Router, layouts, routing, Server Components, data fetching | App en `sga/app/` (inscripciones, notas, aulas, facturación) |
| React completo: JSX, componentes, props, estado, hooks, formularios, consumo de APIs | Componentes de UI para los flujos de alumno/docente/admin |
| APIs y Backend: Route Handlers, endpoints REST, validaciones, manejo de errores | Route Handlers en `sga/app/api/` sobre las entidades del modelo |
| Mercado Pago: checkout, preferencias, estados de pago | Flujo de pago de aranceles sobre `orden_pago`/`evento_webhook_mp` (ya modelados) |
| Testing y calidad: testing manual, Playwright | Suite E2E con Playwright sobre los flujos principales |
| DevOps: deploy en Vercel, variables de entorno, CI/CD con GitHub Actions | Pipeline en GitHub Actions + deploy automático en Vercel |
| Presentación Proyecto Final | Demo end-to-end del SGA |

Los temas previos al parcial (Internet/Web, JS/HTML/CSS, proyecto
integrador e-commerce) son fundamentos de la cursada, no entregables de
este proyecto — quedan documentados en `docs/apuntes/` en la raíz del
repositorio.

Orden sugerido de implementación: 1) migrar schema a Supabase con RLS,
2) Auth y roles, 3) scaffold Next.js + primeros Route Handlers (CRUD sobre
inscripciones/notas), 4) integración Mercado Pago, 5) Playwright, 6) CI/CD
y deploy en Vercel.

## Estructura del repositorio

```text
sga/
├── src/
│   └── sql/
│       ├── ddl_sga.sql       # Schema, enums, 42 tablas
│       └── triggers_sga.sql  # Reglas de negocio (11 triggers)
├── supabase/
│   ├── config.toml            # Configuración para Supabase CLI local
│   └── migrations/            # Migraciones versionadas del schema y triggers
├── tests/
│   └── sql/
│       └── smoke_test.sql    # Validación funcional end-to-end
└── .env.example               # Variables requeridas por la aplicación
└── README.md
```

## Requisitos

- Cuenta y proyecto en [Supabase](https://supabase.com) (Postgres + Auth + RLS).
- Node.js 20+ y `npx supabase` (Supabase CLI) para aplicar el schema.
- `psql` disponible en el path (opcional, para correr los scripts SQL directo).

## Dominios modelados

| Dominio | Tablas principales |
|---|---|
| Identidad | `persona`, `persona_rol` |
| Alumno / Legajo | `legajo`, `titulo_previo`, `dato_familiar`, `hito_academico`, `inhibicion`, `excepcion`, `documento_requerido`, `documento_legajo` |
| Facturación | `arancel_credito`, `item_facturable`, `item_facturable_legajo`, `beca_descuento`, `beca_descuento_legajo`, `factura`, `factura_detalle`, `orden_pago`, `orden_pago_factura`, `evento_webhook_mp` |
| Plan de estudios | `escuela`, `departamento`, `carrera`, `plan_estudio`, `materia`, `plan_materia`, `correlativa` |
| Cursada / Calificaciones | `curso`, `comision`, `inscripcion_curso`, `inscripcion_examen_final`, `examen_especial`, `examen_especial_intento` |
| Docentes | `docente`, `docente_comision`, `ausencia_docente`, `evaluacion_docente` |
| Aulas / Infraestructura | `edificio`, `aula`, `horario_comision`, `evento_academico`, `examen_final` |
| Institucional | `cargo_institucional`, `autoridad`, `cronograma_academico`, `notificacion`, `mensaje` |
| Encuestas | `encuesta`, `encuesta_respuesta` |

Una `persona` es la entidad raíz: puede ser alumno, docente, ayudante y/o
administrativo simultáneamente, cada rol vía `persona_rol`.

## Reglas de negocio implementadas (`triggers_sga.sql`)

1. Máximo 3 intentos de examen final por cursada; el tercero desaprobado
   marca la cursada como `DESAPROBADA` (hay que recursar, no se reutiliza
   la fila).
2. Numeración de intentos de final consecutiva, sin saltos.
3. Nota definitiva = promedio 50/50 entre `nota_cursada` y el intento de
   final que aprueba (≥ 4). No se permiten intentos adicionales una vez
   aprobado.
4. Un docente solo puede cargar notas de comisiones que efectivamente
   dicta (validado contra `docente_comision`).
5. La comisión de una inscripción debe pertenecer al mismo curso.
6. El examen final rendido debe pertenecer al mismo curso que la cursada.
7. **Regla SMA**: `rendimiento_academico` del legajo se recalcula
   automáticamente en cada nota definitiva cargada; si cae debajo de 4,
   `condicional_especial` pasa a `TRUE`.
8. `evaluacion_docente.calificacion` se recalcula como promedio de
   `encuesta_respuesta.puntaje` al cerrarse la encuesta de desempeño.
9. Los `item_facturable` quedan **activos por default** para todo alumno
   (tanto al crear el ítem para legajos existentes, como al crear un
   legajo nuevo contra ítems existentes) — la baja es manual.
10. Una factura no puede tener dos órdenes de pago `PENDIENTE` a la vez.
11. Al confirmarse el pago de una orden, todas las facturas cubiertas
    pasan a `PAGADA`.

## Asunciones de diseño sin confirmar

Como el proyecto ya no pasa por validación con la Secretaría, estas
decisiones quedan documentadas como asunciones razonables, no como hechos
confirmados — revisar si en algún momento se puede validar:

- `departamento` es independiente de `escuela` (transversal a varias
  carreras), no una subdivisión suya.
- `curso`/`comision` siguen la misma lógica estructural que
  `instancia`/`comision` de SecAdmision, pero sin el cupo fijo en 24
  (depende del aula asignada).
- `carrera.nivel_informatico` es un campo suelto sin lógica relacional
  propia (posible remanente de integración con un sistema legado).
- Confirmación de pago vía Mercado Pago: webhook como mecanismo primario
  + reconciliación periódica de respaldo (no implementado aún, es lógica
  de backend, no de base de datos).

## Configuración local

### 1. Instalar los requisitos

- Node.js 20+.
- Docker Desktop, abierto y en ejecución (requerido por Supabase local).

### 2. Levantar Supabase local

Desde la carpeta `sga/`:

```bash
npx supabase start
```

El comando muestra la URL, la publishable key y la cadena de conexión local.
Copiarlas en un archivo `.env.local`, creado a partir de `.env.example`.

### 3. Aplicar migraciones

Las migraciones son la fuente de verdad para entornos nuevos. Para reconstruir
la base local desde cero:

```bash
npx supabase db reset
```

Actualmente se aplican, en orden:

- `20260917000000_initial_schema.sql`: tablas, enums e índices.
- `20260917000001_business_rules.sql`: triggers y funciones de negocio.

Los archivos originales en `src/sql/` se conservan como referencia histórica.

### 4. Crear el proyecto Supabase remoto

Crear un proyecto en [supabase.com](https://supabase.com) (o levantar Supabase
local con `npx supabase start`) y tomar la cadena de conexión a Postgres.

Para un proyecto remoto, vincularlo y subir las migraciones:

```bash
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
```

Las políticas RLS por rol (`persona_rol`) todavía no están escritas — ver
Roadmap.

## Pruebas

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/sql/smoke_test.sql
```

El smoke test corre dentro de una transacción con `ROLLBACK` final — no
modifica la base sobre la que se ejecuta. Cubre: activación automática de
facturables (en ambos sentidos: legajo nuevo → ítems existentes, e ítem
nuevo → legajos existentes), validación docente↔comisión, numeración y
tope de intentos de final, cálculo de nota definitiva, y propagación a
`rendimiento_academico`/`condicional_especial`.
