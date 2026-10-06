"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// La base valida etapa, plan, correlativas, cupo (en la segunda
// inscripción) y superposición.
function volver(q: string, error: string | null, ok: string): never {
  revalidatePath("/inscripciones/cursadas");
  const p = new URLSearchParams(q ? { q } : {});
  p.set(error ? "error" : "ok", error ?? ok);
  redirect(`/inscripciones/cursadas?${p}`);
}

export async function inscribirme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("inscribirse_cursada", { p_comision_id: Number(formData.get("comision_id")) });
  const ok = formData.get("etapa") === "PRIMERA" ? `Solicitaste ${formData.get("materia")}.` : `Te inscribiste en ${formData.get("materia")}.`;
  volver(String(formData.get("q") ?? ""), error?.message ?? null, ok);
}

export async function darmeDeBaja(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("desinscribirse_cursada", { p_inscripcion_id: Number(formData.get("inscripcion_id")) });
  volver(String(formData.get("q") ?? ""), error?.message ?? null, `Te diste de baja de ${formData.get("materia")}.`);
}

export async function retirarSolicitud(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("retirar_solicitud_cursada", { p_solicitud_id: Number(formData.get("solicitud_id")) });
  volver(String(formData.get("q") ?? ""), error?.message ?? null, `Retiraste la solicitud de ${formData.get("materia")}.`);
}
