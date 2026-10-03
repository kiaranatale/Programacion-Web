export type EncuestaParaMi = {
  id: number;
  nombre: string;
  tipo: string;
  sobre: string | null;
  fecha_inicio: string;
  fecha_fin: string;
  estado: string;
  respondida: boolean;
};

export type EncuestaResumen = Omit<EncuestaParaMi, "respondida"> & { respuestas: number; destinatarios: number };

export const estados: Record<string, string> = { PROGRAMADA: "Programada", ACTIVA: "Activa", FINALIZADA: "Finalizada" };
export const tiposEncuesta: Record<string, string> = { ALUMNOS: "General", DESEMPENO_DOCENTE: "Desempeño docente" };
export const escala = ["Muy en desacuerdo", "En desacuerdo", "Neutral", "De acuerdo", "Muy de acuerdo"];
