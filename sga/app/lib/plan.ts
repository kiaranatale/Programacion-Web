import { createClient } from "@/lib/supabase/server";

export type MateriaPlan = {
  id: number;
  codigo: string;
  nombre: string;
  creditos: number;
  creditosRequeridos: number;
  anio: number | null;
  cuatrimestre: number | null;
  correlativas: string[];
};
export type Hueco = { bloque: string; anio: number; cuatrimestre: number; creditos: number };
export type Bloque = {
  id: number | null; // null = materias sin bloque (planes cargados antes de los bloques)
  nombre: string;
  requisito: "APROBAR_TODOS" | "JUNTAR_CREDITOS";
  creditos: number;
  materias: MateriaPlan[];
  huecos: Hueco[]; // solo en bloques APROBAR_TODOS
};
export type PlanDetalle = {
  id: number;
  codigo: string;
  version: number;
  creditosTotales: number;
  vigenciaDesde: string;
  vigenciaHasta: string | null;
  carrera: { codigo: string; nombre: string } | null;
  bloques: Bloque[];
  titulos: { tipo: string; nombre: string; requisito: string | null }[];
};

type PlanRow = {
  id: number;
  codigo: string;
  version: number;
  creditos_totales: number;
  vigencia_desde: string;
  vigencia_hasta: string | null;
  carrera: { codigo: string; nombre: string } | null;
  plan_bloque: {
    id: number; nombre: string; requisito: Bloque["requisito"]; creditos: number; orden: number;
    plan_hueco_electiva: { anio_sugerido: number; cuatrimestre_sugerido: number; creditos: number }[];
  }[];
  plan_materia: {
    bloque_id: number | null;
    anio_sugerido: number | null;
    cuatrimestre_sugerido: number | null;
    creditos_requeridos: number;
    materia: { id: number; codigo: string; nombre: string; creditos: number } | null;
  }[];
  plan_titulo: { tipo: string; nombre: string; requisito: string | null }[];
};
type CorrelativaRow = { materia_id: number; requerida: { codigo: string } | null };

const ordenGrilla = (a: MateriaPlan, b: MateriaPlan) =>
  (a.anio ?? 99) - (b.anio ?? 99) || (a.cuatrimestre ?? 99) - (b.cuatrimestre ?? 99) || a.codigo.localeCompare(b.codigo);

// Plan completo: bloques con sus materias, huecos de electivas,
// correlativas (del plan o generales) y títulos que otorga.
export async function getPlanDetalle(filtro: { id: number } | { carrera: string; codigo: string }): Promise<PlanDetalle | null> {
  const supabase = await createClient();
  const sga = supabase.schema("sga");

  let consulta = sga.from("plan_estudio").select(`id, codigo, version, creditos_totales, vigencia_desde, vigencia_hasta,
    carrera:carrera_id!inner(codigo, nombre),
    plan_bloque(id, nombre, requisito, creditos, orden,
      plan_hueco_electiva(anio_sugerido, cuatrimestre_sugerido, creditos)),
    plan_materia(bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos,
      materia:materia_id(id, codigo, nombre, creditos)),
    plan_titulo(tipo, nombre, requisito)`);
  consulta = "id" in filtro
    ? consulta.eq("id", filtro.id)
    : consulta.eq("codigo", filtro.codigo).eq("carrera.codigo", filtro.carrera);
  const { data: plan } = await consulta.maybeSingle<PlanRow>();
  if (!plan) return null;

  const { data: correlativas } = await sga
    .from("correlativa")
    .select("materia_id, requerida:materia_requerida_id(codigo)")
    .or(`plan_id.eq.${plan.id},plan_id.is.null`)
    .returns<CorrelativaRow[]>();
  const correlativasDe = new Map<number, string[]>();
  for (const c of correlativas ?? []) {
    if (c.requerida) correlativasDe.set(c.materia_id, [...(correlativasDe.get(c.materia_id) ?? []), c.requerida.codigo]);
  }

  const materias = plan.plan_materia
    .filter((pm) => pm.materia)
    .map((pm) => ({
      bloqueId: pm.bloque_id,
      materia: {
        id: pm.materia!.id,
        codigo: pm.materia!.codigo,
        nombre: pm.materia!.nombre,
        creditos: pm.materia!.creditos,
        creditosRequeridos: pm.creditos_requeridos,
        anio: pm.anio_sugerido,
        cuatrimestre: pm.cuatrimestre_sugerido,
        correlativas: correlativasDe.get(pm.materia!.id) ?? [],
      },
    }));

  const bloquesOrdenados = [...plan.plan_bloque].sort((a, b) => a.orden - b.orden || a.nombre.localeCompare(b.nombre));
  const huecos: Hueco[] = bloquesOrdenados.flatMap((b) =>
    b.plan_hueco_electiva.map((h) => ({ bloque: b.nombre, anio: h.anio_sugerido, cuatrimestre: h.cuatrimestre_sugerido, creditos: h.creditos })));
  const primerObligatorio = bloquesOrdenados.find((b) => b.requisito === "APROBAR_TODOS");

  const bloques: Bloque[] = bloquesOrdenados.map((b) => ({
    id: b.id,
    nombre: b.nombre,
    requisito: b.requisito,
    creditos: b.creditos,
    materias: materias.filter((m) => m.bloqueId === b.id).map((m) => m.materia).sort(ordenGrilla),
    huecos: b.id === primerObligatorio?.id ? huecos : [],
  }));

  const sinBloque = materias.filter((m) => m.bloqueId === null).map((m) => m.materia).sort(ordenGrilla);
  if (sinBloque.length > 0) {
    bloques.unshift({
      id: null, nombre: "Materias", requisito: "APROBAR_TODOS",
      creditos: sinBloque.reduce((s, m) => s + m.creditos, 0), materias: sinBloque, huecos: [],
    });
  }

  return {
    id: plan.id,
    codigo: plan.codigo,
    version: plan.version,
    creditosTotales: plan.creditos_totales,
    vigenciaDesde: plan.vigencia_desde,
    vigenciaHasta: plan.vigencia_hasta,
    carrera: plan.carrera,
    bloques,
    titulos: plan.plan_titulo,
  };
}

export function requisitoBloque(b: Bloque): string {
  return b.requisito === "APROBAR_TODOS"
    ? `Aprobar todos los ítems (suma ${b.creditos} créditos)`
    : `Juntar ${b.creditos} créditos`;
}

// Agrupa materias y huecos por "Año X - Cuatrimestre Y".
export function grilla(b: Bloque): { titulo: string; materias: MateriaPlan[]; huecos: Hueco[] }[] {
  const grupos = new Map<string, { titulo: string; orden: number; materias: MateriaPlan[]; huecos: Hueco[] }>();
  const grupo = (anio: number | null, cuatri: number | null) => {
    const clave = `${anio ?? 99}-${cuatri ?? 99}`;
    if (!grupos.has(clave)) {
      grupos.set(clave, {
        titulo: anio ? `Año ${anio} - Cuatrimestre ${cuatri ?? "—"}` : "Sin ubicación en el plan",
        orden: (anio ?? 99) * 10 + (cuatri ?? 9),
        materias: [],
        huecos: [],
      });
    }
    return grupos.get(clave)!;
  };
  for (const m of b.materias) grupo(m.anio, m.cuatrimestre).materias.push(m);
  for (const h of b.huecos) grupo(h.anio, h.cuatrimestre).huecos.push(h);
  return [...grupos.values()].sort((a, c) => a.orden - c.orden);
}
