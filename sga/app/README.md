# SGA: app Next.js

App del Sistema de Gestión Académica, publicada en
**https://itbasga.vercel.app**. La documentación completa (modelo de
datos, migraciones, seeds y deploy) está en [../README.md](../README.md).

## Correrla en local

Necesita una Supabase con las migraciones y los seeds de `sga/supabase/`
(ver "Configuración local" en el README del proyecto) y un `.env.local`
armado a partir de `sga/.env.example`.

```bash
npm install
npm run dev     # http://localhost:3000
npm run build   # verificación de producción
npm run lint
```

## Tests E2E

Corren contra una Supabase local (`supabase start` en `sga/`):

```bash
bash ../scripts/e2e_preparar.sh   # seeds, usuarios demo y .env.e2e
npm run e2e
```

## Carpetas

- `app/`: rutas (App Router). `login/` y `auth/` son el ingreso; `(sga)/`
  tiene todas las pantallas con sesión; `api/mercadopago/webhook` recibe
  los avisos de pago.
- `components/`: menú lateral, solapas, grilla semanal y armador de
  horarios.
- `lib/`: acceso a datos por pantalla, sesión, clientes de Supabase y
  Mercado Pago.
- `e2e/`: tests de Playwright.
- `proxy.ts`: renueva la sesión de Supabase en cada pedido.
