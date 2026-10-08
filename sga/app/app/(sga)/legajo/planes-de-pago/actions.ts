"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/legajo/planes-de-pago";

function volver(error: string | null, ok: string): never {
  revalidatePath(PAGINA);
  revalidatePath("/legajo/estado-de-cuenta");
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

export async function solicitarPlan(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("solicitar_plan_pago", {
    p_cuotas: Number(formData.get("cuotas")),
    p_motivo: String(formData.get("motivo") ?? ""),
  });
  volver(error?.message ?? null, "Pedido enviado. Administración te va a responder por acá y con una notificación.");
}

export async function cancelarPlan(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("cancelar_plan_pago", { p_id: Number(formData.get("id")) });
  volver(error?.message ?? null, "Pedido cancelado.");
}
