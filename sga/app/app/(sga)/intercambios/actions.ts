"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function volver(error: string | null, ok: string): never {
  revalidatePath("/intercambios");
  redirect(`/intercambios?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function postularme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("postular_intercambio", {
    p_convocatoria_id: Number(formData.get("convocatoria_id")),
    p_motivacion: String(formData.get("motivacion") ?? ""),
  });
  volver(error?.message ?? null, "Postulación enviada. El resultado se publica cuando cierra la convocatoria.");
}

export async function retirarme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("retirar_postulacion_intercambio", { p_postulacion_id: Number(formData.get("postulacion_id")) });
  volver(error?.message ?? null, "Te retiraste de la convocatoria.");
}
