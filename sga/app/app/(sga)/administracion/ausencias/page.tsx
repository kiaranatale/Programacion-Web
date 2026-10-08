import { createClient } from "@/lib/supabase/server";
import { estadosAusencia, tiposAusencia, type Ausencia } from "@/lib/ausencias";
import { fecha } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { revisarAusencia } from "./actions";

const rango = (a: Ausencia) => (a.fecha_inicio === a.fecha_fin ? fecha(a.fecha_inicio) : `${fecha(a.fecha_inicio)} al ${fecha(a.fecha_fin)}`);

// Ausencias informadas por los docentes: justificar o no.
export default async function AusenciasDocentes({ searchParams }: PageProps<"/administracion/ausencias">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Ausencias docentes</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").rpc("ausencias_docentes", { p_solo_mias: false });
  const ausencias = (data ?? []) as Ausencia[];
  const pendientes = ausencias.filter((a) => a.estado === "INFORMADA");
  const resto = ausencias.filter((a) => a.estado !== "INFORMADA").slice(0, 50);

  const fila = (a: Ausencia, revisar: boolean) => (
    <tr key={a.id}>
      <td>{a.apellido}, {a.nombre}</td>
      <td>{rango(a)}</td>
      <td>{tiposAusencia[a.tipo] ?? a.tipo}{a.motivo && <div className="sga-ayuda">{a.motivo}</div>}</td>
      <td>{a.comisiones}</td>
      {revisar ? (
        <td className="sga-acciones-doc">
          <form action={revisarAusencia}>
            <input name="id" type="hidden" value={a.id} />
            <button name="decision" type="submit" value="justificar">Justificar</button>
          </form>
          <form action={revisarAusencia}>
            <input name="id" type="hidden" value={a.id} />
            <input aria-label="Motivo" name="observaciones" placeholder="Por qué no se justifica" required />
            <button className="sga-boton-peligro" name="decision" type="submit" value="no">No justificar</button>
          </form>
        </td>
      ) : (
        <td>
          <span className={`sga-estado-encuesta ${estadosAusencia[a.estado]?.clase ?? ""}`}>{estadosAusencia[a.estado]?.texto ?? a.estado}</span>
          {a.observaciones && <div className="sga-ayuda">{a.observaciones}</div>}
        </td>
      )}
    </tr>
  );

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Ausencias docentes</h2>
      <p className="sga-texto">Ausencias que informan los docentes. A los alumnos ya se les avisó; acá se marca si se justifica.</p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <h3 className="sga-subtitulo">Por revisar ({pendientes.length})</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Docente</th><th>Fechas</th><th>Tipo y motivo</th><th>Comisiones</th><th>Acciones</th></tr></thead>
          <tbody>
            {pendientes.length > 0 ? pendientes.map((a) => fila(a, true)) : <tr><td className="sga-vacio" colSpan={5}>No hay ausencias por revisar.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Revisadas y canceladas</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Docente</th><th>Fechas</th><th>Tipo y motivo</th><th>Comisiones</th><th>Estado</th></tr></thead>
          <tbody>
            {resto.length > 0 ? resto.map((a) => fila(a, false)) : <tr><td className="sga-vacio" colSpan={5}>Todavía no hay.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
