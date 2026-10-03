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
  mail_institucional: string;
  escuela: string | null;
  fecha_desde: string;
  fecha_hasta: string | null;
  vigente: boolean;
};

function Tabla({ autoridades, admin, historico }: { autoridades: Autoridad[]; admin: boolean; historico?: boolean }) {
  return (
    <div className="sga-tabla-scroll">
      <table className="sga-tabla sga-tabla-mensajes">
        <thead>
          <tr>
            <th>Cargo</th><th>Nombre</th><th>Mail</th><th>{historico ? "Período" : "Desde"}</th>
            {admin && !historico && <th>Acciones</th>}
          </tr>
        </thead>
        <tbody>
          {autoridades.map((a) => (
            <tr key={a.id}>
              <td><strong>{a.cargo}</strong></td>
              <td>{a.apellido}, {a.nombre}</td>
              <td><a href={`mailto:${a.mail_institucional}`}>{a.mail_institucional}</a></td>
              <td className="sga-col-cupo">{historico ? `${fecha(a.fecha_desde)} – ${fecha(a.fecha_hasta)}` : fecha(a.fecha_desde)}</td>
              {admin && !historico && (
                <td className="sga-acciones-doc">
                  <form action={darDeBaja}>
                    <input name="id" type="hidden" value={a.id} />
                    <button className="sga-boton-peligro" type="submit">Dar de baja</button>
                  </form>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Autoridades vigentes: las institucionales y las de cada escuela.
// Administración designa y da de baja.
export default async function Autoridades({ searchParams }: PageProps<"/autoridades">) {
  const sesion = await getSesion();
  const admin = !!sesion?.roles.includes("ADMINISTRATIVO");
  const { ok, error } = await searchParams;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data }, { data: cargos }, { data: escuelas }] = await Promise.all([
    sga.from("autoridad_listado").select("*").order("cargo").order("apellido").returns<Autoridad[]>(),
    admin ? sga.from("cargo_institucional").select("id, nombre").order("nombre").returns<{ id: number; nombre: string }[]>() : Promise.resolve({ data: [] }),
    admin ? sga.from("escuela").select("id, nombre").order("nombre").returns<{ id: number; nombre: string }[]>() : Promise.resolve({ data: [] }),
  ]);
  const autoridades = data ?? [];
  const vigentes = autoridades.filter((a) => a.vigente);
  const grupos = new Map<string, Autoridad[]>();
  for (const a of vigentes) {
    const grupo = a.escuela ?? "Autoridades institucionales";
    grupos.set(grupo, [...(grupos.get(grupo) ?? []), a]);
  }
  const orden = [...grupos.keys()].sort((a, b) =>
    a === "Autoridades institucionales" ? -1 : b === "Autoridades institucionales" ? 1 : a.localeCompare(b));
  const anteriores = autoridades.filter((a) => !a.vigente);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Autoridades</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {orden.length > 0 ? orden.map((g) => (
        <div key={g}>
          <h3 className="sga-subtitulo">{g}</h3>
          <Tabla admin={admin} autoridades={grupos.get(g)!} />
        </div>
      )) : <p className="sga-vacio">Todavía no hay autoridades cargadas.</p>}

      {admin && anteriores.length > 0 && (
        <details className="sga-detalles">
          <summary>Autoridades anteriores ({anteriores.length})</summary>
          <Tabla admin historico autoridades={anteriores} />
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
