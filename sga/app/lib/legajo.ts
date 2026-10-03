import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";

export type Legajo = {
  id: number;
  numero_legajo: string;
  fecha_registracion: string;
  rendimiento_academico: number | null;
  condicional_especial: boolean;
  plan_estudio: {
    id: number;
    codigo: string;
    creditos_totales: number;
    carrera: { codigo: string; nombre_oficial: string; nivel: string } | null;
  } | null;
};

export type LegajoActual = {
  legajo: Legajo | null;
  nombre: string; // "Apellido, Nombre"
};

// Legajo de la persona logueada. RLS solo devuelve el propio.
export const getLegajoActual = cache(async (): Promise<LegajoActual> => {
  const sesion = await getSesion();
  const nombre = sesion?.persona ? `${sesion.persona.apellido}, ${sesion.persona.nombre}` : "";
  if (!sesion?.persona) return { legajo: null, nombre };

  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("legajo")
    .select(`id, numero_legajo, fecha_registracion, rendimiento_academico, condicional_especial,
      plan_estudio:plan_estudio_id(id, codigo, creditos_totales,
        carrera:carrera_id(codigo, nombre_oficial, nivel))`)
    .eq("persona_id", sesion.persona.id)
    .maybeSingle<Legajo>();

  return { legajo: data, nombre };
});

// ---------- Formato ----------

export function fecha(valor: string | null | undefined): string {
  if (!valor) return "";
  const [anio, mes, dia] = valor.slice(0, 10).split("-");
  return `${dia}/${mes}/${anio}`;
}

export function nota(valor: number | null | undefined): string {
  return valor === null || valor === undefined ? "" : Number(valor).toLocaleString("es-AR", { maximumFractionDigits: 2 });
}

export function pesos(valor: number): string {
  return Number(valor).toLocaleString("es-AR", { style: "currency", currency: "ARS", minimumFractionDigits: 2 });
}

const periodos: Record<string, string> = { "1C": "Primer Cuat.", "2C": "Segundo Cuat." };
export function periodo(anio: number, codigo: string): string {
  return `${periodos[codigo] ?? codigo} ${anio}`;
}
