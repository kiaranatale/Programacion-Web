"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/finales";

// Las políticas solo dejan escribir a Administración.
function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function crearTurno(formData: FormData) {
  const nombre = String(formData.get("nombre") ?? "").trim();
  const desde = String(formData.get("desde") ?? "");
  const hasta = String(formData.get("hasta") ?? "");
  if (!nombre || !desde || !hasta) volver("Completá el nombre y el período de inscripción.", "");
  if (hasta < desde) volver("El fin de la inscripción no puede ser anterior al inicio.", "");
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("turno_examen").insert({ nombre, inscripcion_desde: desde, inscripcion_hasta: hasta });
  volver(error ? (error.code === "23505" ? "Ya existe un turno con ese nombre." : error.message) : null, `Turno ${nombre} creado.`);
}

export async function agregarFecha(formData: FormData) {
  const turnoId = Number(formData.get("turno_id"));
  const codigo = String(formData.get("codigo") ?? "").trim();
  const fecha = String(formData.get("fecha") ?? "");
  const desde = String(formData.get("hora_inicio") ?? "");
  const hasta = String(formData.get("hora_fin") ?? "");
  const aula = String(formData.get("aula") ?? "").trim();
  if (!codigo || !fecha || !desde || !hasta) volver("Completá la materia, la fecha y el horario.", "");
  if (hasta <= desde) volver("La hora de fin tiene que ser posterior a la de inicio.", "");

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  // Curso de referencia: el más reciente de la materia
  const { data: curso } = await sga.from("curso").select("id, materia:materia_id!inner(codigo)")
    .eq("materia.codigo", codigo).order("fecha_inicio", { ascending: false }).limit(1).maybeSingle<{ id: number }>();
  if (!curso) volver(`No hay cursos de la materia ${codigo}.`, "");

  let aulaId: number | null = null;
  if (aula) {
    const { data } = await sga.from("aula").select("id").eq("codigo", aula).limit(1).maybeSingle<{ id: number }>();
    if (!data) volver(`No existe el aula ${aula}.`, "");
    aulaId = data.id;
  }
  const { error } = await sga.from("examen_final").insert({ curso_id: curso.id, turno_id: turnoId, fecha, hora_inicio: desde, hora_fin: hasta, aula_id: aulaId });
  volver(error?.message ?? null, `Fecha de ${codigo} agregada.`);
}

export async function borrarFecha(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("examen_final").delete().eq("id", Number(formData.get("id")));
  volver(error ? (error.code === "23503" ? "No se puede borrar: ya hay alumnos anotados a esa fecha." : error.message) : null, "Fecha borrada.");
}
