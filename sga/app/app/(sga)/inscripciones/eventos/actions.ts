"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function volver(error: string | null, ok: string): never {
  revalidatePath("/inscripciones/eventos");
  redirect(`/inscripciones/eventos?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function anotarme(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("inscribirse_evento", { p_evento_id: Number(formData.get("evento_id")) });
  volver(error?.message ?? null, `Te anotaste a ${formData.get("nombre")}.`);
}

export async function darmeDeBaja(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("desinscribirse_evento", { p_evento_id: Number(formData.get("evento_id")) });
  volver(error?.message ?? null, `Te diste de baja de ${formData.get("nombre")}.`);
}
