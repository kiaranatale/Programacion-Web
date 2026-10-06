"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/legajo/proyectos";

function volver(error: string | null, ok: string, editar?: number): never {
  revalidatePath(PAGINA);
  const params = new URLSearchParams(error ? { error } : { ok });
  if (error && editar) params.set("editar", String(editar));
  redirect(`${PAGINA}?${params}${error ? "#formulario" : ""}`);
}

function campos(formData: FormData) {
  const texto = (campo: string) => String(formData.get(campo) ?? "").trim();
  return {
    p_tipo: texto("tipo"),
    p_titulo: texto("titulo"),
    p_materia_id: Number(texto("materia_id")) || null,
    p_responsable: texto("responsable"),
    p_descripcion: texto("descripcion"),
    p_desde: texto("desde") || null,
    p_hasta: texto("hasta") || null,
  };
}

// Alta o edición (con id) de un proyecto propio. La base valida los datos
// y que no esté validado.
export async function guardarProyecto(formData: FormData) {
  const id = Number(formData.get("id")) || undefined;
  const datos = campos(formData);
  if (datos.p_titulo.length > 200) volver("El título puede tener hasta 200 caracteres.", "", id);
  if (datos.p_descripcion.length > 2000) volver("La descripción puede tener hasta 2000 caracteres.", "", id);
  const supabase = await createClient();
  const { error } = id
    ? await supabase.schema("sga").rpc("editar_proyecto", { p_id: id, ...datos })
    : await supabase.schema("sga").rpc("cargar_proyecto", datos);
  volver(error?.message ?? null, id ? "Proyecto actualizado: queda pendiente de validación." : "Proyecto cargado: queda pendiente de validación.", id);
}

export async function borrarProyecto(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("borrar_proyecto", { p_id: Number(formData.get("id")) });
  volver(error?.message ?? null, "Proyecto borrado.");
}
