import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { MiComision } from "@/lib/docencia";
import { periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import SinAcceso from "./sin-acceso";

function Tabla({ filas }: { filas: MiComision[] }) {
  return (
    <div className="sga-tabla-scroll">
      <table className="sga-tabla sga-tabla-mensajes">
        <thead><tr><th>Materia</th><th>Comisión</th><th>Período</th><th>Cargo</th><th>Inscriptos</th><th>Sin nota de cursada</th><th>Acciones</th></tr></thead>
        <tbody>
          {filas.map((c) => (
            <tr key={c.comision_id}>
              <td><Link href={`/cursos/${c.curso_id}`}>{c.codigo} - {c.materia}</Link></td>
              <td className="sga-col-cupo"><strong>{c.comision}</strong></td>
              <td>{periodo(c.anio, c.periodo)}</td>
              <td>{c.cargo ?? "—"}{c.responsable && <div className="sga-ayuda">Responsable del curso</div>}</td>
              <td className="sga-col-cupo">{c.inscriptos}</td>
              <td className="sga-col-cupo">{c.sin_nota > 0 ? <strong className="sga-deuda">{c.sin_nota}</strong> : "—"}</td>
              <td className="sga-acciones-doc">
                <Link href={`/docencia/comisiones/${c.comision_id}`}>Alumnos y notas</Link>
                <Link href={`/cursos/${c.curso_id}/comisiones?inscriptos=${c.comision_id}`}>Listado</Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Docencia → Mis comisiones: las comisiones que dicta el docente.
export default async function MisComisiones() {
  const sesion = await getSesion();
  if (!sesion?.roles.some((r) => r === "DOCENTE" || r === "AYUDANTE")) return <SinAcceso titulo="Mis comisiones" />;

  const supabase = await createClient();
  const { data } = await supabase.schema("sga").rpc("mis_comisiones");
  const comisiones = (data ?? []) as MiComision[];
  const activas = comisiones.filter((c) => c.activo);
  const anteriores = comisiones.filter((c) => !c.activo);

  return (
    <section className="sga-panel">
      <div className="sga-hoy-encabezado">
        <h2 className="sga-titulo sga-titulo-grande">Mis comisiones</h2>
        <Link className="sga-boton" href="/docencia/notas">Carga de notas</Link>
      </div>
      {comisiones.length === 0 && <p className="sga-vacio">No tenés comisiones asignadas.</p>}
      {activas.length > 0 && (<><h3 className="sga-subtitulo">En curso</h3><Tabla filas={activas} /></>)}
      {anteriores.length > 0 && (<><h3 className="sga-subtitulo">Anteriores</h3><Tabla filas={anteriores} /></>)}
    </section>
  );
}
