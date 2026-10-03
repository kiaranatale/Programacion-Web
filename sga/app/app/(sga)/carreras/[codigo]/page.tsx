import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { periodoDeFecha } from "@/lib/legajo";

type Plan = { id: number; codigo: string; version: number; vigencia_desde: string; vigencia_hasta: string | null };
type Carrera = { codigo: string; nombre: string; nombre_oficial: string; plan_estudio: Plan[] };

// Detalle de carrera como en el SGA actual: nombres y listado de planes.
export default async function DetalleCarrera({ params }: PageProps<"/carreras/[codigo]">) {
  const codigo = decodeURIComponent((await params).codigo);
  const supabase = await createClient();
  const { data: carrera } = await supabase
    .schema("sga")
    .from("carrera")
    .select("codigo, nombre, nombre_oficial, plan_estudio(id, codigo, version, vigencia_desde, vigencia_hasta)")
    .eq("codigo", codigo)
    .maybeSingle<Carrera>();

  if (!carrera) notFound();
  const planes = [...carrera.plan_estudio].sort((a, b) => b.vigencia_desde.localeCompare(a.vigencia_desde));

  return (
    <>
      <section className="sga-encabezado-carrera">
        <p><strong>Nombre de la Carrera:</strong> <span>{carrera.nombre}</span></p>
        <p><strong>Nombre Oficial de la Carrera :</strong> <span>{carrera.nombre_oficial}</span></p>
      </section>

      <h2 className="sga-titulo sga-titulo-grande sga-titulo-suelto">Listado de Planes de estudio</h2>
      <section className="sga-panel">
        <div className="sga-tabla-scroll">
          <table className="sga-tabla">
            <thead>
              <tr><th>Nombre de la Carrera</th><th>Versión</th><th>Activo desde</th><th>Activo hasta</th><th>Acciones</th></tr>
            </thead>
            <tbody>
              {planes.length > 0 ? planes.map((p) => (
                <tr key={p.id}>
                  <td className="sga-curso">{p.codigo}</td>
                  <td>{p.version}</td>
                  <td className="sga-curso">{periodoDeFecha(p.vigencia_desde)}</td>
                  <td className="sga-curso">{p.vigencia_hasta ? periodoDeFecha(p.vigencia_hasta) : ""}</td>
                  <td>
                    <Link aria-label={`Ver plan ${p.codigo}`} href={`/carreras/${encodeURIComponent(carrera.codigo)}/planes/${encodeURIComponent(p.codigo)}`}>🔍</Link>
                  </td>
                </tr>
              )) : (
                <tr><td className="sga-vacio" colSpan={5}>Esta carrera no tiene planes de estudio cargados.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
      <Link className="sga-volver" href="/carreras">← Volver al listado de carreras</Link>
    </>
  );
}
