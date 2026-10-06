import type { createClient } from "@/lib/supabase/server";

type Cliente = Awaited<ReturnType<typeof createClient>>;

export type EstadoTramite = "PENDIENTE" | "EN_CURSO" | "RESUELTO" | "RECHAZADO" | "CANCELADO";
export type Destino = "ACADEMICA" | "ADMINISTRATIVA";

export const estadosTramite: Record<EstadoTramite, { texto: string; clase: string }> = {
  PENDIENTE: { texto: "Pendiente", clase: "sga-estado-programada" },
  EN_CURSO: { texto: "En curso", clase: "sga-estado-activa" },
  RESUELTO: { texto: "Resuelto", clase: "sga-estado-activa" },
  RECHAZADO: { texto: "Rechazado", clase: "sga-estado-rechazado-chip" },
  CANCELADO: { texto: "Cancelado", clase: "sga-estado-finalizada" },
};

export const destinos: Record<Destino, string> = {
  ACADEMICA: "Secretaría Académica",
  ADMINISTRATIVA: "Secretaría Administrativa",
};

export const abierto = (estado: EstadoTramite) => estado === "PENDIENTE" || estado === "EN_CURSO";

export type TramiteListado = {
  id: number;
  persona_id: number;
  titulo: string;
  destino: Destino;
  estado: EstadoTramite;
  fecha_creacion: string;
  enviado_por: string;
  numero_legajo: string | null;
  asignado_a: string | null;
};

export type FiltrosTramites = { desde: string; hasta: string; titulo: string; estado: string; orden: "asc" | "desc" };

const texto = (v: string | string[] | undefined) => (typeof v === "string" ? v.trim() : "");
const esFecha = (v: string) => /^\d{4}-\d{2}-\d{2}$/.test(v);

export function leerFiltros(params: Record<string, string | string[] | undefined>): FiltrosTramites {
  const desde = texto(params.desde);
  const hasta = texto(params.hasta);
  const estado = texto(params.estado);
  return {
    desde: esFecha(desde) ? desde : "",
    hasta: esFecha(hasta) ? hasta : "",
    titulo: texto(params.titulo).slice(0, 100),
    estado: estado in estadosTramite ? estado : "",
    orden: texto(params.orden) === "asc" ? "asc" : "desc",
  };
}

// Trámites visibles (RLS: los propios, o todos para Administración) con
// los filtros del listado. Las fechas se toman en hora de Buenos Aires.
export async function buscarTramites(supabase: Cliente, f: FiltrosTramites, soloDe?: number) {
  let q = supabase.schema("sga").from("tramite_listado")
    .select("id, persona_id, titulo, destino, estado, fecha_creacion, enviado_por, numero_legajo, asignado_a");
  if (soloDe !== undefined) q = q.eq("persona_id", soloDe);
  if (f.desde) q = q.gte("fecha_creacion", `${f.desde}T00:00:00-03:00`);
  if (f.hasta) q = q.lte("fecha_creacion", `${f.hasta}T23:59:59.999-03:00`);
  if (f.titulo) q = q.ilike("titulo", `%${f.titulo.replace(/[%_\\]/g, (c) => `\\${c}`)}%`);
  if (f.estado) q = q.eq("estado", f.estado);
  const { data } = await q.order("fecha_creacion", { ascending: f.orden === "asc" }).limit(500).returns<TramiteListado[]>();
  return data ?? [];
}

export function consulta(f: FiltrosTramites, extra: Record<string, string> = {}): string {
  const p = new URLSearchParams(extra);
  for (const [k, v] of Object.entries(f)) if (v && !(k === "orden" && v === "desc")) p.set(k, v);
  const s = p.toString();
  return s ? `?${s}` : "";
}
