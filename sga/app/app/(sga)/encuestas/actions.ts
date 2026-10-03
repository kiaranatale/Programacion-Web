"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Las funciones de la base validan quién puede hacer cada cosa.

const volver = (url: string, clave: "ok" | "error", mensaje: string): never =>
  redirect(`${url}${url.includes("?") ? "&" : "?"}${clave}=${encodeURIComponent(mensaje)}`);

// Los campos e_<id> son preguntas de escala y t_<id> de texto.
export async function responderEncuesta(formData: FormData) {
  const id = Number(formData.get("encuesta_id"));
  const respuestas: Record<string, number | string> = {};
  for (const [clave, valor] of formData.entries()) {
    const m = clave.match(/^([et])_(\d+)$/);
    if (!m || typeof valor !== "string") continue;
    if (m[1] === "e") respuestas[m[2]] = Number(valor);
    else if (valor.trim()) respuestas[m[2]] = valor.trim();
  }

  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("responder_encuesta", { p_encuesta_id: id, p_respuestas: respuestas });
  if (error) volver(`/encuestas/${id}`, "error", error.message);
  revalidatePath("/encuestas");
  volver("/encuestas", "ok", "¡Gracias! Tu respuesta se guardó de forma anónima.");
}

export async function generarEncuestasDesempeno(formData: FormData) {
  const nombre = String(formData.get("nombre") ?? "").trim();
  const desde = String(formData.get("desde") ?? "");
  const hasta = String(formData.get("hasta") ?? "");
  if (!nombre || !desde || !hasta) volver("/encuestas", "error", "Completá el nombre y las fechas.");
  if (hasta < desde) volver("/encuestas", "error", "La fecha de fin no puede ser anterior a la de inicio.");

  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("crear_encuestas_desempeno", { p_nombre: nombre, p_inicio: desde, p_fin: hasta });
  if (error) volver("/encuestas", "error", error.message);
  revalidatePath("/encuestas");
  volver("/encuestas", "ok", data === 0
    ? "No se creó ninguna: todas las comisiones activas ya tienen una encuesta con ese nombre."
    : `Se crearon ${data} encuestas de desempeño docente.`);
}

export async function finalizarEncuesta(formData: FormData) {
  const id = Number(formData.get("id"));
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("finalizar_encuesta", { p_encuesta_id: id });
  if (error) volver("/encuestas", "error", error.message);
  revalidatePath("/encuestas");
  volver("/encuestas", "ok", "Encuesta cerrada.");
}

export type EstadoNueva = { error: string | null; valores: Record<string, string> };

// Con useActionState: ante un error conserva lo escrito.
export async function crearEncuesta(_previo: EstadoNueva, formData: FormData): Promise<EstadoNueva> {
  const valores = Object.fromEntries([...formData.entries()].filter(([k]) => !k.startsWith("$")).map(([k, v]) => [k, String(v)]));
  const fallo = (error: string): EstadoNueva => ({ error, valores });
  const nombre = (valores.nombre ?? "").trim();
  if (!nombre || !valores.desde || !valores.hasta) return fallo("Completá el nombre y las fechas.");
  if (valores.hasta < valores.desde) return fallo("La fecha de fin no puede ser anterior a la de inicio.");

  const preguntas = Object.keys(valores)
    .filter((k) => /^texto_\d+$/.test(k) && valores[k].trim())
    .sort((a, b) => Number(a.split("_")[1]) - Number(b.split("_")[1]))
    .map((k) => ({ texto: valores[k].trim().slice(0, 300), tipo: valores[`tipo_${k.split("_")[1]}`] === "TEXTO" ? "TEXTO" : "ESCALA" }));
  if (preguntas.length === 0) return fallo("Escribí al menos una pregunta.");

  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("crear_encuesta", {
    p_nombre: nombre,
    p_descripcion: valores.descripcion ?? "",
    p_inicio: valores.desde,
    p_fin: valores.hasta,
    p_preguntas: preguntas,
  });
  if (error) return fallo(error.message);
  revalidatePath("/encuestas");
  redirect(`/encuestas?ok=${encodeURIComponent("Encuesta creada.")}`);
}
