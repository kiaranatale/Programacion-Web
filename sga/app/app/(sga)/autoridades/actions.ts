"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { hoy } from "@/lib/hoy";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/autoridades";

// Las políticas de catálogo solo dejan escribir a Administración.
function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function designarAutoridad(formData: FormData) {
  const cargoId = Number(formData.get("cargo_id")) || null;
  const cargoNuevo = String(formData.get("cargo_nuevo") ?? "").trim();
  const mail = String(formData.get("mail") ?? "").trim();
  const escuelaId = Number(formData.get("escuela_id")) || null;
  const desde = String(formData.get("desde") ?? "") || hoy();

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data: persona } = await sga.from("persona").select("id").ilike("mail_institucional", mail).maybeSingle<{ id: number }>();
  if (!persona) volver(`No hay ninguna persona con el mail ${mail}.`, "");

  let cargo = cargoId;
  if (cargoNuevo) {
    const { data, error } = await sga.from("cargo_institucional").upsert({ nombre: cargoNuevo }, { onConflict: "nombre" }).select("id").single<{ id: number }>();
    if (error || !data) volver("No se pudo crear el cargo.", "");
    cargo = data.id;
  }
  if (!cargo) volver("Elegí un cargo o escribí uno nuevo.", "");

  const { error } = await sga.from("autoridad").insert({ persona_id: persona.id, cargo_institucional_id: cargo, escuela_id: escuelaId, fecha_desde: desde });
  volver(error ? "No se pudo designar la autoridad." : null, "Autoridad designada.");
}

// Termina el mandato: queda vigente hasta ayer (o se borra si empezaba hoy).
export async function darDeBaja(formData: FormData) {
  const id = Number(formData.get("id"));
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data: autoridad } = await sga.from("autoridad").select("fecha_desde").eq("id", id).maybeSingle<{ fecha_desde: string }>();
  if (!autoridad) volver("No se encontró la autoridad.", "");

  const ayer = new Date(`${hoy()}T12:00:00Z`);
  ayer.setUTCDate(ayer.getUTCDate() - 1);
  const hasta = ayer.toISOString().slice(0, 10);
  const { error } = autoridad.fecha_desde > hasta
    ? await sga.from("autoridad").delete().eq("id", id)
    : await sga.from("autoridad").update({ fecha_hasta: hasta }).eq("id", id);
  volver(error ? "No se pudo dar de baja." : null, "Autoridad dada de baja.");
}
