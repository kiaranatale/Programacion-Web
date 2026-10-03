import { createClient } from "@/lib/supabase/server";
import { estadosDocumento } from "@/lib/documentacion";
import { fecha } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { revisarDocumento } from "./actions";

type Doc = {
  id: number;
  nombre_archivo: string | null;
  ruta_archivo: string | null;
  estado: string;
  fecha_carga: string | null;
  fecha_revision: string | null;
  observaciones: string | null;
  documento: { nombre: string } | null;
  legajo: { numero_legajo: string; persona: { nombre: string; apellido: string } | null } | null;
};

const SELECT = `id, nombre_archivo, ruta_archivo, estado, fecha_carga, fecha_revision, observaciones,
  documento:documento_requerido_id(nombre),
  legajo:legajo_id(numero_legajo, persona:persona_id(nombre, apellido))`;

function Alumno({ d }: { d: Doc }) {
  return <>{d.legajo?.persona ? `${d.legajo.persona.apellido}, ${d.legajo.persona.nombre}` : "—"} ({d.legajo?.numero_legajo})</>;
}

function Archivo({ d }: { d: Doc }) {
  return d.ruta_archivo
    ? <a href={`/documentos/${d.id}`} rel="noreferrer" target="_blank">{d.nombre_archivo}</a>
    : <>{d.nombre_archivo}</>;
}

export default async function DocumentacionPendiente({ searchParams }: PageProps<"/administracion/documentacion">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();

  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Documentación pendiente</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: pendientes }, { data: revisados }] = await Promise.all([
    sga.from("documento_legajo").select(SELECT).eq("estado", "CARGADO")
      .order("fecha_carga", { ascending: true }).returns<Doc[]>(),
    sga.from("documento_legajo").select(SELECT).in("estado", ["VALIDADO", "RECHAZADO"])
      .not("fecha_revision", "is", null)
      .order("fecha_revision", { ascending: false }).limit(20).returns<Doc[]>(),
  ]);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Documentación pendiente</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <h3 className="sga-subtitulo">Pendientes de validación ({pendientes?.length ?? 0})</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Alumno</th><th>Documento</th><th>Archivo</th><th>Cargado</th><th>Acciones</th></tr></thead>
          <tbody>
            {pendientes && pendientes.length > 0 ? pendientes.map((d) => (
              <tr key={d.id}>
                <td><Alumno d={d} /></td>
                <td>{d.documento?.nombre}</td>
                <td><Archivo d={d} /></td>
                <td>{fecha(d.fecha_carga)}</td>
                <td className="sga-acciones-doc">
                  <form action={revisarDocumento}>
                    <input name="documento_legajo_id" type="hidden" value={d.id} />
                    <button name="decision" type="submit" value="aprobar">Aprobar</button>
                  </form>
                  <form action={revisarDocumento}>
                    <input name="documento_legajo_id" type="hidden" value={d.id} />
                    <input aria-label="Motivo del rechazo" name="observaciones" placeholder="Motivo del rechazo" required />
                    <button className="sga-boton-peligro" name="decision" type="submit" value="rechazar">Rechazar</button>
                  </form>
                </td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={5}>No hay documentación pendiente de validación.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Revisados recientemente</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Alumno</th><th>Documento</th><th>Archivo</th><th>Estado</th><th>Revisado</th><th>Observaciones</th></tr></thead>
          <tbody>
            {revisados && revisados.length > 0 ? revisados.map((d) => (
              <tr key={d.id}>
                <td><Alumno d={d} /></td>
                <td>{d.documento?.nombre}</td>
                <td><Archivo d={d} /></td>
                <td><span className={`sga-estado-${d.estado.toLowerCase()}`}>{estadosDocumento[d.estado] ?? d.estado}</span></td>
                <td>{fecha(d.fecha_revision)}</td>
                <td>{d.observaciones}</td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={6}>Todavía no se revisó documentación.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
