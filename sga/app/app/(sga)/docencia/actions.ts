"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { leerNota } from "@/lib/docencia";
import { createClient } from "@/lib/supabase/server";

// Guarda solo las notas que cambiaron. Las funciones de la base validan
// que el docente dicte la comisión y las reglas de cada nota.
function resultado(pagina: string, guardadas: number, errores: string[]): never {
  revalidatePath(pagina);
  const p = new URLSearchParams();
  if (guardadas) p.set("ok", guardadas === 1 ? "Se guardó 1 nota." : `Se guardaron ${guardadas} notas.`);
  if (errores.length) p.set("error", errores.join(" · "));
  if (!guardadas && !errores.length) p.set("ok", "No había cambios para guardar.");
  redirect(`${pagina}?${p}`);
}

export async function guardarNotasCursada(formData: FormData) {
  const comisionId = Number(formData.get("comision_id"));
  const pagina = `/docencia/comisiones/${comisionId}`;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  let guardadas = 0;
  const errores: string[] = [];

  for (const [clave, valor] of formData.entries()) {
    const m = clave.match(/^n_(\d+)$/);
    if (!m) continue;
    const nombre = String(formData.get(`a_${m[1]}`) ?? "");
    const nota = leerNota(valor);
    const original = leerNota(formData.get(`o_${m[1]}`));
    if (nota === original) continue;
    if (nota === "invalida") { errores.push(`${nombre}: la nota tiene que ser un número de 0 a 10`); continue; }
    const { error } = await sga.rpc("cargar_nota_cursada", { p_inscripcion_id: Number(m[1]), p_nota: nota });
    if (error) errores.push(`${nombre}: ${error.message}`);
    else guardadas++;
  }
  resultado(pagina, guardadas, errores);
}

export async function guardarNotasFinal(formData: FormData) {
  const mesaId = Number(formData.get("examen_final_id"));
  const pagina = `/docencia/finales/${mesaId}`;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  let guardadas = 0;
  const errores: string[] = [];

  for (const [clave, valor] of formData.entries()) {
    const m = clave.match(/^n_(\d+)$/);
    if (!m) continue;
    const nombre = String(formData.get(`a_${m[1]}`) ?? "");
    const ausente = formData.get(`x_${m[1]}`) === "1";
    const nota = leerNota(valor);
    if (nota === null && !ausente) continue;
    if (nota === "invalida" && !ausente) { errores.push(`${nombre}: la nota tiene que ser un número de 0 a 10`); continue; }
    const { error } = await sga.rpc("cargar_nota_final", {
      p_inscripcion_examen_final_id: Number(m[1]),
      p_nota: ausente || nota === "invalida" ? null : nota,
      p_ausente: ausente,
    });
    if (error) errores.push(`${nombre}: ${error.message}`);
    else guardadas++;
  }
  resultado(pagina, guardadas, errores);
}
