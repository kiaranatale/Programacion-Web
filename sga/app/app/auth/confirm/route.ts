import { type EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Destino del link del mail de recuperación de contraseña. Acepta las dos
// formas que puede tener el link de Supabase: token_hash (plantilla de
// mail personalizada, funciona en cualquier navegador) o code (plantilla
// por defecto, en el mismo navegador donde se pidió). Con la sesión ya
// iniciada, lleva a elegir la contraseña nueva.
export async function GET(request: NextRequest) {
  const url = request.nextUrl;
  const tokenHash = url.searchParams.get("token_hash");
  const tipo = url.searchParams.get("type") as EmailOtpType | null;
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/usuario/clave";
  // Solo rutas internas, para que el link no pueda llevar a otro sitio.
  const destino = next.startsWith("/") && !next.startsWith("//") ? next : "/usuario/clave";

  const supabase = await createClient();
  let ok = false;
  if (tokenHash && tipo) {
    ok = !(await supabase.auth.verifyOtp({ token_hash: tokenHash, type: tipo })).error;
  } else if (code) {
    ok = !(await supabase.auth.exchangeCodeForSession(code)).error;
  }

  return NextResponse.redirect(new URL(ok ? destino : "/login?error=link", url.origin));
}
