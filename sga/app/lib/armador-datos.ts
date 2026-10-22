import { createClient } from "@/lib/supabase/server";
import { getCursadas } from "@/lib/cursadas";
import { DIA_DE, minutos, type EstadoMateria, type MateriaArmador, type Modalidad } from "@/lib/armador";

export type PeriodoArmador = { anio: number; periodo: string };
export type PlanOpcion = { id: number; codigo: string; carrera: string };

type CursoRow = {
  id: number;
  materia_id: number;
  fecha_inicio: string;
  comision: {
    id: number; nombre: string; cupo: number | null; inscriptos_sga: number | null;
    horario_comision: {
      dia_semana: string; hora_inicio: string; hora_fin: string; modalidad: Modalidad;
      aula: { codigo: string; edificio: { nombre: string } | null } | null;
    }[];
  }[];
};
type PlanMateriaRow = {
  anio_sugerido: number | null;
  cuatrimestre_sugerido: number | null;
  materia: { id: number; codigo: string; nombre: string; creditos: number | null } | null;
};
type CorrelativaRow = { materia_id: number; estado_requerido: "REGULAR" | "APROBADA"; requerida: { id: number; codigo: string } | null };

const clave = (p: PeriodoArmador) => `${p.anio}-${p.periodo}`;
export const deClave = (texto: string | undefined): PeriodoArmador | null => {
  const m = texto?.match(/^(\d{4})-(1C|2C)$/);
  return m ? { anio: Number(m[1]), periodo: m[2] } : null;
};
export { clave as clavePeriodo };

// Períodos que tienen comisiones con horarios, del más nuevo al más viejo.
export async function getPeriodosArmador(): Promise<PeriodoArmador[]> {
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("curso")
    .select("anio, periodo, comision!inner(horario_comision!inner(id))")
    .eq("activo", true)
    .limit(1, { referencedTable: "comision" })
    .limit(1, { referencedTable: "comision.horario_comision" })
    .returns<PeriodoArmador[]>();
  const unicos = new Map((data ?? []).map((p) => [clave(p), { anio: p.anio, periodo: p.periodo }]));
  return [...unicos.values()].sort((a, b) => b.anio - a.anio || b.periodo.localeCompare(a.periodo));
}

export async function getPlanesArmador(): Promise<PlanOpcion[]> {
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("plan_estudio")
    .select("id, codigo, carrera:carrera_id(nombre_oficial)")
    .order("codigo")
    .returns<{ id: number; codigo: string; carrera: { nombre_oficial: string } | null }[]>();
  return (data ?? []).map((p) => ({ id: p.id, codigo: p.codigo, carrera: p.carrera?.nombre_oficial ?? "" }));
}

// Materias del plan que se dictan en el período, con sus comisiones y
// horarios. Si se pasa el legajo (y es de ese plan), cada materia trae el
// estado del alumno: aprobada, cursada, cursando, o las correlativas que le
// faltan para cursarla.
export async function getMateriasArmador(planId: number, periodo: PeriodoArmador, legajoId: number | null): Promise<MateriaArmador[]> {
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data: delPlan } = await sga.from("plan_materia")
    .select("anio_sugerido, cuatrimestre_sugerido, materia:materia_id(id, codigo, nombre, creditos)")
    .eq("plan_id", planId)
    .returns<PlanMateriaRow[]>();
  const materias = (delPlan ?? []).filter((pm) => pm.materia);
  if (materias.length === 0) return [];

  const [{ data: cursos }, { data: correlativas }, cursadas] = await Promise.all([
    sga.from("curso")
      .select(`id, materia_id, fecha_inicio, comision(id, nombre, cupo, inscriptos_sga,
        horario_comision(dia_semana, hora_inicio, hora_fin, modalidad, aula:aula_id(codigo, edificio:edificio_id(nombre))))`)
      .eq("anio", periodo.anio).eq("periodo", periodo.periodo).eq("activo", true)
      .in("materia_id", materias.map((pm) => pm.materia!.id))
      .returns<CursoRow[]>(),
    legajoId
      ? sga.from("correlativa")
          .select("materia_id, estado_requerido, requerida:materia_requerida_id(id, codigo)")
          .eq("tipo_requisito", "PARA_CURSAR")
          .or(`plan_id.eq.${planId},plan_id.is.null`)
          .returns<CorrelativaRow[]>()
      : Promise.resolve({ data: [] as CorrelativaRow[] }),
    legajoId ? getCursadas(legajoId) : Promise.resolve([]),
  ]);

  // Estado de cada materia según las cursadas del alumno
  const rango: Record<string, number> = { CURSANDO: 1, CURSADA_APROBADA: 2, APROBADA: 3 };
  const estadoDe = new Map<number, string>();
  for (const c of cursadas) {
    const id = c.curso?.materia?.id;
    if (id && rango[c.estado] && (rango[c.estado] > (rango[estadoDe.get(id) ?? ""] ?? 0))) estadoDe.set(id, c.estado);
  }
  const cumple = (requerida: number, estado: "REGULAR" | "APROBADA") => {
    const e = estadoDe.get(requerida);
    return e === "APROBADA" || (estado === "REGULAR" && e === "CURSADA_APROBADA");
  };

  // Una materia puede tener varios cursos en el período (bimestrales): la
  // comisión lleva la fecha de inicio para distinguirlos.
  const comisionesDe = new Map<number, MateriaArmador["comisiones"]>();
  const varios = new Set((cursos ?? []).filter((c, i, todos) => todos.findIndex((x) => x.materia_id === c.materia_id) !== i).map((c) => c.materia_id));
  for (const curso of cursos ?? []) {
    const lista = comisionesDe.get(curso.materia_id) ?? [];
    for (const co of curso.comision) {
      lista.push({
        id: co.id,
        nombre: varios.has(curso.materia_id) ? `${co.nombre} (desde ${curso.fecha_inicio.slice(8, 10)}/${curso.fecha_inicio.slice(5, 7)})` : co.nombre,
        cupo: co.cupo,
        inscriptos: co.inscriptos_sga,
        bloques: co.horario_comision
          .map((h) => ({
            dia: DIA_DE[h.dia_semana] ?? 0,
            desde: minutos(h.hora_inicio),
            hasta: minutos(h.hora_fin),
            modalidad: h.modalidad,
            lugar: h.aula ? `Aula ${h.aula.codigo}${h.aula.edificio ? ` · ${h.aula.edificio.nombre}` : ""}` : "",
          }))
          .sort((a, b) => a.dia - b.dia || a.desde - b.desde),
      });
    }
    comisionesDe.set(curso.materia_id, lista.sort((a, b) => a.nombre.localeCompare(b.nombre)));
  }

  return materias
    .map((pm): MateriaArmador => {
      const m = pm.materia!;
      const e = estadoDe.get(m.id);
      const faltan = (correlativas ?? [])
        .filter((c) => c.materia_id === m.id && c.requerida && !cumple(c.requerida.id, c.estado_requerido))
        .map((c) => c.requerida!.codigo);
      const estado: EstadoMateria = e === "APROBADA" ? "APROBADA" : e === "CURSADA_APROBADA" ? "CURSADA"
        : e === "CURSANDO" ? "CURSANDO" : faltan.length ? "CORRELATIVAS" : "DISPONIBLE";
      return {
        codigo: m.codigo,
        nombre: m.nombre,
        creditos: m.creditos,
        anio: pm.anio_sugerido,
        cuatrimestre: pm.cuatrimestre_sugerido,
        estado,
        faltan: faltan.length ? [...new Set(faltan)].sort().join(", ") : null,
        comisiones: comisionesDe.get(m.id) ?? [],
      };
    })
    .sort((a, b) => (a.anio ?? 99) - (b.anio ?? 99) || (a.cuatrimestre ?? 99) - (b.cuatrimestre ?? 99) || a.codigo.localeCompare(b.codigo));
}
