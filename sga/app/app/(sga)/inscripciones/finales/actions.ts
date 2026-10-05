"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/inscripciones/finales";

// La base valida turno, 48 h, cursada, correlativas y fecha única.
function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function anotarme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("inscribirse_final", { p_examen_final_id: Number(formData.get("examen_final_id")) });
  volver(error?.message ?? null, "Te anotaste al final.");
}

export async function darmeDeBaja(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("desinscribirse_final", { p_inscripcion_examen_final_id: Number(formData.get("inscripcion_id")) });
  volver(error?.message ?? null, "Te diste de baja del final.");
}
