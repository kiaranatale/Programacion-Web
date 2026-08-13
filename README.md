# Sistema de Gestión Académica

Proyecto final de Programación Web (ITBA). Plataforma de gestión académica con roles de **alumno**, **profesor** y **administrador**: inscripción a materias con validación de correlatividades, carga de notas, y pago de matrícula/cuotas con Mercado Pago.

## Stack

- [Next.js](https://nextjs.org) (App Router, TypeScript, Server Components)
- [Tailwind CSS](https://tailwindcss.com) + componentes estilo [shadcn/ui](https://ui.shadcn.com)
- [Supabase](https://supabase.com) (Postgres, Auth, Row Level Security)
- [Mercado Pago](https://www.mercadopago.com.ar/developers) (Checkout + Webhooks)
- [Playwright](https://playwright.dev) (testing end-to-end)
- GitHub Actions (CI/CD) + Vercel (deploy)

## Desarrollo local

```bash
npm install
npm run dev
```

Abrí [http://localhost:3000](http://localhost:3000).

Copiá `.env.local.example` a `.env.local` y completá las variables cuando se configure Supabase / Mercado Pago (etapas 2, 3 y 7 del roadmap).

## Estructura del proyecto

```
src/
  app/
    page.tsx          # landing
    login/             # login (etapa Auth)
    registro/          # registro (etapa Auth)
    alumno/            # panel del alumno
    profesor/          # panel del profesor
    admin/             # panel de administración
  components/
    ui/                # componentes base estilo shadcn/ui
  lib/
    utils.ts           # helpers (cn, etc.)
docs/
  apuntes/             # apuntes de práctica de JS de la cursada
```

## Roles

- **Alumno**: se inscribe a materias (validando correlatividades), consulta notas y paga matrícula/cuotas.
- **Profesor**: ve sus cursadas asignadas y carga notas.
- **Admin**: administra carreras, materias, correlatividades, cursadas y usuarios.

## Roadmap del proyecto

1. ✅ Setup: Next.js + Tailwind + shadcn/ui + estructura del repo
2. Modelo de datos + RLS en Supabase
3. Auth + roles + middleware de rutas protegidas
4. CRUD admin (materias, carreras, correlatividades, usuarios)
5. Flujo alumno: inscripción con validación de correlatividades
6. Flujo profesor: carga de notas
7. Integración Mercado Pago (checkout + webhook)
8. Testing con Playwright
9. CI/CD con GitHub Actions + deploy a Vercel
10. Pulido de UI/UX y demo final
