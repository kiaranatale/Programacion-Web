import { createClient } from "@/lib/supabase/server";
import { estadosAusencia, tiposAusencia, type Ausencia } from "@/lib/ausencias";
import { hoy } from "@/lib/hoy";
import { fecha } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import SinAcceso from "../sin-acceso";
import { cancelarAusencia, informarAusencia } from "./actions";

type Comision = { comision_id: number; codigo: string; materia: string; comision: string; activo: boolean };

const rango = (a: Ausencia) => (a.fecha_inicio === a.fecha_fin ? fecha(a.fecha_inicio) : `${fecha(a.fecha_inicio)} al ${fecha(a.fecha_fin)}`);

// Ausencias del docente: informar (avisa a los alumnos), ver su estado y cancelar.
export default async function MisAusencias({ searchParams }: PageProps<"/docencia/ausencias">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.some((r) => r === "DOCENTE" || r === "AYUDANTE")) return <SinAcceso titulo="Ausencias" />;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: ausenciasData }, { data: comisionesData }] = await Promise.all([
    sga.rpc("ausencias_docentes", { p_solo_mias: true }),
    sga.rpc("mis_comisiones"),
  ]);
  const ausencias = (ausenciasData ?? []) as Ausencia[];
  const comisiones = ((comisionesData ?? []) as Comision[]).filter((c) => c.activo);
  const hoyStr = hoy();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Ausencias</h2>
      <p className="sga-texto">
        Si vas a faltar, informalo acá: a los alumnos de las comisiones que elijas les llega el aviso de que no hay clase y lo
        ven en su calendario. Administración después la marca como justificada o no.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <h3 className="sga-subtitulo">Informar una ausencia</h3>
      {comisiones.length === 0 ? (
        <p className="sga-vacio">No tenés comisiones en cursos activos.</p>
      ) : (
        <form action={informarAusencia} className="sga-form-publicacion">
          <fieldset>
            <legend>Cuándo</legend>
            <label><span>Desde</span><input defaultValue={hoyStr} min={hoyStr} name="desde" required type="date" /></label>
            <label><span>Hasta</span><input defaultValue={hoyStr} min={hoyStr} name="hasta" required type="date" /></label>
            <label>
              <span>Tipo</span>
              <select defaultValue="" name="tipo" required>
                <option disabled value="">Elegí…</option>
                {Object.entries(tiposAusencia).map(([v, t]) => <option key={v} value={v}>{t}</option>)}
              </select>
            </label>
          </fieldset>
          <fieldset className="sga-roles">
            <legend>Comisiones sin clase</legend>
            {comisiones.map((c) => (
              <label key={c.comision_id}>
                <input defaultChecked={comisiones.length === 1} name="comision" type="checkbox" value={c.comision_id} /> {c.codigo} {c.materia} · {c.comision}
              </label>
            ))}
          </fieldset>
          <label>
            <span>Motivo (opcional, solo lo ve Administración)</span>
            <textarea maxLength={1000} name="motivo" rows={3} />
          </label>
          <div className="sga-acciones-form"><button type="submit">Informar y avisar a los alumnos</button></div>
        </form>
      )}

      <h3 className="sga-subtitulo">Mis ausencias</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Fechas</th><th>Tipo</th><th>Comisiones</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {ausencias.length > 0 ? ausencias.map((a) => (
              <tr key={a.id}>
                <td>{rango(a)}</td>
                <td>{tiposAusencia[a.tipo] ?? a.tipo}</td>
                <td>{a.comisiones}</td>
                <td>
                  <span className={`sga-estado-encuesta ${estadosAusencia[a.estado]?.clase ?? ""}`}>{estadosAusencia[a.estado]?.texto ?? a.estado}</span>
                  {a.observaciones && <div className="sga-ayuda">{a.observaciones}</div>}
                </td>
                <td className="sga-acciones-doc">
                  {a.estado === "INFORMADA" && a.fecha_inicio > hoyStr && (
                    <form action={cancelarAusencia}>
                      <input name="id" type="hidden" value={a.id} />
                      <button className="sga-boton-peligro" type="submit">Cancelar</button>
                    </form>
                  )}
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={5}>No informaste ausencias.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
