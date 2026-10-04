import { createClient } from "@supabase/supabase-js";

// Cliente con la clave service_role: SOLO para el servidor (webhook y
// confirmación de pagos de Mercado Pago). Nunca importarlo desde un
// componente de cliente ni exponer la clave como NEXT_PUBLIC_*.
export function createAdminClient() {
  const clave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!clave) throw new Error("Falta la variable SUPABASE_SERVICE_ROLE_KEY");
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, clave, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
