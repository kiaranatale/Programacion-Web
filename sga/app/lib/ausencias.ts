export const tiposAusencia: Record<string, string> = {
  ENFERMEDAD: "Enfermedad",
  PERSONAL: "Razones personales",
  CONGRESO: "Congreso o jornada",
  CAPACITACION: "Capacitación",
  OTRO: "Otro",
};

export const estadosAusencia: Record<string, { texto: string; clase: string }> = {
  INFORMADA: { texto: "Informada", clase: "sga-estado-programada" },
  JUSTIFICADA: { texto: "Justificada", clase: "sga-estado-activa" },
  NO_JUSTIFICADA: { texto: "No justificada", clase: "sga-estado-rechazado-chip" },
  CANCELADA: { texto: "Cancelada", clase: "sga-estado-finalizada" },
};

export type Ausencia = {
  id: number;
  apellido: string;
  nombre: string;
  tipo: string;
  fecha_inicio: string;
  fecha_fin: string;
  motivo: string | null;
  estado: string;
  observaciones: string | null;
  fecha_carga: string;
  comisiones: string | null;
};
