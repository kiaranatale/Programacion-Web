"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const LISTA = "/administracion/oferta";

function volver(pagina: string, error: string | null, ok: string): never {
  revalidatePath(LISTA);
  revalidatePath(pagina);
  revalidatePath("/cursos");
  redirect(`${pagina}${pagina.includes("?") ? "&" : "?"}${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

const curso = (formData: FormData) => `${LISTA}/${Number(formData.get("curso_id"))}`;

export async function crearCurso(formData: FormData) {
  const [anio, periodo = ""] = String(formData.get("cuatrimestre") ?? "").split("|");
  const codigo = String(formData.get("codigo") ?? "").trim();
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("crear_curso", {
    p_codigo: codigo,
    p_anio: Number(anio) || 0,
    p_periodo: periodo,
    p_desde: String(formData.get("desde") ?? "") || null,
    p_hasta: String(formData.get("hasta") ?? "") || null,
  });
  if (error || typeof data !== "number") volver(`${LISTA}?cuatrimestre=${anio}|${periodo}`, error?.message ?? "No se pudo crear el curso.", "");
  volver(`${LISTA}/${data}`, null, `Curso de ${codigo} creado. Agregale comisiones y horarios.`);
}

export async function borrarCurso(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("borrar_curso", { p_curso_id: Number(formData.get("curso_id")) });
  if (error) volver(curso(formData), error.message, "");
  volver(LISTA, null, "Curso borrado.");
}

export async function crearComision(formData: FormData) {
  const cupo = String(formData.get("cupo") ?? "").trim();
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("crear_comision", {
    p_curso_id: Number(formData.get("curso_id")),
    p_nombre: String(formData.get("nombre") ?? ""),
    p_cupo: cupo ? Number(cupo) : null,
  });
  volver(curso(formData), error?.message ?? null, "Comisión creada.");
}

export async function cambiarCupo(formData: FormData) {
  const cupo = String(formData.get("cupo") ?? "").trim();
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("cambiar_cupo_comision", {
    p_comision_id: Number(formData.get("comision_id")),
    p_cupo: cupo ? Number(cupo) : null,
  });
  volver(curso(formData), error?.message ?? null, "Cupo actualizado.");
}

export async function borrarComision(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("borrar_comision", { p_comision_id: Number(formData.get("comision_id")) });
  volver(curso(formData), error?.message ?? null, "Comisión borrada.");
}

export async function agregarHorario(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("agregar_horario", {
    p_comision_id: Number(formData.get("comision_id")),
    p_dia: String(formData.get("dia") ?? ""),
    p_desde: String(formData.get("desde") ?? "") || null,
    p_hasta: String(formData.get("hasta") ?? "") || null,
    p_modalidad: String(formData.get("modalidad") ?? "PRESENCIAL"),
    p_edificio_id: Number(formData.get("edificio_id")) || null,
    p_aula: String(formData.get("aula") ?? ""),
  });
  volver(curso(formData), error?.message ?? null, "Horario agregado.");
}

export async function borrarHorario(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("borrar_horario", { p_horario_id: Number(formData.get("horario_id")) });
  volver(curso(formData), error?.message ?? null, "Horario borrado.");
}
