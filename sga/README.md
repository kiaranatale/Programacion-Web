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
- Frontend conectado a Supabase (la app hoy es una demo sin datos reales).
- Supabase Auth (login/registro) y el flujo que vincula un usuario de Auth
  con su `persona` (`persona.auth_user_id`).
- Vistas de solo-lectura (ocupación de aulas con alertas, agenda del día).
- Integración real con Mercado Pago (el modelo de datos para QR/órdenes de
  pago está listo, falta la lógica de aplicación).

Disponible desde la última actualización:

- Políticas RLS por rol (`persona_rol`) sobre las 49 tablas del schema
  `sga`, en `20261001000000_rls_policies.sql`. Alumnos solo ven su propio
  legajo/facturación; docentes ven alumnos y notas de sus comisiones;
  administrativos tienen acceso total. Catálogos (carreras, aulas, etc.)
  son de lectura abierta para cualquier usuario autenticado.
- Columna `persona.auth_user_id` para vincular una `persona` con su
  usuario de Supabase Auth (todavía no se crea automáticamente — falta el
  flujo de registro/login).

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
│       ├── ddl_sga.sql       # Schema, enums, tablas (copia histórica)
│       └── triggers_sga.sql  # Reglas de negocio (copia histórica)
├── supabase/
│   ├── config.toml            # Configuración para Supabase CLI local
│   ├── migrations/            # Migraciones versionadas: fuente de verdad del schema
│   └── seed.sql               # Datos de prueba (catálogos, aulas, cursos)
├── tests/
│   └── sql/
│       ├── smoke_test.sql    # Validación funcional de los triggers
│       └── rls_test.sql      # Validación de las políticas RLS
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
- `carrera.nivel_informatico` corresponde al "Nivel informativo" del
  listado de carreras del SGA actual (hoy siempre "Grado" en grado).
  Sigue sin lógica relacional propia.
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
Para la aplicación Next.js, crear `app/.env.local` a partir de `.env.example`
(el archivo debe quedar dentro de `sga/app/`, que es la raíz de Next.js).

### 3. Aplicar migraciones

Las migraciones son la fuente de verdad para entornos nuevos. Para reconstruir
la base local desde cero:

```bash
npx supabase db reset
```

Actualmente se aplican, en orden:

- `20260917000000_initial_schema.sql`: tablas, enums e índices.
- `20260917000001_business_rules.sql`: triggers y funciones de negocio.
- `20261001000000_rls_policies.sql`: `persona.auth_user_id`, funciones
  helper (`sga.es_admin()`, `sga.legajo_actual_id()`, etc.) y políticas RLS
  por rol sobre las 49 tablas del schema.
- `20261001000001_grants_sga.sql`: permisos de los roles de la Data API
  (`anon`, `authenticated`, `service_role`) sobre el schema `sga`. Sin
  esto, Supabase rechaza cualquier consulta al schema.
- `20261002000000_auth_vinculo_persona.sql`: vínculo automático entre
  usuarios de Supabase Auth y `persona` por mail institucional, y triggers
  de notas como `SECURITY DEFINER` para que funcionen con RLS.
- `20261003000000_documento_requerido_unico.sql`: evita documentos
  requeridos duplicados cuando carrera y nivel quedan en NULL.
- `20261003000001_carrera_nombre_plan_version.sql`: nombre de la carrera
  (además del oficial) y versión del plan, como en el SGA actual.
- `20261003000002_plan_bloques.sql`: bloques del plan con su requisito
  (aprobar todos / juntar créditos), huecos de electivas en la grilla,
  créditos requeridos, correlativas por plan, títulos que otorga el plan
  y materias de 0 créditos.
- `20261004000000_cursos_reales.sql`: varios cursos de una materia en el
  mismo período (bimestrales), créditos de materia opcionales y la vista
  `curso_listado` con la cantidad de alumnos por curso.
- `20261004000001_curso_plantel.sql`: responsable del curso, cargo de cada
  docente, contenidos mínimos de la materia y la vista `curso_plantel`
  (nombre, cargo y mail institucional de los docentes de cada curso).
- `20261004000002_documentacion_carga.sql`: bucket privado
  `documentacion` en Supabase Storage con políticas por legajo, y
  funciones para que el alumno suba/elimine documentos (quedan
  "Pendiente de validación") y Administración los apruebe o rechace.
- `20261004000003_ocupacion_aulas.sql`: función `ocupacion_aulas(fecha)`
  con clases, eventos y exámenes por aula y la cantidad de inscriptos
  (para Administración → Ocupación de Aulas).

Datos en el SQL Editor, en este orden (todos se pueden volver a correr):

1. `supabase/seed.sql`: carreras reales, aulas, cursos y comisiones.
2. `supabase/seed_plan_a22.sql`: plan A22 completo de LAES (119 materias,
   bloques de electivas, correlativas).
3. `supabase/seed_cursos.sql`: 492 cursos reales del segundo cuatrimestre
   2026 con su departamento (generado con `scripts/csv_a_seed_cursos.py`;
   ver "Cómo bajar el listado de cursos" en ROADMAP.md).
4. `supabase/seed_usuarios.sql`: personas de prueba.
5. `supabase/seed_legajo_demo.sql`: legajo completo de la alumna.

Usuarios de prueba: `supabase/seed_usuarios.sql` crea alumno, docente y administrativo; los usuarios de Auth
se crean en el dashboard con los mismos mails.

Legajo de demo: `supabase/seed_legajo_demo.sql` (correr después de
`seed_usuarios.sql`) completa todas las solapas de "Mi legajo" de la
alumna: títulos, cursadas anteriores con finales, documentación,
exámenes habilitados, facturas y pagos.

Datos de prueba: `supabase/seed.sql` (escuela, carrera, plan, materias,
edificios, aulas, cursos, comisiones y horarios). En Supabase en la nube se
corre pegándolo en el SQL Editor; se puede ejecutar más de una vez.

Los archivos originales en `src/sql/` se conservan como referencia histórica.

### 4. Crear el proyecto Supabase remoto

Crear un proyecto en [supabase.com](https://supabase.com) (o levantar Supabase
local con `npx supabase start`) y tomar la cadena de conexión a Postgres.

Para un proyecto remoto, vincularlo y subir las migraciones:

```bash
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
```

Las políticas RLS por rol (`persona_rol`) ya están escritas en
`20261001000000_rls_policies.sql`. Falta integrar Supabase Auth en la app
para que `persona.auth_user_id` se complete al registrarse/iniciar sesión.

### 5. Desplegar la app en Vercel

La app está en `sga/app/`. Vercel publica la rama `main` como producción y
cada push a otra rama como una *preview* con su propia URL.

1. En [vercel.com](https://vercel.com), **Add New → Project** e importar el
   repositorio de GitHub.
2. **Root Directory:** `sga/app`. El framework se detecta como Next.js; los
   comandos de build y el directorio de salida quedan en sus valores
   automáticos.
3. **Environment Variables** (antes del primer deploy: las `NEXT_PUBLIC_*`
   se incorporan al código en el build):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
4. **Deploy**. Si las variables se agregan o cambian después, hace falta un
   **Redeploy** para que tomen efecto.
5. En Supabase, **Authentication → URL Configuration → Site URL**: poner la
   URL de producción de Vercel (la usan los mails de Auth, como el de
   recuperar contraseña).

No configurar `SUPABASE_SERVICE_ROLE_KEY` como variable `NEXT_PUBLIC_*` ni
usarla en componentes del navegador; cuando haga falta (webhook de Mercado
Pago) va solo como variable de servidor.

Límite de Vercel: los pedidos al servidor no pueden superar 4,5 MB, por eso
la carga de documentación acepta archivos de hasta 4 MB.

Para comprobar la app localmente, ejecutar desde `sga/app/`:

```bash
npm install
npm run dev
```

La verificación de producción es `npm run build`.

## Pruebas

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/sql/smoke_test.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/sql/rls_test.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/sql/auth_test.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/sql/documentacion_test.sql
```

También se pueden pegar completos en el **SQL Editor** del dashboard de
Supabase (no usan comandos propios de `psql`).

Ambos corren dentro de una transacción con `ROLLBACK` final — no modifican
la base sobre la que se ejecutan.

- `smoke_test.sql` cubre: activación automática de facturables (en ambos
  sentidos: legajo nuevo → ítems existentes, e ítem nuevo → legajos
  existentes), validación docente↔comisión, numeración y tope de intentos
  de final, cálculo de nota definitiva, y propagación a
  `rendimiento_academico`/`condicional_especial`.
- `rls_test.sql` cubre las políticas RLS: un alumno solo ve su propio
  legajo, un administrativo ve todos, y el rol `anon` (sin sesión) no ve
  ninguno. Requiere correr contra una instancia de Supabase (no un
  Postgres pelado), ya que depende del schema `auth` y de los roles
  `anon`/`authenticated`.
