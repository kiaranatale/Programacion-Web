import { createClient } from "@/lib/supabase/server";
import { fecha } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { darDeBaja, designarAutoridad } from "./actions";

type Autoridad = {
  id: number;
  cargo: string;
  apellido: string;
  nombre: string;
  escuela: string | null;
  fecha_desde: string;
  fecha_hasta: string | null;
  vigente: boolean;
  cargo_orden: number;
  escuela_orden: number | null;
};

// "Director/a" + "Escuela de Posgrado" → "Director/a de Escuela de Posgrado"
const cargoCompleto = (a: Autoridad) => (a.escuela ? `${a.cargo} de ${a.escuela}` : a.cargo);

// Primero las institucionales y después cada escuela, en orden jerárquico.
function comparar(a: Autoridad, b: Autoridad) {
  return (a.escuela ? 1 : 0) - (b.escuela ? 1 : 0)
    || (a.escuela_orden ?? 0) - (b.escuela_orden ?? 0)
    || (a.escuela ?? "").localeCompare(b.escuela ?? "")
    || a.cargo_orden - b.cargo_orden
    || a.cargo.localeCompare(b.cargo)
    || a.apellido.localeCompare(b.apellido);
}

// Autoridades vigentes como en el SGA: cargo y nombre, las institucionales
// primero y después cada escuela. Administración designa y da de baja.
export default async function Autoridades({ searchParams }: PageProps<"/autoridades">) {
  const sesion = await getSesion();
  const admin = !!sesion?.roles.includes("ADMINISTRATIVO");
  const { ok, error } = await searchParams;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data }, { data: cargos }, { data: escuelas }] = await Promise.all([
    sga.from("autoridad_listado").select("*").returns<Autoridad[]>(),
    admin ? sga.from("cargo_institucional").select("id, nombre").order("orden").order("nombre").returns<{ id: number; nombre: string }[]>() : Promise.resolve({ data: [] }),
    admin ? sga.from("escuela").select("id, nombre").order("orden").order("nombre").returns<{ id: number; nombre: string }[]>() : Promise.resolve({ data: [] }),
  ]);
  const autoridades = [...(data ?? [])].sort(comparar);
  const vigentes = autoridades.filter((a) => a.vigente);
  const anteriores = autoridades.filter((a) => !a.vigente);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Autoridades</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {vigentes.length > 0 ? (
        <dl className="sga-autoridades">
          {vigentes.map((a) => (
            <div key={a.id}>
              <dt>{cargoCompleto(a)}</dt>
              <dd>
                <strong>{a.apellido}, {a.nombre}</strong>
                {admin && (
                  <form action={darDeBaja}>
                    <input name="id" type="hidden" value={a.id} />
                    <button className="sga-boton-peligro" type="submit">Dar de baja</button>
                  </form>
                )}
              </dd>
            </div>
          ))}
        </dl>
      ) : <p className="sga-vacio">Todavía no hay autoridades cargadas.</p>}

      {admin && anteriores.length > 0 && (
        <details className="sga-detalles">
          <summary>Autoridades anteriores ({anteriores.length})</summary>
          <div className="sga-tabla-scroll">
            <table className="sga-tabla">
              <thead>
                <tr><th>Cargo</th><th>Nombre</th><th>Período</th></tr>
              </thead>
              <tbody>
                {anteriores.map((a) => (
                  <tr key={a.id}>
                    <td>{cargoCompleto(a)}</td>
                    <td>{a.apellido}, {a.nombre}</td>
                    <td className="sga-col-cupo">{fecha(a.fecha_desde)} – {fecha(a.fecha_hasta)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </details>
      )}

      {admin && (
        <>
          <h3 className="sga-subtitulo">Designar autoridad</h3>
          <form action={designarAutoridad} className="sga-form-publicacion">
            <label>
              <span>Cargo</span>
              <select defaultValue="" name="cargo_id">
                <option value="">Elegí un cargo…</option>
                {(cargos ?? []).map((c) => <option key={c.id} value={c.id}>{c.nombre}</option>)}
              </select>
              <input name="cargo_nuevo" placeholder="…o escribí un cargo nuevo" />
            </label>
            <label>
              <span>Mail institucional de la persona</span>
              <input name="mail" required type="email" />
            </label>
            <label>
              <span>Escuela</span>
              <select defaultValue="" name="escuela_id">
                <option value="">Ninguna (autoridad institucional)</option>
                {(escuelas ?? []).map((e) => <option key={e.id} value={e.id}>{e.nombre}</option>)}
              </select>
            </label>
            <label>
              <span>Desde</span>
              <input defaultValue={hoy()} name="desde" required type="date" />
            </label>
            <div className="sga-acciones-form"><button type="submit">Designar</button></div>
          </form>
        </>
      )}
    </section>
  );
}
