export const ROLES = ["ALUMNO", "DOCENTE", "AYUDANTE", "ADMINISTRATIVO"] as const;

const etiquetas: Record<string, string> = {
  ALUMNO: "Alumno",
  DOCENTE: "Docente",
  AYUDANTE: "Ayudante",
  ADMINISTRATIVO: "Administrativo",
};

export const etiquetaRol = (rol: string) => etiquetas[rol] ?? rol;

export const TIPOS_DOCUMENTO: Record<string, string> = {
  DNI: "DNI",
  PASAPORTE: "Pasaporte",
  CEDULA_DE_IDENTIDAD: "Cédula de identidad",
  LIBRETA_CIVICA: "Libreta cívica",
  LIBRETA_DE_ENROLAMIENTO: "Libreta de enrolamiento",
  OTRO: "Otro",
};
