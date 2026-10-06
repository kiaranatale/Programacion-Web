"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function volver(periodoId: number, error: string | null, ok: string): never {
  const pagina = `/administracion/inscripciones/${periodoId}`;
  revalidatePath(pagina);
  redirect(`${pagina}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

// Asigna todas las vacantes según las pautas (créditos, rendimiento, fecha).
export async function asignarAutomaticamente(formData: FormData) {
  const periodoId = Number(formData.get("periodo_id"));
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("asignar_vacantes_automaticamente", { p_periodo_id: periodoId });
  volver(periodoId, error?.message ?? null, `Vacantes asignadas: ${data ?? 0} solicitudes quedaron asignadas. Revisalas y confirmá.`);
}

// Cambia a mano una solicitud (asignada / no asignada).
export async function marcarSolicitud(formData: FormData) {
  const periodoId = Number(formData.get("periodo_id"));
  const asignada = formData.get("asignada") === "true";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("marcar_solicitud_cursada", {
    p_solicitud_id: Number(formData.get("solicitud_id")),
    p_asignada: asignada,
  });
  volver(periodoId, error?.message ?? null, asignada ? "Solicitud asignada." : "Solicitud marcada como no asignada.");
}

// Los asignados quedan inscriptos; ya no se puede cambiar la asignación.
export async function confirmarAsignacion(formData: FormData) {
  const periodoId = Number(formData.get("periodo_id"));
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("confirmar_asignacion_cursadas", { p_periodo_id: periodoId });
  volver(periodoId, error?.message ?? null, `Asignación confirmada: ${data ?? 0} alumnos quedaron inscriptos.`);
}
