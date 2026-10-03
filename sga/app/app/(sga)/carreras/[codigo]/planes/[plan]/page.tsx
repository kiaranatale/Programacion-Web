import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { periodoDeFecha } from "@/lib/legajo";

type PlanMateria = {
  anio_sugerido: number | null;
  cuatrimestre_sugerido: number | null;
  materia: { codigo: string; nombre: string; creditos: number } | null;
};
type Plan = {
  codigo: string;
  version: number;
  creditos_totales: number;
  vigencia_desde: string;
  vigencia_hasta: string | null;
  carrera: { codigo: string; nombre: string } | null;
  plan_materia: PlanMateria[];
};

export default async function DetallePlan({ params }: PageProps<"/carreras/[codigo]/planes/[plan]">) {
  const { codigo, plan: planCodigo } = await params;
  const carreraCodigo = decodeURIComponent(codigo);
  const supabase = await createClient();
  const { data: plan } = await supabase
    .schema("sga")
    .from("plan_estudio")
    .select(`codigo, version, creditos_totales, vigencia_desde, vigencia_hasta,
      carrera:carrera_id!inner(codigo, nombre),
      plan_materia(anio_sugerido, cuatrimestre_sugerido, materia:materia_id(codigo, nombre, creditos))`)
    .eq("codigo", decodeURIComponent(planCodigo))
    .eq("carrera.codigo", carreraCodigo)
    .maybeSingle<Plan>();

  if (!plan) notFound();

  const materias = plan.plan_materia
    .filter((pm) => pm.materia)
    .sort((a, b) =>
      (a.anio_sugerido ?? 99) - (b.anio_sugerido ?? 99) ||
      (a.cuatrimestre_sugerido ?? 99) - (b.cuatrimestre_sugerido ?? 99) ||
      a.materia!.codigo.localeCompare(b.materia!.codigo));
  const creditosMaterias = materias.reduce((s, pm) => s + pm.materia!.creditos, 0);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Plan {plan.codigo} - {plan.carrera?.nombre}</h2>
      <dl className="sga-datos sga-datos-carrera">
        <div><dt>Versión:</dt><dd>{plan.version}</dd></div>
        <div><dt>Activo desde:</dt><dd>{periodoDeFecha(plan.vigencia_desde)}</dd></div>
        <div><dt>Activo hasta:</dt><dd>{plan.vigencia_hasta ? periodoDeFecha(plan.vigencia_hasta) : "Vigente"}</dd></div>
        <div><dt>Créditos totales:</dt><dd>{plan.creditos_totales} ({creditosMaterias} en materias cargadas)</dd></div>
      </dl>

      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Año</th><th>Cuatrimestre</th><th>Materia</th><th>Créditos</th></tr></thead>
          <tbody>
            {materias.length > 0 ? materias.map((pm) => (
              <tr key={pm.materia!.codigo}>
                <td>{pm.anio_sugerido ?? "—"}</td>
                <td>{pm.cuatrimestre_sugerido ?? "—"}</td>
                <td className="sga-curso">{pm.materia!.codigo} - {pm.materia!.nombre}</td>
                <td>{pm.materia!.creditos}</td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={4}>El plan no tiene materias cargadas.</td></tr>
            )}
          </tbody>
        </table>
      </div>
      <Link className="sga-volver" href={`/carreras/${encodeURIComponent(carreraCodigo)}`}>← Volver a la carrera</Link>
    </section>
  );
}
