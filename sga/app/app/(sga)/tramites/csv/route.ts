import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { buscarTramites, destinos, estadosTramite, leerFiltros } from "@/lib/tramites";

const celda = (v: string) => `"${v.replace(/"/g, '""')}"`;

// Descarga del listado de trámites en CSV, con los mismos filtros. Sin
// "todos" (o sin ser de Administración), solo los propios.
export async function GET(request: Request) {
  const sesion = await getSesion();
  if (!sesion?.persona) return new Response("No autorizado", { status: 401 });
  const params = Object.fromEntries(new URL(request.url).searchParams);
  const todos = params.todos === "1" && sesion.roles.includes("ADMINISTRATIVO");
  const supabase = await createClient();
  const tramites = await buscarTramites(supabase, leerFiltros(params), todos ? undefined : sesion.persona.id);

  const filas = [
    ["Número", "Enviado por", "Legajo", "Fecha de creación", "Título", "Destino", "Asignado a", "Estado"],
    ...tramites.map((t) => [
      String(t.id), t.enviado_por, t.numero_legajo ?? "", fechaHora(t.fecha_creacion), t.titulo,
      destinos[t.destino], t.asignado_a ?? "", estadosTramite[t.estado].texto,
    ]),
  ];
  // BOM para que Excel lea bien los acentos
  const csv = "﻿" + filas.map((f) => f.map(celda).join(";")).join("\r\n");
  return new Response(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="tramites.csv"',
      "Cache-Control": "no-store",
    },
  });
}
