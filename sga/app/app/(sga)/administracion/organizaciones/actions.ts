"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/organizaciones";

// Las políticas de la base solo dejan a Administración tocar
// organizaciones y miembros; acá se traduce el resultado.
function volver(error: { message: string } | null, ok: string): never {
  revalidatePath(PAGINA);
  revalidatePath("/hoy");
  if (error) redirect(`${PAGINA}?error=${encodeURIComponent(error.message)}`);
  redirect(`${PAGINA}?ok=${encodeURIComponent(ok)}`);
}

export async function crearOrganizacion(formData: FormData) {
  const nombre = String(formData.get("nombre") ?? "").trim();
  const descripcion = String(formData.get("descripcion") ?? "").trim() || null;
  if (!nombre) redirect(`${PAGINA}?error=${encodeURIComponent("Escribí el nombre de la organización.")}`);
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("organizacion").insert({ nombre, descripcion });
  volver(error && { message: error.code === "23505" ? "Ya existe una organización con ese nombre." : error.message }, "Organización creada.");
}

export async function cambiarActiva(formData: FormData) {
  const id = Number(formData.get("id"));
  const activa = formData.get("activa") === "1";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("organizacion").update({ activa }).eq("id", id);
  volver(error, activa ? "Organización reactivada." : "Organización desactivada: sus miembros ya no pueden publicar.");
}

export async function agregarMiembro(formData: FormData) {
  const organizacionId = Number(formData.get("organizacion_id"));
  const mail = String(formData.get("mail") ?? "").trim().toLowerCase();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data: persona } = await sga.from("persona").select("id").ilike("mail_institucional", mail).maybeSingle<{ id: number }>();
  if (!persona) redirect(`${PAGINA}?error=${encodeURIComponent(`No hay ninguna persona con el mail ${mail}.`)}`);
  const { error } = await sga.from("organizacion_miembro").insert({ organizacion_id: organizacionId, persona_id: persona.id });
  volver(error && { message: error.code === "23505" ? "Esa persona ya es miembro." : error.message }, "Miembro agregado.");
}

export async function quitarMiembro(formData: FormData) {
  const organizacionId = Number(formData.get("organizacion_id"));
  const personaId = Number(formData.get("persona_id"));
  const supabase = await createClient();
  const { error } = await supabase
    .schema("sga")
    .from("organizacion_miembro")
    .delete()
    .eq("organizacion_id", organizacionId)
    .eq("persona_id", personaId);
  volver(error, "Miembro quitado.");
}
