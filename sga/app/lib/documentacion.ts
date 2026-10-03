export const BUCKET_DOCUMENTACION = "documentacion";
// Vercel acepta hasta 4,5 MB por pedido al servidor; el bucket admite 5 MB.
export const TAMANIO_MAXIMO = 4 * 1024 * 1024;
export const TIPOS_PERMITIDOS: Record<string, string> = {
  "application/pdf": "PDF",
  "image/png": "PNG",
  "image/jpeg": "JPG",
};

export const estadosDocumento: Record<string, string> = {
  NO_CARGADO: "No cargado",
  CARGADO: "Pendiente de validación",
  VALIDADO: "Validado",
  RECHAZADO: "Rechazado",
};

// Nombre seguro para la ruta en Storage (sin espacios ni acentos).
export function nombreSeguro(nombre: string): string {
  const limpio = nombre
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-zA-Z0-9._-]+/g, "_")
    .slice(-80);
  return limpio || "archivo";
}
