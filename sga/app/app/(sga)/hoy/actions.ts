"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";

// Las políticas de la base deciden quién publica, edita, borra o
// comenta; acá se validan los campos y se traduce el resultado.

function texto(formData: FormData, campo: string): string {
  return String(formData.get(campo) ?? "").trim();
}

function camposPublicacion(formData: FormData) {
  const tipo = texto(formData, "tipo") === "EVENTO" ? "EVENTO" : "NOVEDAD";
  const evento = tipo === "EVENTO";
  return {
    tipo,
    titulo: texto(formData, "titulo"),
    cuerpo: texto(formData, "cuerpo"),
    fecha_evento: evento ? texto(formData, "fecha_evento") || null : null,
    hora_evento: evento ? texto(formData, "hora_evento") || null : null,
    lugar: evento ? texto(formData, "lugar") || null : null,
  };
}

function errorDeCampos(c: ReturnType<typeof camposPublicacion>): string | null {
  if (!c.titulo) return "Escribí un título.";
  if (c.titulo.length > 150) return "El título puede tener hasta 150 caracteres.";
  if (!c.cuerpo) return "Escribí el texto de la publicación.";
  if (c.cuerpo.length > 5000) return "El texto puede tener hasta 5000 caracteres.";
  if (c.tipo === "EVENTO" && !c.fecha_evento) return "Indicá la fecha del evento.";
  if (c.lugar && c.lugar.length > 150) return "El lugar puede tener hasta 150 caracteres.";
  return null;
}

const conError = (url: string, mensaje: string) => `${url}${url.includes("?") ? "&" : "?"}error=${encodeURIComponent(mensaje)}`;

export async function crearPublicacion(formData: FormData) {
  const sesion = await getSesion();
  const campos = camposPublicacion(formData);
  const organizacionId = Number(formData.get("organizacion_id"));
  const invalido = errorDeCampos(campos);
  if (invalido) redirect(conError("/hoy/nueva", invalido));
  if (!sesion?.persona) redirect(conError("/hoy/nueva", "Tu usuario no tiene una persona asociada."));

  const supabase = await createClient();
  const { data, error } = await supabase
    .schema("sga")
    .from("publicacion")
    .insert({ ...campos, organizacion_id: organizacionId, autor_persona_id: sesion.persona.id })
    .select("id")
    .single<{ id: number }>();

  if (error || !data) redirect(conError("/hoy/nueva", "No se pudo publicar. Revisá que seas miembro de la organización."));
  revalidatePath("/hoy");
  redirect(`/hoy/${data.id}?ok=${encodeURIComponent("Publicación creada.")}`);
}

export async function editarPublicacion(formData: FormData) {
  const id = Number(formData.get("id"));
  const campos = camposPublicacion(formData);
  const pagina = `/hoy/${id}/editar`;
  const invalido = errorDeCampos(campos);
  if (invalido) redirect(conError(pagina, invalido));

  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").from("publicacion").update(campos).eq("id", id).select("id");
  if (error || !data?.length) redirect(conError(pagina, "No se pudo guardar. Solo pueden editar los miembros de la organización."));
  revalidatePath("/hoy");
  redirect(`/hoy/${id}?ok=${encodeURIComponent("Publicación actualizada.")}`);
}

export async function borrarPublicacion(formData: FormData) {
  const id = Number(formData.get("id"));
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").from("publicacion").delete().eq("id", id).select("id");
  if (error || !data?.length) redirect(conError(`/hoy/${id}`, "No se pudo borrar la publicación."));
  revalidatePath("/hoy");
  redirect(`/hoy?ok=${encodeURIComponent("Publicación borrada.")}`);
}

export async function comentar(formData: FormData) {
  const sesion = await getSesion();
  const publicacionId = Number(formData.get("publicacion_id"));
  const cuerpo = texto(formData, "cuerpo");
  const pagina = `/hoy/${publicacionId}`;
  if (!cuerpo) redirect(conError(pagina, "Escribí un comentario."));
  if (cuerpo.length > 2000) redirect(conError(pagina, "El comentario puede tener hasta 2000 caracteres."));
  if (!sesion?.persona) redirect(conError(pagina, "Tu usuario no tiene una persona asociada."));

  const supabase = await createClient();
  const { error } = await supabase
    .schema("sga")
    .from("publicacion_comentario")
    .insert({ publicacion_id: publicacionId, autor_persona_id: sesion.persona.id, cuerpo });
  if (error) redirect(conError(pagina, "No se pudo enviar el comentario."));
  revalidatePath(pagina);
  redirect(`${pagina}#comentarios`);
}

export async function borrarComentario(formData: FormData) {
  const id = Number(formData.get("id"));
  const publicacionId = Number(formData.get("publicacion_id"));
  const pagina = `/hoy/${publicacionId}`;
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").from("publicacion_comentario").delete().eq("id", id).select("id");
  if (error || !data?.length) redirect(conError(pagina, "No se pudo borrar el comentario."));
  revalidatePath(pagina);
  redirect(`${pagina}#comentarios`);
}
