import { createClient } from "@/lib/supabase/server";

export type Horario = { dia_semana: string; hora_inicio: string; hora_fin: string };
export type Cursada = {
  id: number;
  estado: "CURSANDO" | "CURSADA_APROBADA" | "APROBADA" | "DESAPROBADA" | "ABANDONADA";
  nota_cursada: number | null;
  nota_definitiva: number | null;
  comision: { nombre: string; horario_comision: Horario[] } | null;
  curso: {
    anio: number;
    periodo: string;
    materia: { id: number; codigo: string; nombre: string; creditos: number } | null;
  } | null;
  inscripcion_examen_final: {
    numero_intento: number;
    nota_final: number | null;
    ausente: boolean;
    examen_final: { fecha: string } | null;
  }[];
};

// Todas las cursadas del legajo con comisión, horarios y finales rendidos.
export async function getCursadas(legajoId: number): Promise<Cursada[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("inscripcion_curso")
    .select(`id, estado, nota_cursada, nota_definitiva,
      comision:comision_id(nombre, horario_comision(dia_semana, hora_inicio, hora_fin)),
      curso:curso_id(anio, periodo, materia:materia_id(id, codigo, nombre, creditos)),
      inscripcion_examen_final(numero_intento, nota_final, ausente, examen_final:examen_final_id(fecha))`)
    .eq("legajo_id", legajoId)
    .returns<Cursada[]>();

  return (data ?? []).map((c) => ({
    ...c,
    inscripcion_examen_final: [...c.inscripcion_examen_final].sort((a, b) => a.numero_intento - b.numero_intento),
  }));
}

// Orden cronológico de períodos: 2025-2C antes que 2026-1C.
export function clavePeriodo(c: Cursada): string {
  return `${c.curso?.anio ?? 0}-${c.curso?.periodo ?? ""}`;
}

// Resultado de un final para el legajo: nota, "Ausente" o "Anotado".
export function resultadoFinal(f: Cursada["inscripcion_examen_final"][number], nota: (n: number | null) => string): { texto: string; clase: string } {
  if (f.ausente) return { texto: "Ausente", clase: "sga-desaprobado" };
  if (f.nota_final === null) return { texto: "Anotado", clase: "sga-cursando" };
  return { texto: nota(f.nota_final), clase: f.nota_final >= 4 ? "sga-aprobado" : "sga-desaprobado" };
}
