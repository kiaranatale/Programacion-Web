import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { estadosProyecto, periodoProyecto, tiposProyecto, type EstadoProyecto, type TipoProyecto } from "@/lib/proyectos";
import { getSesion } from "@/lib/sesion";
import { revisarProyecto } from "./actions";

type Proyecto = {
  id: number;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  tipo: TipoProyecto;
  titulo: string;
  materia: string | null;
  responsable: string | null;
  descripcion: string | null;
  desde: string;
  hasta: string | null;
  estado: EstadoProyecto;
  observaciones: string | null;
  fecha_carga: string;
};

function Detalle({ p }: { p: Proyecto }) {
  return (
    <>
      <strong>{p.titulo}</strong>
      <div className="sga-ayuda">
        {tiposProyecto[p.tipo]} · {periodoProyecto(p.desde, p.hasta)}
        {p.materia && <> · {p.materia}</>}
        {p.responsable && <> · A cargo: {p.responsable}</>}
      </div>
      {p.descripcion && <div className="sga-cv-descripcion">{p.descripcion}</div>}
    </>
  );
}

// Validación de los proyectos que cargan los alumnos en su legajo.
export default async function ProyectosDeAlumnos({ searchParams }: PageProps<"/administracion/proyectos">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Proyectos de alumnos</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const { data } = await supabase.schema("sga").rpc("proyectos_para_revisar");
  const proyectos = (data ?? []) as Proyecto[];
  const pendientes = proyectos.filter((p) => p.estado === "PENDIENTE");
  const revisados = proyectos.filter((p) => p.estado !== "PENDIENTE").slice(0, 30);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Proyectos de alumnos</h2>
      <p className="sga-texto">
        Ayudantías, investigación, extensión y otros proyectos que los alumnos cargan en su legajo. Al validarlos figuran con ✓
        en su registro; al rechazarlos, el alumno ve el motivo y puede corregirlos.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <h3 className="sga-subtitulo">Pendientes de validación ({pendientes.length})</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Alumno</th><th>Proyecto</th><th>Cargado</th><th>Acciones</th></tr></thead>
          <tbody>
            {pendientes.length > 0 ? pendientes.map((p) => (
              <tr key={p.id}>
                <td>{p.apellido}, {p.nombre}<div className="sga-ayuda">{p.numero_legajo}</div></td>
                <td><Detalle p={p} /></td>
                <td>{fechaHora(p.fecha_carga)}</td>
                <td className="sga-acciones-doc">
                  <form action={revisarProyecto}>
                    <input name="id" type="hidden" value={p.id} />
                    <button name="decision" type="submit" value="validar">Validar</button>
                  </form>
                  <form action={revisarProyecto}>
                    <input name="id" type="hidden" value={p.id} />
                    <input aria-label="Motivo del rechazo" name="observaciones" placeholder="Motivo del rechazo" required />
                    <button className="sga-boton-peligro" name="decision" type="submit" value="rechazar">Rechazar</button>
                  </form>
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={4}>No hay proyectos pendientes de validación.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Revisados recientemente</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Alumno</th><th>Proyecto</th><th>Estado</th><th>Observaciones</th></tr></thead>
          <tbody>
            {revisados.length > 0 ? revisados.map((p) => (
              <tr key={p.id}>
                <td>{p.apellido}, {p.nombre}<div className="sga-ayuda">{p.numero_legajo}</div></td>
                <td><Detalle p={p} /></td>
                <td><span className={estadosProyecto[p.estado].clase}>{estadosProyecto[p.estado].texto}</span></td>
                <td>{p.observaciones}</td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={4}>Todavía no se revisó ningún proyecto.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
