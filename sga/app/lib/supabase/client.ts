import { createBrowserClient } from "@supabase/ssr";

// Cliente para Client Components. Usa la clave pública (publishable),
// segura para el navegador; el acceso real a los datos queda acotado
// por las políticas RLS del rol autenticado.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
