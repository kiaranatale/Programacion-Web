"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function volver(url: string, error: string | null, ok: string): never {
  revalidatePath("/tramites");
  revalidatePath("/administracion/tramites");
  redirect(`${url}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function iniciarTramite(formData: FormData) {
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("iniciar_tramite", {
    p_titulo: String(formData.get("titulo") ?? ""),
    p_destino: String(formData.get("destino") ?? ""),
    p_descripcion: String(formData.get("descripcion") ?? ""),
  });
  if (error || typeof data !== "number") volver("/tramites/nuevo", error?.message ?? "No se pudo enviar el trámite.", "");
  volver(`/tramites/${data}`, null, "Trámite enviado.");
}

export async function cancelarTramite(formData: FormData) {
  const id = Number(formData.get("id"));
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("cancelar_tramite", { p_id: id });
  volver(`/tramites/${id}`, error?.message ?? null, "Trámite cancelado.");
}

export async function comentarTramite(formData: FormData) {
  const id = Number(formData.get("id"));
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("comentar_tramite", { p_id: id, p_comentario: String(formData.get("comentario") ?? "") });
  volver(`/tramites/${id}`, error?.message ?? null, "Comentario agregado.");
}

// Administración: tomar, resolver o rechazar.
export async function cambiarEstadoTramite(formData: FormData) {
  const id = Number(formData.get("id"));
  const estado = String(formData.get("estado") ?? "");
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("cambiar_estado_tramite", {
    p_id: id,
    p_estado: estado,
    p_comentario: String(formData.get("comentario") ?? ""),
  });
  const ok = { EN_CURSO: "Trámite tomado.", RESUELTO: "Trámite resuelto.", RECHAZADO: "Trámite rechazado." }[estado] ?? "Trámite actualizado.";
  volver(`/tramites/${id}`, error?.message ?? null, ok);
}
