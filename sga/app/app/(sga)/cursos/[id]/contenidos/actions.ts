"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// La función de la base verifica que quien llama sea el responsable del
// curso (o Administración); acá solo se traduce el resultado.
export async function guardarContenidos(formData: FormData) {
  const cursoId = Number(formData.get("curso_id"));
  const contenidos = String(formData.get("contenidos") ?? "");
  const pagina = `/cursos/${cursoId}/contenidos`;

  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("actualizar_contenidos_minimos", {
    p_curso_id: cursoId,
    p_contenidos: contenidos,
  });

  revalidatePath(`/cursos/${cursoId}`, "layout");
  if (error) redirect(`${pagina}?editar=1&error=${encodeURIComponent(error.message)}`);
  redirect(`${pagina}?ok=${encodeURIComponent("Contenidos mínimos actualizados.")}`);
}
