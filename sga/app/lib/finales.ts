export type FinalParaMi = {
  examen_final_id: number;
  turno: string;
  inscripcion_desde: string;
  inscripcion_hasta: string;
  codigo: string;
  materia: string;
  fecha: string;
  hora_inicio: string;
  aula: string | null;
  cierre: string;
  inscripcion_id: number | null;
  motivo: string | null;
};

// "Lunes 07/12/2026 · 09:00 hs"
export function diaYHora(fecha: string, hora: string): string {
  const d = new Date(`${fecha}T12:00:00Z`);
  const dia = d.toLocaleDateString("es-AR", { timeZone: "UTC", weekday: "long" });
  const corta = d.toLocaleDateString("es-AR", { timeZone: "UTC", day: "2-digit", month: "2-digit", year: "numeric" });
  return `${dia[0].toUpperCase()}${dia.slice(1)} ${corta} · ${hora.slice(0, 5)} hs`;
}
