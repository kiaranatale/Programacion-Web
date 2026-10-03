import { createClient } from "@/lib/supabase/server";
import type { Sesion } from "@/lib/sesion";

export type ComisionEnCurso = { nombre: string; horarios: string[] };
export type CursoEnProgreso = { id: number; codigo: string; nombre: string; comisiones: ComisionEnCurso[] };

export type HorarioRow = {
  dia_semana: string;
  hora_inicio: string;
  hora_fin: string;
  modalidad: string;
  aula: { codigo: string; edificio: { nombre: string } | null } | null;
};
type ComisionRow = {
  nombre: string;
  horario_comision: HorarioRow[];
  curso: { id: number; activo: boolean; materia: { codigo: string; nombre: string } | null } | null;
};

const COMISION_SELECT = `
  nombre,
  horario_comision(dia_semana, hora_inicio, hora_fin, modalidad,
    aula:aula_id(codigo, edificio:edificio_id(nombre))),
  curso:curso_id(id, activo, materia:materia_id(codigo, nombre))
`;

const dias: Record<string, string> = {
  LUNES: "Lunes", MARTES: "Martes", MIERCOLES: "Miércoles", JUEVES: "Jueves",
  VIERNES: "Viernes", SABADO: "Sábado", DOMINGO: "Domingo",
};
const modalidades: Record<string, string> = {
  PRESENCIAL: "Presencial",
  VIRTUAL_SINCRONICO: "Virtual sincrónica",
  VIRTUAL_ASINCRONICO: "Virtual asincrónica",
};
const ordenDias = Object.keys(dias);

// "Lunes (09:00 - 12:00) - Aula 304 → Sede Distrito Financiero: Presencial"
export function formatearHorario(h: HorarioRow): string {
  const dia = dias[h.dia_semana] ?? h.dia_semana;
  const rango = `${h.hora_inicio.slice(0, 5)} - ${h.hora_fin.slice(0, 5)}`;
  const lugar = h.aula ? ` - Aula ${h.aula.codigo} → ${h.aula.edificio?.nombre ?? "Sin edificio"}` : "";
  return `${dia} (${rango})${lugar}: ${modalidades[h.modalidad] ?? h.modalidad}`;
}

function agrupar(comisiones: ComisionRow[]): CursoEnProgreso[] {
  const cursos = new Map<number, CursoEnProgreso>();
  for (const c of comisiones) {
    if (!c.curso?.materia || !c.curso.activo) continue;
    const curso = cursos.get(c.curso.id) ?? {
      id: c.curso.id,
      codigo: c.curso.materia.codigo,
      nombre: c.curso.materia.nombre,
      comisiones: [],
    };
    const horarios = [...c.horario_comision]
      .sort((a, b) => ordenDias.indexOf(a.dia_semana) - ordenDias.indexOf(b.dia_semana))
      .map(formatearHorario);
    curso.comisiones.push({ nombre: c.nombre, horarios });
    cursos.set(c.curso.id, curso);
  }
  return [...cursos.values()]
    .map((c) => ({ ...c, comisiones: c.comisiones.sort((a, b) => a.nombre.localeCompare(b.nombre)) }))
    .sort((a, b) => a.codigo.localeCompare(b.codigo));
}

// Alumno: comisiones donde está cursando. Docente: comisiones que dicta.
// Administrativo: todas las comisiones de cursos activos. Si una persona
// tiene varios roles, se juntan.
export async function getCursosEnProgreso(sesion: Sesion): Promise<CursoEnProgreso[]> {
  if (!sesion.persona) return [];
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const comisiones: ComisionRow[] = [];

  if (sesion.roles.includes("ADMINISTRATIVO")) {
    const { data } = await sga.from("comision").select(COMISION_SELECT).returns<ComisionRow[]>();
    return agrupar(data ?? []);
  }

  if (sesion.roles.includes("ALUMNO")) {
    const { data: legajo } = await sga
      .from("legajo")
      .select("id")
      .eq("persona_id", sesion.persona.id)
      .maybeSingle<{ id: number }>();
    if (legajo) {
      const { data } = await sga
        .from("inscripcion_curso")
        .select(`comision:comision_id(${COMISION_SELECT})`)
        .eq("legajo_id", legajo.id)
        .eq("estado", "CURSANDO")
        .returns<{ comision: ComisionRow | null }[]>();
      comisiones.push(...(data ?? []).flatMap((r) => (r.comision ? [r.comision] : [])));
    }
  }

  if (sesion.roles.includes("DOCENTE") || sesion.roles.includes("AYUDANTE")) {
    const { data: docente } = await sga
      .from("docente")
      .select("id")
      .eq("persona_id", sesion.persona.id)
      .maybeSingle<{ id: number }>();
    if (docente) {
      const { data } = await sga
        .from("docente_comision")
        .select(`comision:comision_id(${COMISION_SELECT})`)
        .eq("docente_id", docente.id)
        .returns<{ comision: ComisionRow | null }[]>();
      comisiones.push(...(data ?? []).flatMap((r) => (r.comision ? [r.comision] : [])));
    }
  }

  return agrupar(comisiones);
}
