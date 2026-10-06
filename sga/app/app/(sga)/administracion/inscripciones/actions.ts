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
  const segundaDesde = String(formData.get("segunda_desde") ?? "") || null;
  const segundaHasta = String(formData.get("segunda_hasta") ?? "") || null;
  if (hasta < desde) volver("El fin de la inscripción no puede ser anterior al inicio.", "");
  if (!segundaDesde !== !segundaHasta) volver("Completá las dos fechas de la segunda inscripción (o ninguna).", "");
  if (segundaDesde && segundaHasta) {
    if (segundaDesde <= hasta) volver("La segunda inscripción tiene que empezar después de la primera.", "");
    if (segundaHasta < segundaDesde) volver("El fin de la segunda inscripción no puede ser anterior al inicio.", "");
  }
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("periodo_inscripcion_cursada")
    .upsert({ anio, periodo, desde, hasta, segunda_desde: segundaDesde, segunda_hasta: segundaHasta }, { onConflict: "anio,periodo" });
  volver(error?.message ?? null, "Período de inscripción guardado.");
}

export async function borrarPeriodo(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("periodo_inscripcion_cursada").delete().eq("id", Number(formData.get("id")));
  volver(error?.message ?? null, "Período de inscripción borrado.");
}
