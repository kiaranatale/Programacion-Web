import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { formatearHorario } from "@/lib/cursos";
import { getCurso } from "@/lib/curso";

type Inscriptos = { comision_id: number; inscriptos: number };
type Companero = { apellido: string; nombre: string };

// Comisiones con su ocupación del cupo ("1/40"). Los alumnos de una
// comisión (y sus docentes y Administración) pueden abrir el listado de
// inscriptos; la base verifica quién lo pide.
export default async function Comisiones({ params, searchParams }: PageProps<"/cursos/[id]/comisiones">) {
  const curso = await getCurso(Number((await params).id));
  if (!curso) return null;
  const { inscriptos: verParam } = await searchParams;
  const comisiones = [...curso.comision].sort((a, b) => a.nombre.localeCompare(b.nombre));

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: ocupacion }, permisos] = await Promise.all([
    sga.from("comision_inscriptos").select("comision_id, inscriptos").eq("curso_id", curso.id).returns<Inscriptos[]>(),
    Promise.all(comisiones.map(async (c) => {
      const { data } = await sga.rpc("puede_ver_inscriptos", { p_comision_id: c.id });
      return [c.id, data === true] as const;
    })),
  ]);
  const inscriptosDe = new Map((ocupacion ?? []).map((o) => [o.comision_id, o.inscriptos]));
  const puedeVer = new Map(permisos);

  const base = `/cursos/${curso.id}/comisiones`;
  const elegida = comisiones.find((c) => String(c.id) === verParam && puedeVer.get(c.id));
  let companeros: Companero[] = [];
  if (elegida) {
    const { data } = await sga.rpc("companeros_comision", { p_comision_id: elegida.id });
    companeros = (data ?? []) as Companero[];
  }

  return (
    <>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Comisión</th><th>Cupo</th><th>Horarios</th><th>Inscriptos</th></tr></thead>
          <tbody>
            {comisiones.length > 0 ? comisiones.map((c) => {
              const inscriptos = inscriptosDe.get(c.id) ?? 0;
              return (
                <tr key={c.id}>
                  <td><strong>{c.nombre}</strong></td>
                  <td className="sga-col-cupo">{c.cupo ? `${inscriptos}/${c.cupo}` : `${inscriptos} (sin cupo)`}</td>
                  <td className="sga-horarios">
                    {c.horario_comision.length > 0 ? c.horario_comision.map(formatearHorario).join(" | ") : "Sin horarios cargados"}
                  </td>
                  <td className="sga-col-cupo">
                    {puedeVer.get(c.id)
                      ? elegida?.id === c.id
                        ? <Link href={base}>Ocultar listado</Link>
                        : <Link href={`${base}?inscriptos=${c.id}`}>Ver listado</Link>
                      : "—"}
                  </td>
                </tr>
              );
            }) : (
              <tr><td className="sga-vacio" colSpan={4}>Este curso todavía no tiene comisiones cargadas.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {elegida && (
        <>
          <h3 className="sga-subtitulo">Inscriptos en la comisión {elegida.nombre} ({companeros.length})</h3>
          {companeros.length > 0 ? (
            <ol className="sga-lista-inscriptos">
              {companeros.map((p, i) => <li key={i}>{p.apellido}, {p.nombre}</li>)}
            </ol>
          ) : (
            <p className="sga-vacio">No hay alumnos inscriptos en esta comisión.</p>
          )}
        </>
      )}
    </>
  );
}
