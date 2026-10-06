import Link from "next/link";
import ListadoTramites from "@/components/listado-tramites";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";
import { buscarTramites, leerFiltros } from "@/lib/tramites";

// Trámites propios. Al entrar, las notificaciones de trámites quedan
// leídas.
export default async function ListadoDeTramites({ searchParams }: PageProps<"/tramites">) {
  const params = await searchParams;
  const filtros = leerFiltros(params);
  const sesion = await getSesion();
  const personaId = sesion?.persona?.id ?? 0;
  const supabase = await createClient();
  const [tramites] = await Promise.all([
    buscarTramites(supabase, filtros, personaId),
    supabase.schema("sga").from("notificacion").update({ leida: true }).eq("persona_id", personaId).eq("tipo", "TRAMITE").eq("leida", false),
  ]);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Listado de trámites pendientes</h2>
      {typeof params.ok === "string" && <p className="sga-mensaje-ok" role="status">{params.ok}</p>}
      <p className="sga-texto"><Link href="/tramites/nuevo">Iniciar nuevo trámite</Link></p>
      <ListadoTramites base="/tramites" filtros={filtros} tramites={tramites} />
    </section>
  );
}
