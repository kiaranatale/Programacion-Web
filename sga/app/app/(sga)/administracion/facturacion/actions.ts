"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/facturacion";

// Nuevo valor del crédito desde una fecha. Las facturas de los meses que
// empiecen desde esa fecha lo usan solas.
export async function cambiarValorCredito(formData: FormData) {
  const monto = Number(formData.get("monto"));
  const desde = String(formData.get("desde") ?? "");
  let error: string | null = null;
  if (!(monto > 0)) error = "Indicá un valor mayor que cero.";
  else if (!/^\d{4}-\d{2}-01$/.test(desde)) error = "El valor rige desde el primer día de un mes.";
  else {
    const supabase = await createClient();
    const { error: e } = await supabase.schema("sga").from("valor_credito").upsert({ vigente_desde: desde, monto }, { onConflict: "vigente_desde" });
    error = e?.message ?? null;
  }
  revalidatePath(PAGINA);
  redirect(`${PAGINA}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent("Valor del crédito guardado.")}`}`);
}
