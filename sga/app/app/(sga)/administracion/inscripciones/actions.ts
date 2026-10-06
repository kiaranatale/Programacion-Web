"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/inscripciones";

function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

// Crea o actualiza el período de inscripción de un cuatrimestre.
export async function guardarPeriodo(formData: FormData) {
  const [anioTexto, periodo = ""] = String(formData.get("cuatrimestre") ?? "").split("|");
  const anio = Number(anioTexto);
  const desde = String(formData.get("desde") ?? "");
  const hasta = String(formData.get("hasta") ?? "");
  if (!anio || !periodo || !desde || !hasta) volver("Completá el cuatrimestre y las fechas.", "");
  if (hasta < desde) volver("El fin de la inscripción no puede ser anterior al inicio.", "");
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("periodo_inscripcion_cursada")
    .upsert({ anio, periodo, desde, hasta }, { onConflict: "anio,periodo" });
  volver(error?.message ?? null, "Período de inscripción guardado.");
}

export async function borrarPeriodo(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("periodo_inscripcion_cursada").delete().eq("id", Number(formData.get("id")));
  volver(error?.message ?? null, "Período de inscripción borrado.");
}
