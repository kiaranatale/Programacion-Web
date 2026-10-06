"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function volver(pagina: string, error: string | null, ok: string): never {
  revalidatePath("/administracion/intercambios");
  revalidatePath(pagina);
  redirect(`${pagina}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

const LISTA = "/administracion/intercambios";

export async function crearConvocatoria(formData: FormData) {
  const texto = (c: string) => String(formData.get(c) ?? "").trim();
  const [anio, periodo = ""] = texto("cuatrimestre").split("|");
  const datos = {
    universidad: texto("universidad"),
    pais: texto("pais"),
    ciudad: texto("ciudad") || null,
    anio: Number(anio),
    periodo,
    vacantes: Number(texto("vacantes")),
    creditos_minimos: Number(texto("creditos_minimos") || 0),
    promedio_minimo: texto("promedio_minimo") ? Number(texto("promedio_minimo")) : null,
    descripcion: texto("descripcion") || null,
    postulacion_desde: texto("desde"),
    postulacion_hasta: texto("hasta"),
  };
  if (!datos.universidad || !datos.pais || !datos.anio || !datos.periodo || !datos.postulacion_desde || !datos.postulacion_hasta) {
    volver(LISTA, "Completá universidad, país, cuatrimestre y fechas.", "");
  }
  if (!(datos.vacantes > 0)) volver(LISTA, "Indicá cuántas vacantes hay.", "");
  if (datos.postulacion_hasta < datos.postulacion_desde) volver(LISTA, "El cierre no puede ser anterior a la apertura.", "");
  if (datos.promedio_minimo !== null && !(datos.promedio_minimo >= 0 && datos.promedio_minimo <= 10)) volver(LISTA, "El promedio va de 0 a 10.", "");
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("convocatoria_intercambio").insert(datos);
  volver(LISTA, error?.message ?? null, "Convocatoria publicada.");
}

export async function borrarConvocatoria(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").from("convocatoria_intercambio").delete().eq("id", Number(formData.get("id")));
  volver(LISTA, error?.message ?? null, "Convocatoria borrada.");
}

export async function marcarPostulacion(formData: FormData) {
  const pagina = `${LISTA}/${Number(formData.get("convocatoria_id"))}`;
  const seleccionada = formData.get("seleccionada") === "true";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("marcar_postulacion_intercambio", {
    p_postulacion_id: Number(formData.get("postulacion_id")),
    p_seleccionada: seleccionada,
  });
  volver(pagina, error?.message ?? null, seleccionada ? "Postulante seleccionado." : "Postulante marcado como no seleccionado.");
}

export async function publicarResultados(formData: FormData) {
  const id = Number(formData.get("convocatoria_id"));
  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("publicar_resultados_intercambio", { p_convocatoria_id: id });
  volver(`${LISTA}/${id}`, error?.message ?? null, `Resultados publicados: ${data ?? 0} seleccionados. Los postulantes fueron notificados.`);
}
