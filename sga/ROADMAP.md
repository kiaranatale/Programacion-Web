# Ruta de trabajo del SGA

Revisión del estado del proyecto al 01/10/2026 y pasos sugeridos para seguir.

## 1. Qué hay hoy (y qué se probó)

| Pieza | Estado | Verificado |
|---|---|---|
| Schema `sga` (49 tablas, enums, índices) | Listo | Las 3 migraciones aplican sin errores |
| Triggers de negocio (11 reglas) | Listos | `tests/sql/smoke_test.sql` pasa |
| Políticas RLS por rol | Escritas | `tests/sql/rls_test.sql` **falla** (ver problema 1) |
| App Next.js 16 + clientes Supabase (`lib/supabase/`, `proxy.ts`) | Lista | `npm ci`, `npm run lint` y `npm run build` pasan |
| Pantalla de inicio (`/`) | Demo con datos de muestra | — |
| Pantalla `/aulas` | Lee `sga.aula` en vivo | No va a mostrar datos todavía (ver problemas 1 y 3) |
| Login / registro | No existe | — |
| Route Handlers (`app/api/`) | No existen | — |
| Mercado Pago, Playwright, CI/CD | No existen | — |

## 2. Problemas encontrados

1. **Faltan los `GRANT` sobre el schema `sga` (bloqueante).** Supabase solo
   da permisos automáticos sobre `public`. Para un schema propio hay que
   darlos explícitamente; si no, cualquier consulta desde la app o desde el
   rol `authenticated` falla con `permission denied for schema sga`
   (es lo que rompe hoy `rls_test.sql`, y lo que va a mostrar `/aulas`).
   Agregando esto en una migración nueva el test de RLS pasa:

   ```sql
   GRANT USAGE ON SCHEMA sga TO anon, authenticated, service_role;
   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sga
       TO anon, authenticated, service_role;
   GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sga
       TO anon, authenticated, service_role;
   ALTER DEFAULT PRIVILEGES IN SCHEMA sga
       GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated, service_role;
   ALTER DEFAULT PRIVILEGES IN SCHEMA sga
       GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, service_role;
   ```

   Los permisos de tabla no abren los datos: RLS sigue filtrando fila por
   fila (las políticas son `TO authenticated`, así que `anon` ve 0 filas).
   Además, en el proyecto de Supabase hay que agregar `sga` en
   **Integrations → Data API → Settings → Exposed schemas** (el `config.toml`
   solo aplica a Supabase local; ver sección 4.1).
2. **No hay datos de prueba (seed).** `[db.seed]` está deshabilitado en
   `supabase/config.toml` y no existe `supabase/seed.sql`. Aunque te
   loguees, `/aulas` va a estar vacía.
3. **No hay forma de loguearse**, así que `persona.auth_user_id` nunca se
   completa y RLS no deja ver nada a nadie.
4. **README desactualizado en algunos puntos:** dice "42 tablas" (son 49),
   y en la sección de Vercel dice que las políticas RLS "todavía no
   existen". La estructura del repo no lista `app/` ni `rls_test.sql`.
5. **SQL duplicado:** `src/sql/ddl_sga.sql` y `src/sql/triggers_sga.sql`
   son idénticos a las dos primeras migraciones. Conviene borrarlos (o
   dejar claro que no se tocan) para no editar el archivo equivocado:
   la fuente de verdad son las migraciones.
6. Menores: el `package-lock.json` de la raíz del repo está vacío y no
   sirve (el proyecto Node real está en `sga/app/`); en `app/page.tsx` el
   link a Aulas usa `<a>` en vez de `<Link>` de Next.

## 3. Qué instalar en tu compu

Se trabaja contra un proyecto de Supabase en la nube (supabase.com), sin
Docker ni Supabase local.

| Herramienta | Para qué | Cómo comprobar |
|---|---|---|
| **Git** | Clonar y versionar | `git --version` |
| **Node.js 20 LTS o superior** (recomendado 22) | Correr Next.js y la CLI de Supabase vía `npx` (no hace falta instalarla aparte) | `node -v` |
| **VS Code** (o tu editor) | Editar | — |

Extensiones de VS Code útiles: ESLint, Tailwind CSS IntelliSense.

Cuentas (gratis): GitHub (ya la tenés), Supabase, Vercel (deploy, más
adelante) y Mercado Pago Developers (sandbox, más adelante).

## 4. Cómo levantarlo para probar

### 4.1 Crear el proyecto en Supabase (una sola vez)

1. En <https://supabase.com/dashboard> → **New project**. Elegí región
   São Paulo (`sa-east-1`) y **guardá la contraseña de la base**: la vas a
   necesitar para subir migraciones.
2. Exponer el schema `sga` en la Data API: **Integrations → Data API →
   pestaña Settings → Exposed schemas** (en versiones anteriores del
   dashboard estaba en Project Settings → Data API). Agregar `sga` además
   de `public`. Sin esto la app no puede consultar el schema. **Ojo:** el
   schema tiene que existir para poder elegirlo, así que este paso se hace
   después de subir las migraciones (sección 4.2).
3. **Authentication → Sign In / Providers → Email**: para desarrollo,
   desactivar **Confirm email**, así podés crear usuarios de prueba sin
   tener que confirmar mails.
4. Anotar el **Reference ID** del proyecto (Project Settings → General),
   y la **URL** y la **publishable key** (Project Settings → API Keys /
   Data API).

### 4.2 Subir las migraciones (recomendado: con la CLI)

La CLI de Supabase **no necesita Docker** para `link` y `db push`: se
conecta directo a la base de la nube.

```bash
git clone https://github.com/kiaranatale/Programacion-Web.git
cd Programacion-Web/sga

npx supabase login                               # abre el navegador
npx supabase link --project-ref TU_REFERENCE_ID  # pide la contraseña de la base
npx supabase db push                             # aplica las migraciones que falten
```

Cada vez que agregues una migración nueva en `supabase/migrations/`,
volvés a correr `npx supabase db push` y solo se aplica lo nuevo.

> Alternativa sin CLI: pegar el contenido de cada archivo de
> `supabase/migrations/`, en orden, en el **SQL Editor** del dashboard.
> Sirve para salir del paso, pero Supabase no registra que se aplicaron,
> y si después usás `db push` intenta aplicarlas de nuevo y falla.
> **Elegí un solo método y quedate con ese** (recomendado: la CLI).

### 4.3 Correr los tests SQL

Abrir **SQL Editor → New query**, pegar el contenido completo de
`tests/sql/smoke_test.sql` y ejecutar. Después lo mismo con
`tests/sql/rls_test.sql`. Ambos terminan en `ROLLBACK`, así que no dejan
datos en la base. Si algo falla, el editor muestra el error (ej. el
`RAISE EXCEPTION` con la regla que no se cumplió).

Recordá que `rls_test.sql` va a fallar hasta hacer el Paso 0 (los `GRANT`).

### 4.4 Levantar la app

```bash
cd app
cp ../.env.example .env.local   # completar NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
npm install
npm run dev                     # http://localhost:3000
```

- Ver y editar datos: **Table Editor** del dashboard (elegir schema `sga`
  arriba a la izquierda).
- Crear usuarios de prueba a mano: **Authentication → Users → Add user**.
- Las claves `SUPABASE_SERVICE_ROLE_KEY` y la contraseña de la base nunca
  se suben al repo (`.env.local` ya está en `.gitignore`).

## 5. Ruta sugerida, paso a paso

Cada paso termina en algo que podés probar en el navegador o con un test.

### Paso 0 — Arreglar la base ✅ hecho

Hecho en `supabase/migrations/20261001000001_grants_sga.sql` y
`supabase/seed.sql`. Los tests SQL ahora filtran por sus propios datos, así
que pasan también con el seed cargado. Lo que sigue es el detalle original:

- Migración nueva `supabase/migrations/2026100100000X_grants_sga.sql` con
  los `GRANT` del problema 1.
- `supabase/seed.sql` con un set chico de datos: 1 escuela, 1 carrera,
  1 plan, 3–4 materias, 1 edificio con 3 aulas, 1 curso con 2 comisiones.
  Como no usamos Supabase local, el seed se corre pegándolo una vez en el
  SQL Editor (`db push` no carga seeds en la nube). Escribirlo de forma
  que se pueda correr dos veces sin romper (`ON CONFLICT DO NOTHING`).
- **Probar:** `npx supabase db push`, correr el seed y los dos tests SQL
  en verde desde el SQL Editor; en Table Editor ver las aulas cargadas.

### Paso 1 — Autenticación ✅ hecho (tema: Auth, middleware, sesiones)

- `supabase/migrations/20261002000000_auth_vinculo_persona.sql`: triggers
  que vinculan `auth.users` ↔ `sga.persona` por mail institucional (en
  los dos órdenes, solo mails confirmados), y `SECURITY DEFINER` en
  `procesar_nota_final` / `recalcular_rendimiento_academico` (antes, la
  nota que cargaba un docente no actualizaba el rendimiento del legajo).
- `app/login/` (página + Server Action), `app/auth/actions.ts` (logout) y
  redirección a `/login` sin sesión en `lib/supabase/middleware.ts`.
- La pantalla de inicio muestra nombre y rol reales del usuario.
- `supabase/seed_usuarios.sql`: alumno, docente y administrativo de prueba
  (`alumno.demo@`, `docente.demo@`, `admin.demo@itba.edu.ar`).
- `tests/sql/auth_test.sql`: vínculo en ambos órdenes y carga de nota de
  un docente con RLS activo.
- **Configuración en el dashboard:** desactivar el registro público
  (Authentication → Sign In / Providers → "Allow new users to sign up"),
  porque la vinculación es automática por mail: los usuarios se crean
  solo desde el dashboard.

### Paso 2 — Layout y navegación por rol (tema: App Router, layouts) — en curso

Hecho:
- Estética basada en el SGA actual (banda azul, menú gris, cajas y tablas).
- `app/(sga)/layout.tsx`: encabezado y menú compartidos por todas las
  pantallas con sesión; el menú muestra solo lo que corresponde al rol.
- Inicio con datos reales: notificaciones, cronogramas y "Cursos en
  progreso" (alumno: lo que cursa; docente: lo que dicta; administrativo:
  todas las comisiones), en `lib/cursos.ts`.

Falta:
- Una ruta por módulo (`/cursos`, `/examenes`, `/legajo`, etc.): hoy
  aparecen en gris en el menú.
- **Probar:** cada rol ve un menú y unos cursos distintos.

### Pantallas del SGA actual (según `Estructuracion_SGA.pdf`)

Inventario de lo que muestra el SGA actual, con las tablas que ya lo
cubren y el orden sugerido (columna **#**). "Falta modelo" = hay que
agregar tablas antes de hacer la pantalla.

| # | Menú → Pantalla | Qué muestra | Tablas | Estado |
|---|---|---|---|---|
| — | Inicio | Notificaciones, tareas, trámites, cronogramas, cursos en progreso | `notificacion`, `cronograma_academico`, `inscripcion_curso`, `horario_comision` | ✅ Hecho (tareas y trámites son texto fijo) |
| 1 | Legajos → Mi legajo → **General** | Foto y datos personales | `persona`, `legajo` | Pendiente (foto: falta Supabase Storage) |
| 1 | Mi legajo → **Títulos** | Títulos previos | `titulo_previo` | Pendiente |
| 1 | Mi legajo → Datos del alumno → **Roles** | Roles, legajos, carreras en curso, historial de actividades | `persona_rol`, `legajo`, `plan_estudio`, `hito_academico` | Pendiente |
| 2 | Datos del alumno → **Analítico de notas** | Rendimiento, créditos aprobados / en curso, % de carrera, materias por año con cursada y finales | `legajo`, `plan_materia`, `inscripcion_curso`, `inscripcion_examen_final` | Pendiente |
| 2 | Datos del alumno → **Historia académica** | Materias por cuatrimestre con nota de cursada y final | `inscripcion_curso`, `inscripcion_examen_final`, `curso` | Pendiente |
| 3 | Datos del alumno → **Calendario semanal** | Grilla lunes–sábado con los horarios de cada materia | `inscripcion_curso`, `horario_comision` | Pendiente |
| 4 | Administración → **Ocupación de Aulas** | Grilla aula × hora: cursos, eventos, exámenes, capacidad excedida | `aula`, `horario_comision`, `evento_academico`, `examen_final` | Hoy `/aulas` es un listado; falta la grilla |
| 5 | Académica → **Carreras** | Listado con filtros (código, escuela, nivel, activa) | `carrera`, `escuela` | Pendiente |
| 5 | Académica → **Cursos** | Listado con filtros (materia, depto., período, año, alumnos) | `curso`, `materia`, `departamento`, `inscripcion_curso` | Pendiente |
| 5 | Académica → **Autoridades** | Cargo y nombre | `autoridad`, `cargo_institucional`, `persona` | Pendiente |
| 5 | Académica → **Hoy en el ITBA** | Aulas ocupadas hoy por hora (curso, evento, examen) | `horario_comision`, `evento_academico`, `examen_final` | Pendiente |
| 6 | Datos del alumno → **Datos familiares** | Familiares | `dato_familiar` | Pendiente |
| 6 | Datos del alumno → **Historial de inhibiciones** / **Histórico excepciones** | Inhibiciones y excepciones con fechas | `inhibicion`, `excepcion` | Pendiente |
| 6 | Datos del alumno → **Exámenes habilitados** | Exámenes especiales (inglés, castellano, práctica laboral) | `examen_especial`, `examen_especial_intento` | Pendiente |
| 6 | Datos del alumno → **Documentación** | Documentos obligatorios, entregados y validados, con carga de archivos | `documento_requerido`, `documento_legajo` | Pendiente (archivos: Supabase Storage) |
| 7 | Datos del alumno → **Facturables** / Mi legajo → **Estado de cuenta** | Ítems activos, saldo, facturas y pagos | `item_facturable_legajo`, `factura`, `orden_pago` | Pendiente (Paso 4, con Mercado Pago) |
| 8 | Encuestas → **General** | Listado de encuestas con estado y fechas | `encuesta`, `encuesta_respuesta` | Pendiente |
| 9 | Usuario → **Cambio de clave** | Cambiar contraseña | Supabase Auth | Pendiente |
| 9 | Usuario → **Mensajes** | Bandeja de mensajes | `mensaje` | Pendiente |
| — | Mi legajo → **Planes de pago** | Planes de pago | — | Falta modelo |
| — | Mi legajo → **Proyectos** | Roles en proyectos (investigador, tecnólogo, etc.) | — | Falta modelo |
| — | Mi legajo → **Información personal** | Datos de Salesforce | — | Fuera de alcance (sistema externo) |

El menú de la app ya replica esta estructura (Encuestas, Académica,
Legajos, Administración, Usuario); lo no implementado aparece en gris.

### Paso 3 — Primeros CRUD reales (temas: Server Components, formularios, Route Handlers)
Orden sugerido, de lo más simple a lo más complejo:
1. **Mi legajo** (alumno): pantallas 1–3 de la tabla de arriba. Son
   lecturas (RLS ya filtra al legajo propio) y es lo que más se usa.
2. **Aulas/edificios** (admin): alta/edición. Es un catálogo sin reglas
   raras, ideal para aprender el patrón de formularios.
3. **Inscripción a cursada** (alumno): elegir curso/comisión →
   `inscripcion_curso`. El trigger de comisión↔curso ya valida.
4. **Carga de notas** (docente): sobre sus comisiones. El trigger de
   docente↔comisión ya valida; mostrar bien el error que devuelve.
5. **Finales**: inscripción e intentos (los triggers manejan los 3
   intentos y la nota definitiva).

Para cada uno: Route Handler en `app/api/<entidad>/route.ts` con
validación de entrada (por ejemplo con `zod`) y respuestas de error
claras, o Server Actions si es un formulario de la propia app.
- **Probar:** a mano en el navegador, y verificar en Studio que los
  triggers hicieron lo esperado (ej. `rendimiento_academico`).

### Paso 4 — Facturación + Mercado Pago (tema: Mercado Pago)
- Pantalla "Mis facturas" para el alumno.
- Botón "Pagar" → Route Handler que crea una preferencia de Checkout Pro
  con `MERCADO_PAGO_ACCESS_TOKEN` (sandbox) y una `orden_pago` `PENDIENTE`.
- `app/api/webhooks/mercadopago/route.ts`: valida la firma con
  `MERCADO_PAGO_WEBHOOK_SECRET`, guarda en `evento_webhook_mp` y pasa la
  orden a pagada (el trigger marca las facturas como `PAGADA`). Este
  handler usa `SUPABASE_SERVICE_ROLE_KEY` (solo en servidor).
- Para recibir webhooks mientras corrés la app en tu compu: un túnel tipo
  `ngrok` o `cloudflared`, o probarlo directamente con el deploy en Vercel.
- **Probar:** pagar con tarjeta de prueba de Mercado Pago y ver la factura
  pagada.

### Paso 5 — Tests E2E (tema: Playwright)
- `npm init playwright@latest` dentro de `sga/app`.
- Flujos mínimos: login por rol, inscripción a cursada, carga de nota,
  alumno no ve datos de otro alumno.

### Paso 6 — CI/CD y deploy (tema: DevOps)
- GitHub Actions: en cada PR, `npm ci`, `npm run lint`, `npm run build`.
  Opcional: un job que haga `supabase db push` al mergear a `main`
  (usando `SUPABASE_ACCESS_TOKEN` y la contraseña de la base como secrets
  del repo). Ideal: un segundo proyecto de Supabase para producción, así
  no probás sobre los mismos datos que muestra la demo.
- Vercel: Root Directory `sga/app`, cargar
  `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY` y las de Mercado Pago.

### Paso 7 — Presentación
- Guion de demo: admin carga un curso → alumno se inscribe → docente pone
  nota → alumno ve la nota y paga una factura.
