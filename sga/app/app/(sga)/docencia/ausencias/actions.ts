"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/docencia/ausencias";

function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function informarAusencia(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("informar_ausencia", {
    p_tipo: String(formData.get("tipo") ?? ""),
    p_desde: String(formData.get("desde") ?? "") || null,
    p_hasta: String(formData.get("hasta") ?? "") || null,
    p_motivo: String(formData.get("motivo") ?? ""),
    p_comisiones: formData.getAll("comision").map(Number).filter(Boolean),
  });
  volver(error?.message ?? null, "Ausencia informada. Les avisamos a los alumnos de esas comisiones.");
}

export async function cancelarAusencia(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("cancelar_ausencia", { p_id: Number(formData.get("id")) });
  volver(error?.message ?? null, "Ausencia cancelada. Les avisamos a los alumnos que hay clase.");
}
