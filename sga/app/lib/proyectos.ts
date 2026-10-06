export type TipoProyecto = "AYUDANTIA" | "INVESTIGACION" | "EXTENSION" | "PROYECTO" | "OTRO";
export type EstadoProyecto = "PENDIENTE" | "VALIDADO" | "RECHAZADO";

export const tiposProyecto: Record<TipoProyecto, string> = {
  AYUDANTIA: "Ayudantía",
  INVESTIGACION: "Investigación",
  EXTENSION: "Extensión / voluntariado",
  PROYECTO: "Proyecto institucional",
  OTRO: "Otro",
};

export const estadosProyecto: Record<EstadoProyecto, { texto: string; clase: string }> = {
  PENDIENTE: { texto: "Pendiente de validación", clase: "sga-estado-cargado" },
  VALIDADO: { texto: "Validado ✓", clase: "sga-estado-validado" },
  RECHAZADO: { texto: "Rechazado", clase: "sga-estado-rechazado" },
};

const mes = (valor: string) =>
  new Date(`${valor}T12:00:00Z`).toLocaleDateString("es-AR", { timeZone: "UTC", month: "short", year: "numeric" });

// "mar 2025 – actualidad", o un solo mes si empieza y termina en el mismo
export function periodoProyecto(desde: string, hasta: string | null): string {
  if (hasta && mes(hasta) === mes(desde)) return mes(desde);
  return `${mes(desde)} – ${hasta ? mes(hasta) : "actualidad"}`;
}
