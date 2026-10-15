import { expect, type Page } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

// Usuarios demo de seed_usuarios.sql (los crea en Auth scripts/e2e_preparar.sh)
export const USUARIOS = {
  alumno: "alumno.demo@itba.edu.ar",
  docente: "docente.demo@itba.edu.ar",
  admin: "admin.demo@itba.edu.ar",
} as const;
export type Rol = keyof typeof USUARIOS;
export const CLAVE = "demo1234";

export async function entrar(page: Page, rol: Rol) {
  await page.goto("/login");
  await page.fill('input[name="email"]', USUARIOS[rol]);
  await page.fill('input[name="password"]', CLAVE);
  await page.click('.login-form button[type="submit"]');
  await page.waitForURL((url) => url.pathname === "/");
}

// Cliente de Supabase con la sesión de un usuario demo, para probar las
// políticas RLS directamente contra la API (como lo haría un navegador).
export async function clienteDe(rol: Rol) {
  const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, {
    auth: { persistSession: false },
  });
  const { error } = await supabase.auth.signInWithPassword({ email: USUARIOS[rol], password: CLAVE });
  expect(error).toBeNull();
  return supabase.schema("sga");
}

// Texto único por corrida, para encontrar lo que crea cada test.
export const unico = (prefijo: string) => `${prefijo} ${Date.now().toString(36)}`;
