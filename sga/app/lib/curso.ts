import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { HorarioRow } from "@/lib/cursos";

export type CursoDetalle = {
  id: number;
  anio: number;
  periodo: string;
  fecha_inicio: string;
  fecha_fin: string;
  activo: boolean;
  materia: {
    id: number;
    codigo: string;
    nombre: string;
    creditos: number | null;
    contenidos_minimos: string | null;
    departamento: { nombre: string } | null;
  } | null;
  comision: { id: number; nombre: string; cupo: number | null; horario_comision: HorarioRow[] }[];
};

// Curso con su materia y comisiones; lo comparten el layout y las solapas.
export const getCurso = cache(async (id: number): Promise<CursoDetalle | null> => {
  if (!Number.isInteger(id)) return null;
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("curso")
    .select(`id, anio, periodo, fecha_inicio, fecha_fin, activo,
      materia:materia_id(id, codigo, nombre, creditos, contenidos_minimos, departamento:departamento_id(nombre)),
      comision(id, nombre, cupo, horario_comision(dia_semana, hora_inicio, hora_fin, modalidad,
        aula:aula_id(codigo, edificio:edificio_id(nombre))))`)
    .eq("id", id)
    .maybeSingle<CursoDetalle>();
  return data?.materia ? data : null;
});
