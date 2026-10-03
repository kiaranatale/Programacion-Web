import { createClient } from "@/lib/supabase/server";
import { getCurso } from "@/lib/curso";
import { fecha } from "@/lib/legajo";

type EnPlan = {
  anio_sugerido: number | null;
  cuatrimestre_sugerido: number | null;
  creditos_requeridos: number;
  plan: { id: number; codigo: string; carrera: { codigo: string; nombre: string } | null } | null;
  bloque: { nombre: string } | null;
};
type Correlativa = { plan_id: number | null; requerida: { codigo: string; nombre: string } | null };

// Información de la materia: datos generales y en qué planes aparece, con
// su ubicación, créditos requeridos y correlativas en cada plan.
export default async function InformacionMateria({ params }: PageProps<"/cursos/[id]/informacion">) {
  const curso = await getCurso(Number((await params).id));
  if (!curso?.materia) return null;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: planes }, { data: correlativas }, { data: resumen }] = await Promise.all([
    sga.from("plan_materia")
      .select("anio_sugerido, cuatrimestre_sugerido, creditos_requeridos, plan:plan_id(id, codigo, carrera:carrera_id(codigo, nombre)), bloque:bloque_id(nombre)")
      .eq("materia_id", curso.materia.id)
      .returns<EnPlan[]>(),
    sga.from("correlativa")
      .select("plan_id, requerida:materia_requerida_id(codigo, nombre)")
      .eq("materia_id", curso.materia.id)
      .returns<Correlativa[]>(),
    sga.from("curso_listado").select("alumnos").eq("id", curso.id).maybeSingle<{ alumnos: number }>(),
  ]);

  const correlativasDe = (planId: number) =>
    (correlativas ?? []).filter((c) => c.requerida && (c.plan_id === planId || c.plan_id === null))
      .map((c) => `${c.requerida!.codigo} - ${c.requerida!.nombre}`);

  return (
    <>
      <dl className="sga-datos sga-datos-carrera">
        <div><dt>Créditos:</dt><dd>{curso.materia.creditos ?? "Sin dato"}</dd></div>
        <div><dt>Comienzo del curso:</dt><dd>{fecha(curso.fecha_inicio)}</dd></div>
        <div><dt>Fin del curso:</dt><dd>{fecha(curso.fecha_fin)}</dd></div>
        <div><dt>Activo:</dt><dd>{curso.activo ? "Sí" : "No"}</dd></div>
        <div><dt>Alumnos inscriptos:</dt><dd>{resumen?.alumnos ?? 0}</dd></div>
      </dl>

      <h3 className="sga-subtitulo">Planes de estudio que la incluyen</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Carrera</th><th>Plan</th><th>Ubicación</th><th>Créditos requeridos</th><th>Correlativas</th></tr></thead>
          <tbody>
            {planes && planes.length > 0 ? planes.filter((p) => p.plan).map((p) => (
              <tr key={p.plan!.id}>
                <td className="sga-curso">{p.plan!.carrera?.nombre}</td>
                <td className="sga-materia-plan">{p.plan!.codigo}</td>
                <td>
                  {p.anio_sugerido ? `Año ${p.anio_sugerido} - Cuatrimestre ${p.cuatrimestre_sugerido ?? "—"}` : p.bloque?.nombre ?? "—"}
                </td>
                <td>{p.creditos_requeridos}</td>
                <td className="sga-curso">{correlativasDe(p.plan!.id).join(" · ") || "Sin correlativas"}</td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={5}>La materia no figura en ningún plan cargado.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
