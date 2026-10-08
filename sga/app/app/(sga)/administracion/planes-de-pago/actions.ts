"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/planes-de-pago";

export async function resolverPlan(formData: FormData) {
  const aprobar = formData.get("decision") === "aprobar";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("resolver_plan_pago", {
    p_id: Number(formData.get("id")),
    p_aprobar: aprobar,
    p_observaciones: String(formData.get("observaciones") ?? ""),
  });
  revalidatePath(PAGINA);
  const ok = aprobar ? "Plan aprobado: las cuotas ya figuran en el estado de cuenta del alumno." : "Pedido rechazado.";
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error.message)}` : `ok=${encodeURIComponent(ok)}`}`);
}
