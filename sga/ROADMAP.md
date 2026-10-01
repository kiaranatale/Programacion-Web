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
   En el proyecto remoto, además, hay que agregar `sga` en
   **Project Settings → Data API → Exposed schemas** (el `config.toml`
   solo aplica a Supabase local).
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

| Herramienta | Para qué | Cómo comprobar |
|---|---|---|
| **Git** | Clonar y versionar | `git --version` |
| **Node.js 20 LTS o superior** (recomendado 22) | Correr Next.js y la CLI de Supabase vía `npx` | `node -v` |
| **Docker Desktop** (abierto mientras trabajás) | Supabase local corre en contenedores | `docker info` |
| **VS Code** (o tu editor) | Editar | — |
| `psql` (opcional) | Correr los tests SQL a mano. Alternativa: pegar el SQL en Supabase Studio | `psql --version` |

Extensiones de VS Code útiles: ESLint, Tailwind CSS IntelliSense,
PostgreSQL (o "SQLTools").

Cuentas (gratis): GitHub (ya la tenés), Supabase (para el proyecto
remoto, más adelante), Vercel (deploy), Mercado Pago Developers (sandbox).

En Windows: instalar Docker Desktop con WSL 2 habilitado.

## 4. Cómo levantarlo para probar

```bash
git clone https://github.com/kiaranatale/Programacion-Web.git
cd Programacion-Web/sga

# 1. Base de datos local (primera vez tarda: baja las imágenes de Docker)
npx supabase start          # muestra API URL, publishable key, DB URL y Studio
npx supabase db reset       # reaplica todas las migraciones desde cero

# 2. Tests SQL (usar la "DB URL" que mostró supabase start)
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f tests/sql/smoke_test.sql
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f tests/sql/rls_test.sql

# 3. App
cd app
cp ../.env.example .env.local   # completar URL y PUBLISHABLE_KEY con lo de supabase start
npm install
npm run dev                     # http://localhost:3000
```

- Supabase Studio local: <http://127.0.0.1:54323> (ver tablas, correr SQL,
  crear usuarios de Auth a mano).
- Mails de Auth local (confirmaciones, magic links): <http://127.0.0.1:54324>.
- Para apagar: `npx supabase stop`.

## 5. Ruta sugerida, paso a paso

Cada paso termina en algo que podés probar en el navegador o con un test.

### Paso 0 — Arreglar la base (1 tarde)
- Migración nueva `supabase/migrations/2026100100000X_grants_sga.sql` con
  los `GRANT` del problema 1.
- `supabase/seed.sql` con un set chico de datos: 1 escuela, 1 carrera,
  1 plan, 3–4 materias, 1 edificio con 3 aulas, 1 curso con 2 comisiones.
  Activar `[db.seed] enabled = true` y `sql_paths = ["./seed.sql"]`.
- **Probar:** `npx supabase db reset` + los dos tests SQL en verde.

### Paso 1 — Autenticación (tema: Auth, middleware, sesiones)
- Páginas `app/login/page.tsx` (y `app/registro` si querés auto-registro)
  con Server Actions que llamen `supabase.auth.signInWithPassword` /
  `signUp`, y un botón de logout.
- Vincular usuario ↔ persona: lo más simple es un trigger en
  `auth.users` (AFTER INSERT) que busque la `persona` por
  `mail_institucional` y le complete `auth_user_id`.
- En el seed, crear 3 usuarios (alumno, docente, administrativo) con sus
  `persona` y `persona_rol`.
- En `lib/supabase/middleware.ts`, redirigir a `/login` si no hay usuario
  (excepto en `/login`).
- **Probar:** entrar como admin y ver las aulas en `/aulas`; entrar como
  alumno y ver lo mismo (catálogo abierto); sin sesión, ir a `/login`.

### Paso 2 — Layout y navegación por rol (tema: App Router, layouts)
- Sacar el sidebar de `page.tsx` a un `layout.tsx` compartido, con el
  nombre y rol reales del usuario logueado (reemplazar "Lucía Fernández").
- Una ruta por módulo (`/alumnos`, `/cursadas`, `/examenes`, `/facturacion`,
  `/docentes`) usando `<Link>`; mostrar solo los módulos que corresponden
  al rol.
- **Probar:** cada rol ve un menú distinto.

### Paso 3 — Primeros CRUD reales (temas: Server Components, formularios, Route Handlers)
Orden sugerido, de lo más simple a lo más complejo:
1. **Aulas/edificios** (admin): listado + alta/edición. Es un catálogo
   sin reglas raras, ideal para aprender el patrón.
2. **Mi legajo** (alumno): datos propios + materias cursadas y notas
   (RLS ya filtra al legajo propio).
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
- Para recibir webhooks en local: un túnel tipo `ngrok` o `cloudflared`.
- **Probar:** pagar con tarjeta de prueba de Mercado Pago y ver la factura
  pagada.

### Paso 5 — Tests E2E (tema: Playwright)
- `npm init playwright@latest` dentro de `sga/app`.
- Flujos mínimos: login por rol, inscripción a cursada, carga de nota,
  alumno no ve datos de otro alumno.

### Paso 6 — CI/CD y deploy (tema: DevOps)
- GitHub Actions: en cada PR, `npm ci`, `npm run lint`, `npm run build`,
  y opcionalmente Supabase local + tests SQL + Playwright.
- Proyecto Supabase remoto: `npx supabase link` + `npx supabase db push`,
  y exponer el schema `sga` (problema 1).
- Vercel: Root Directory `sga/app`, cargar
  `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY` y las de Mercado Pago.

### Paso 7 — Presentación
- Guion de demo: admin carga un curso → alumno se inscribe → docente pone
  nota → alumno ve la nota y paga una factura.
