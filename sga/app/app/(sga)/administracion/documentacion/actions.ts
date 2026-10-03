"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PAGINA = "/administracion/documentacion";

// La función de la base verifica que quien llama sea administrativo y que
// el documento siga pendiente; acá solo se traduce el resultado.
export async function revisarDocumento(formData: FormData) {
  const id = Number(formData.get("documento_legajo_id"));
  const aprobado = formData.get("decision") === "aprobar";
  const observaciones = String(formData.get("observaciones") ?? "").trim();

  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("revisar_documento", {
    p_documento_legajo_id: id,
    p_aprobado: aprobado,
    p_observaciones: observaciones || null,
  });

  revalidatePath(PAGINA);
  if (error) redirect(`${PAGINA}?error=${encodeURIComponent(error.message)}`);
  redirect(`${PAGINA}?ok=${encodeURIComponent(aprobado ? "Documento validado." : "Documento rechazado.")}`);
}
