import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";

export type Publicacion = {
  id: number;
  organizacion_id: number;
  organizacion: string;
  tipo: "EVENTO" | "NOVEDAD";
  titulo: string;
  cuerpo: string;
  fecha_evento: string | null;
  hora_evento: string | null;
  lugar: string | null;
  creada: string;
  editada: string | null;
  autor_apellido: string | null;
  autor_nombre: string | null;
  comentarios: number;
  puede_editar: boolean;
};

export type Organizacion = { id: number; nombre: string; descripcion: string | null; activa: boolean };

export const PUBLICACION_SELECT =
  "id, organizacion_id, organizacion, tipo, titulo, cuerpo, fecha_evento, hora_evento, lugar, creada, editada, autor_apellido, autor_nombre, comentarios, puede_editar";

export const tipos: Record<string, string> = { EVENTO: "Evento", NOVEDAD: "Novedad" };

const ZONA = "America/Argentina/Buenos_Aires";

// Fecha de hoy en Buenos Aires como YYYY-MM-DD (para comparar con DATE).
export function hoy(): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: ZONA });
}

// "03/10/2026 14:05"
export function fechaHora(valor: string): string {
  return new Date(valor).toLocaleString("es-AR", {
    timeZone: ZONA, day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false,
  });
}

// "Viernes 09/10 · 17:00 hs"
export function cuandoEvento(fecha: string | null, hora: string | null): string {
  if (!fecha) return "";
  const d = new Date(`${fecha}T12:00:00Z`);
  const dia = d.toLocaleDateString("es-AR", { timeZone: "UTC", weekday: "long" });
  const fechaCorta = d.toLocaleDateString("es-AR", { timeZone: "UTC", day: "2-digit", month: "2-digit" });
  return `${dia[0].toUpperCase()}${dia.slice(1)} ${fechaCorta}${hora ? ` · ${hora.slice(0, 5)} hs` : ""}`;
}

export function autor(p: { autor_apellido: string | null; autor_nombre: string | null }): string | null {
  return p.autor_apellido ? `${p.autor_apellido}, ${p.autor_nombre}` : null;
}

// Organizaciones activas en las que la persona logueada puede publicar.
export const getMisOrganizaciones = cache(async (): Promise<{ id: number; nombre: string }[]> => {
  const sesion = await getSesion();
  if (!sesion?.persona) return [];
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("organizacion_miembro")
    .select("organizacion:organizacion_id(id, nombre, activa)")
    .eq("persona_id", sesion.persona.id)
    .returns<{ organizacion: { id: number; nombre: string; activa: boolean } | null }[]>();
  return (data ?? [])
    .flatMap((r) => (r.organizacion?.activa ? [{ id: r.organizacion.id, nombre: r.organizacion.nombre }] : []))
    .sort((a, b) => a.nombre.localeCompare(b.nombre));
});

export const getPublicacion = cache(async (id: number): Promise<Publicacion | null> => {
  if (!Number.isInteger(id)) return null;
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("publicacion_listado")
    .select(PUBLICACION_SELECT)
    .eq("id", id)
    .maybeSingle<Publicacion>();
  return data;
});
