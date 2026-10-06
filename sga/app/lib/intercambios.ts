export type ResultadoIntercambio = "PENDIENTE" | "SELECCIONADA" | "NO_SELECCIONADA";

export const resultadosIntercambio: Record<ResultadoIntercambio, { texto: string; clase: string }> = {
  PENDIENTE: { texto: "Postulación enviada", clase: "sga-estado-programada" },
  SELECCIONADA: { texto: "Seleccionado/a ✓", clase: "sga-estado-activa" },
  NO_SELECCIONADA: { texto: "No seleccionado/a", clase: "sga-estado-finalizada" },
};

export type Convocatoria = {
  id: number;
  universidad: string;
  pais: string;
  ciudad: string | null;
  anio: number;
  periodo: string;
  vacantes: number;
  creditos_minimos: number;
  promedio_minimo: number | null;
  descripcion: string | null;
  postulacion_desde: string;
  postulacion_hasta: string;
  resultados_publicados: boolean;
};

export function requisitos(c: Pick<Convocatoria, "creditos_minimos" | "promedio_minimo">): string {
  const r = [];
  if (c.creditos_minimos > 0) r.push(`${c.creditos_minimos} créditos aprobados`);
  if (c.promedio_minimo !== null) r.push(`promedio ${c.promedio_minimo}`);
  return r.length ? r.join(" y ") : "Sin requisitos mínimos";
}
