export const estadosPlan: Record<string, { texto: string; clase: string }> = {
  SOLICITADO: { texto: "Esperando respuesta", clase: "sga-estado-programada" },
  APROBADO: { texto: "Aprobado", clase: "sga-estado-activa" },
  RECHAZADO: { texto: "Rechazado", clase: "sga-estado-rechazado-chip" },
  CANCELADO: { texto: "Cancelado", clase: "sga-estado-finalizada" },
};

export type Plan = {
  id: number;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  cuotas: number;
  monto_total: number;
  motivo: string | null;
  estado: string;
  observaciones: string | null;
  fecha_solicitud: string;
  facturas: string | null;
  cuotas_pagas: number;
};
