# Setup de Supabase

## 1. Crear el proyecto

1. Entrá a [supabase.com/dashboard](https://supabase.com/dashboard) y logueate (podés usar tu cuenta de GitHub).
2. **New project** → elegí una organización, un nombre (ej. `gestion-academica`), una contraseña de base de datos (guardala) y una región cercana.
3. Esperá a que termine de aprovisionarse (~2 min).

## 2. Correr las migraciones

En el dashboard del proyecto, andá a **SQL Editor** → **New query**, y corré en orden el contenido de estos archivos (cada uno es un `New query` separado):

1. `supabase/migrations/20260813120000_init_schema.sql` — tablas, enums, índices.
2. `supabase/migrations/20260813120100_auth_trigger.sql` — crea el perfil en `usuarios` automáticamente al registrarse, y la función `rol_actual()`.
3. `supabase/migrations/20260813120200_rls.sql` — políticas de Row Level Security.

Opcional, para tener datos de prueba:

4. `supabase/seed.sql` — algunas carreras/materias/correlatividades de ejemplo.

> Alternativa con el CLI de Supabase (si lo tenés instalado y logueado):
> `npx supabase link --project-ref <tu-project-ref>` y después `npx supabase db push`.

## 3. Obtener las API keys

En **Project Settings → API**:

- `Project URL` → `NEXT_PUBLIC_SUPABASE_URL`
- `anon public` key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `service_role` key (¡secreta, no exponer al cliente!) → `SUPABASE_SERVICE_ROLE_KEY`

Copiá `.env.local.example` a `.env.local` y completá esas tres variables.

En Vercel: **Project → Settings → Environment Variables**, cargá las mismas tres (la `service_role` sin marcar "expose to client").

## 4. Cómo quedó modelado

- `usuarios` extiende `auth.users` de Supabase (1:1), con un campo `rol` (`alumno` / `profesor` / `admin`). Se crea automáticamente vía trigger cuando alguien se registra.
- `carreras` → `materias` → `correlatividades` (qué materia requiere tener aprobada cuál otra).
- `cursadas`: una materia dictada en un año/cuatrimestre puntual, con un profesor asignado.
- `inscripciones_cursada`: alumno inscripto a una cursada, con estado (`inscripto`, `regular`, `libre`, `abandonada`).
- `notas`: nota de un alumno en una cursada (parcial 1, parcial 2, recuperatorio, final).
- `pagos`: matrícula/cuotas de un alumno, con estado y el ID de pago de Mercado Pago (para conciliar vía webhook).

Todas las tablas tienen RLS habilitado: cada rol solo ve y modifica lo que le corresponde (ver `supabase/migrations/20260813120200_rls.sql` para el detalle policy por policy).

## 5. Rol de admin

Como no hay un flujo de "alta de admin" todavía (llega en la etapa de CRUD admin), para probar como administrador:

1. Registrate normalmente desde `/registro` (te va a quedar rol `alumno`).
2. En el SQL Editor de Supabase, corré:
   ```sql
   update public.usuarios set rol = 'admin' where email = 'tu-email@ejemplo.com';
   ```
