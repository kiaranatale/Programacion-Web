"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Pide a Supabase el mail con el link para elegir una contraseña nueva.
// Siempre responde lo mismo, exista o no el mail, para no revelar qué
// cuentas hay.
export async function pedirRecuperacion(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  if (!email) redirect("/login/recuperar");

  const h = await headers();
  const origen = `${h.get("x-forwarded-proto") ?? "http"}://${h.get("x-forwarded-host") ?? h.get("host")}`;
  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${origen}/auth/confirm?next=/usuario/clave` });

  redirect("/login/recuperar?enviado=1");
}
