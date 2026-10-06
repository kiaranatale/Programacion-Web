"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/eventos";

// Las políticas de catálogo solo dejan escribir a Administración.
function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  revalidatePath("/inscripciones/eventos");
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function crearEvento(formData: FormData) {
  const campo = (k: string) => String(formData.get(k) ?? "").trim();
  const nombre = campo("nombre");
  const fecha = campo("fecha");
  const desde = campo("hora_inicio");
  const hasta = campo("hora_fin");
  if (!nombre || !fecha || !desde || !hasta) volver("Completá el nombre, la fecha y el horario.", "");
  if (hasta <= desde) volver("La hora de fin tiene que ser posterior a la de inicio.", "");
  const cupo = campo("cupo") ? Number(campo("cupo")) : null;
  if (cupo !== null && (!Number.isInteger(cupo) || cupo <= 0)) volver("El cupo tiene que ser un número entero positivo.", "");

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  let aulaId: number | null = null;
  if (campo("aula")) {
    const { data } = await sga.from("aula").select("id").eq("codigo", campo("aula")).limit(1).maybeSingle<{ id: number }>();
    if (!data) volver(`No existe el aula ${campo("aula")}.`, "");
    aulaId = data.id;
  }
  const cierre = campo("cierre_fecha")
    ? new Date(`${campo("cierre_fecha")}T${campo("cierre_hora") || "23:59"}:00-03:00`).toISOString()
    : null;
  const { error } = await sga.from("evento_academico").insert({
    nombre, tipo: campo("tipo") || null, descripcion: campo("descripcion") || null, fecha, hora_inicio: desde, hora_fin: hasta,
    aula_id: aulaId, cupo, con_inscripcion: formData.get("con_inscripcion") === "1", inscripcion_hasta: cierre,
  });
  volver(error?.message ?? null, `Evento ${nombre} creado.`);
}

export async function cambiarInscripcion(formData: FormData) {
  const supabase = await createClient();
  const abrir = formData.get("abrir") === "1";
  const { error } = await supabase.schema("sga").from("evento_academico").update({ con_inscripcion: abrir }).eq("id", Number(formData.get("id")));
  volver(error?.message ?? null, abrir ? "Inscripción habilitada." : "Inscripción deshabilitada (los ya anotados se conservan).");
}

export async function borrarEvento(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("evento_academico").delete().eq("id", Number(formData.get("id")));
  volver(error?.message ?? null, "Evento borrado.");
}
