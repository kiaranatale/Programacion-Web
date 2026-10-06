"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/proyectos";

// Valida o rechaza (con motivo) un proyecto cargado por un alumno.
export async function revisarProyecto(formData: FormData) {
  const validar = formData.get("decision") === "validar";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("revisar_proyecto", {
    p_id: Number(formData.get("id")),
    p_validar: validar,
    p_observaciones: String(formData.get("observaciones") ?? "").trim() || null,
  });
  revalidatePath(PAGINA);
  const mensaje = error ? `error=${encodeURIComponent(error.message)}` : `ok=${encodeURIComponent(validar ? "Proyecto validado." : "Proyecto rechazado.")}`;
  redirect(`${PAGINA}?${mensaje}`);
}
