import { createClient } from "@/lib/supabase/server";

const VENTANA_SEGUNDOS = 15 * 60;

// ¿La sesión viene del link de recuperación de contraseña de hace menos de
// 15 minutos? En ese caso se puede elegir una contraseña nueva sin
// ingresar la actual. Se mira el claim "amr" del token de Supabase, que
// dice cómo se inició la sesión (el usuario ya fue validado por el
// middleware con getUser).
export async function esRecuperacionReciente(): Promise<boolean> {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) return false;
  try {
    const payload = JSON.parse(Buffer.from(session.access_token.split(".")[1], "base64url").toString());
    const ahora = Math.floor(Date.now() / 1000);
    return (payload.amr ?? []).some(
      (m: { method?: string; timestamp?: number }) =>
        (m.method === "recovery" || m.method === "otp") && ahora - (m.timestamp ?? 0) < VENTANA_SEGUNDOS,
    );
  } catch {
    return false;
  }
}

export const LARGO_MINIMO = 8;
