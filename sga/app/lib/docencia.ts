export type MiComision = {
  comision_id: number;
  curso_id: number;
  codigo: string;
  materia: string;
  comision: string;
  anio: number;
  periodo: string;
  activo: boolean;
  cargo: string | null;
  responsable: boolean;
  inscriptos: number;
  sin_nota: number;
};

export type MesaDeFinal = {
  examen_final_id: number;
  curso_id: number;
  codigo: string;
  materia: string;
  fecha: string;
  hora_inicio: string;
  inscriptos: number;
  sin_nota: number;
};

export const estadosCursada: Record<string, string> = {
  CURSANDO: "Cursando",
  CURSADA_APROBADA: "Cursada aprobada",
  APROBADA: "Aprobada",
  DESAPROBADA: "Desaprobada",
  ABANDONADA: "Abandonó",
};

// Lee una nota del formulario: vacío = sin nota; acepta coma decimal.
export function leerNota(valor: FormDataEntryValue | null): number | null | "invalida" {
  const texto = String(valor ?? "").trim().replace(",", ".");
  if (!texto) return null;
  const nota = Number(texto);
  return Number.isFinite(nota) && nota >= 0 && nota <= 10 ? nota : "invalida";
}
