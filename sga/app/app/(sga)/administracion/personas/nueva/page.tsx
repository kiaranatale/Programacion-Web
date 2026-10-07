import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";
import FormularioAlta from "./formulario";

type Plan = { id: number; codigo: string; carrera: { nombre_oficial: string } | null };

export default async function NuevaPersona() {
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Nueva persona</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("plan_estudio")
    .select("id, codigo, carrera:carrera_id(nombre_oficial)").order("codigo").returns<Plan[]>();
  const planes = (data ?? []).map((p) => ({ id: p.id, codigo: p.codigo, carrera: p.carrera?.nombre_oficial ?? "" }));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Nueva persona</h2>
      <p className="sga-texto">
        Si es alumno, se crea también su legajo. Si es docente o ayudante, después le asignás las comisiones desde su ficha.
      </p>
      <FormularioAlta planes={planes} />
    </section>
  );
}
