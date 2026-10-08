"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/ausencias";

export async function revisarAusencia(formData: FormData) {
  const justificada = formData.get("decision") === "justificar";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("revisar_ausencia", {
    p_id: Number(formData.get("id")),
    p_justificada: justificada,
    p_observaciones: String(formData.get("observaciones") ?? ""),
  });
  revalidatePath(PAGINA);
  const ok = justificada ? "Ausencia justificada." : "Ausencia marcada como no justificada.";
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error.message)}` : `ok=${encodeURIComponent(ok)}`}`);
}
