import ListadoTramites from "@/components/listado-tramites";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";
import { buscarTramites, leerFiltros } from "@/lib/tramites";

// Trámites de todos, para las secretarías.
export default async function GestionDeTramites({ searchParams }: PageProps<"/administracion/tramites">) {
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Trámites</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const filtros = leerFiltros(await searchParams);
  const supabase = await createClient();
  const tramites = await buscarTramites(supabase, filtros);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Trámites de alumnos y docentes</h2>
      <p className="sga-texto">
        Entrá a cada trámite para tomarlo (queda asignado a vos), responder, resolverlo o rechazarlo. Filtrá por estado
        &quot;Pendiente&quot; para ver los que nadie tomó.
      </p>
      <ListadoTramites base="/administracion/tramites" todos filtros={filtros} tramites={tramites} />
    </section>
  );
}
