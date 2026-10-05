"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// La base valida período, plan, correlativas, cupo y superposición.
function volver(q: string, error: string | null, ok: string): never {
  revalidatePath("/inscripciones/cursadas");
  const p = new URLSearchParams(q ? { q } : {});
  p.set(error ? "error" : "ok", error ?? ok);
  redirect(`/inscripciones/cursadas?${p}`);
}

export async function inscribirme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("inscribirse_cursada", { p_comision_id: Number(formData.get("comision_id")) });
  volver(String(formData.get("q") ?? ""), error?.message ?? null, `Te inscribiste en ${formData.get("materia")}.`);
}

export async function darmeDeBaja(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("desinscribirse_cursada", { p_inscripcion_id: Number(formData.get("inscripcion_id")) });
  volver(String(formData.get("q") ?? ""), error?.message ?? null, `Te diste de baja de ${formData.get("materia")}.`);
}
