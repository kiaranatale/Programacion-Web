"use server";

import { redirect } from "next/navigation";
import { LARGO_MINIMO, esRecuperacionReciente } from "@/lib/clave";
import { getSesion } from "@/lib/sesion";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/usuario/clave";
const conError = (mensaje: string): never => redirect(`${PAGINA}?error=${encodeURIComponent(mensaje)}`);

// Cambia la contraseña. Pide la actual salvo que se llegue desde el link
// de recuperación.
export async function cambiarClave(formData: FormData) {
  const actual = String(formData.get("actual") ?? "");
  const nueva = String(formData.get("nueva") ?? "");
  const repetida = String(formData.get("repetida") ?? "");

  if (nueva.length < LARGO_MINIMO) conError(`La contraseña nueva tiene que tener al menos ${LARGO_MINIMO} caracteres.`);
  if (nueva !== repetida) conError("Las dos contraseñas nuevas no coinciden.");

  const sesion = await getSesion();
  if (!sesion) redirect("/login");
  const supabase = await createClient();

  if (!(await esRecuperacionReciente())) {
    if (!actual) conError("Ingresá tu contraseña actual.");
    if (actual === nueva) conError("La contraseña nueva tiene que ser distinta de la actual.");
    const { error } = await supabase.auth.signInWithPassword({ email: sesion.email, password: actual });
    if (error) conError("La contraseña actual no es correcta.");
  }

  const { error } = await supabase.auth.updateUser({ password: nueva });
  if (error) {
    if (error.code === "same_password") conError("La contraseña nueva tiene que ser distinta de la actual.");
    if (error.code === "weak_password") conError("La contraseña nueva es muy débil. Probá con una más larga, con letras y números.");
    conError("No se pudo cambiar la contraseña. Probá de nuevo.");
  }

  redirect(`${PAGINA}?ok=1`);
}
