"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getLegajoActual } from "@/lib/legajo";
import { BUCKET_DOCUMENTACION, TAMANIO_MAXIMO, TIPOS_PERMITIDOS, nombreSeguro } from "@/lib/documentacion";

const PAGINA = "/legajo/alumno/documentacion";

function volver(mensaje: string, tipo: "ok" | "error"): never {
  redirect(`${PAGINA}?${tipo}=${encodeURIComponent(mensaje)}`);
}

// Sube el archivo a la carpeta del legajo en Storage y lo registra como
// "Pendiente de validación". Si reemplaza a uno anterior, borra el viejo.
export async function subirDocumento(formData: FormData) {
  const documentoId = Number(formData.get("documento_id"));
  const archivo = formData.get("archivo");

  if (!Number.isInteger(documentoId)) volver("Documento inválido.", "error");
  if (!(archivo instanceof File) || archivo.size === 0) volver("Elegí un archivo antes de subirlo.", "error");
  if (archivo.size > TAMANIO_MAXIMO) volver("El archivo supera los 4 MB.", "error");
  if (!TIPOS_PERMITIDOS[archivo.type]) volver("Solo se aceptan archivos PDF, PNG o JPG.", "error");

  const { legajo } = await getLegajoActual();
  if (!legajo) volver("Tu usuario no tiene un legajo de alumno.", "error");

  const supabase = await createClient();
  const ruta = `${legajo.id}/${documentoId}/${Date.now()}-${nombreSeguro(archivo.name)}`;

  const { error: errorSubida } = await supabase.storage
    .from(BUCKET_DOCUMENTACION)
    .upload(ruta, archivo, { contentType: archivo.type, upsert: false });
  if (errorSubida) volver(`No se pudo subir el archivo: ${errorSubida.message}`, "error");

  const { data: anterior, error } = await supabase
    .schema("sga")
    .rpc("cargar_documento", {
      p_documento_requerido_id: documentoId,
      p_nombre_archivo: archivo.name,
      p_ruta_archivo: ruta,
    });

  if (error) {
    await supabase.storage.from(BUCKET_DOCUMENTACION).remove([ruta]);
    volver(error.message, "error");
  }
  if (typeof anterior === "string" && anterior) {
    await supabase.storage.from(BUCKET_DOCUMENTACION).remove([anterior]);
  }

  revalidatePath(PAGINA);
  volver(`"${archivo.name}" quedó pendiente de validación.`, "ok");
}

export async function eliminarDocumento(formData: FormData) {
  const documentoId = Number(formData.get("documento_id"));
  if (!Number.isInteger(documentoId)) volver("Documento inválido.", "error");

  const supabase = await createClient();
  const { data: ruta, error } = await supabase
    .schema("sga")
    .rpc("eliminar_documento", { p_documento_requerido_id: documentoId });
  if (error) volver(error.message, "error");

  if (typeof ruta === "string" && ruta) {
    await supabase.storage.from(BUCKET_DOCUMENTACION).remove([ruta]);
  }

  revalidatePath(PAGINA);
  volver("El documento se eliminó.", "ok");
}
