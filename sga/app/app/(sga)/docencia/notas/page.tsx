import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { MesaDeFinal, MiComision } from "@/lib/docencia";
import { fecha, periodo } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import SinAcceso from "../sin-acceso";

// Docencia → Carga de notas: cursadas y mesas de final, con lo pendiente.
export default async function CargaDeNotas() {
  const sesion = await getSesion();
  if (!sesion?.roles.some((r) => r === "DOCENTE" || r === "AYUDANTE")) return <SinAcceso titulo="Carga de notas" />;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: c }, { data: m }] = await Promise.all([sga.rpc("mis_comisiones"), sga.rpc("mesas_de_final_docente")]);
  const comisiones = (c ?? []) as MiComision[];
  const mesas = (m ?? []) as MesaDeFinal[];
  const hoyStr = hoy();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Carga de notas</h2>

      <h3 className="sga-subtitulo">Notas de cursada</h3>
      <p className="sga-texto">Con 4 o más la cursada queda aprobada; con menos, desaprobada (hay que recursar).</p>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Materia</th><th>Comisión</th><th>Período</th><th>Inscriptos</th><th>Sin nota</th><th></th></tr></thead>
          <tbody>
            {comisiones.length > 0 ? comisiones.map((x) => (
              <tr key={x.comision_id}>
                <td>{x.codigo} - {x.materia}</td>
                <td className="sga-col-cupo"><strong>{x.comision}</strong></td>
                <td>{periodo(x.anio, x.periodo)}</td>
                <td className="sga-col-cupo">{x.inscriptos}</td>
                <td className="sga-col-cupo">{x.sin_nota > 0 ? <strong className="sga-deuda">{x.sin_nota}</strong> : "—"}</td>
                <td className="sga-col-cupo"><Link href={`/docencia/comisiones/${x.comision_id}`}>Cargar notas</Link></td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={6}>No tenés comisiones asignadas.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Notas de finales</h3>
      <p className="sga-texto">
        Se cargan una vez tomada la mesa. La nota definitiva es el promedio entre la cursada y el final aprobado.
      </p>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Materia</th><th>Fecha</th><th>Inscriptos de tus comisiones</th><th>Sin nota</th><th></th></tr></thead>
          <tbody>
            {mesas.length > 0 ? mesas.map((x) => (
              <tr key={x.examen_final_id}>
                <td>{x.codigo} - {x.materia}</td>
                <td>{fecha(x.fecha)} {x.hora_inicio.slice(0, 5)} hs{x.fecha > hoyStr && <div className="sga-ayuda">Todavía no se tomó</div>}</td>
                <td className="sga-col-cupo">{x.inscriptos}</td>
                <td className="sga-col-cupo">{x.sin_nota > 0 ? <strong className="sga-deuda">{x.sin_nota}</strong> : "—"}</td>
                <td className="sga-col-cupo"><Link href={`/docencia/finales/${x.examen_final_id}`}>{x.fecha > hoyStr ? "Ver inscriptos" : "Cargar notas"}</Link></td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={5}>No hay mesas de final de tus materias.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
