import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";
import { agregarMiembro, cambiarActiva, crearOrganizacion, quitarMiembro } from "./actions";

type Organizacion = {
  id: number;
  nombre: string;
  descripcion: string | null;
  activa: boolean;
  organizacion_miembro: { persona: { id: number; nombre: string; apellido: string; mail_institucional: string } | null }[];
};

// Alta de organizaciones estudiantiles y de quiénes publican en su nombre
// en Hoy en el ITBA.
export default async function Organizaciones({ searchParams }: PageProps<"/administracion/organizaciones">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();

  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Organizaciones estudiantiles</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const { data: organizaciones } = await supabase
    .schema("sga")
    .from("organizacion")
    .select("id, nombre, descripcion, activa, organizacion_miembro(persona:persona_id(id, nombre, apellido, mail_institucional))")
    .order("nombre")
    .returns<Organizacion[]>();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Organizaciones estudiantiles</h2>
      <p className="sga-texto">Los miembros de cada organización pueden publicar eventos y novedades en Hoy en el ITBA.</p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Organización</th><th>Miembros</th><th>Agregar miembro</th><th>Estado</th></tr></thead>
          <tbody>
            {organizaciones && organizaciones.length > 0 ? organizaciones.map((o) => (
              <tr key={o.id}>
                <td className="sga-curso">
                  <strong>{o.nombre}</strong>
                  {o.descripcion && <div className="sga-ayuda">{o.descripcion}</div>}
                </td>
                <td className="sga-acciones-doc">
                  {o.organizacion_miembro.length > 0 ? o.organizacion_miembro.flatMap((m) => m.persona ? [m.persona] : [])
                    .sort((a, b) => a.apellido.localeCompare(b.apellido))
                    .map((p) => (
                      <form action={quitarMiembro} key={p.id}>
                        <input name="organizacion_id" type="hidden" value={o.id} />
                        <input name="persona_id" type="hidden" value={p.id} />
                        <span>{p.apellido}, {p.nombre} ({p.mail_institucional})</span>
                        <button className="sga-boton-peligro" type="submit">Quitar</button>
                      </form>
                    )) : <span className="sga-vacio">Sin miembros</span>}
                </td>
                <td className="sga-acciones-doc">
                  <form action={agregarMiembro}>
                    <input name="organizacion_id" type="hidden" value={o.id} />
                    <input aria-label="Mail institucional" name="mail" placeholder="mail@itba.edu.ar" required type="email" />
                    <button type="submit">Agregar</button>
                  </form>
                </td>
                <td className="sga-acciones-doc">
                  <form action={cambiarActiva}>
                    <input name="id" type="hidden" value={o.id} />
                    <input name="activa" type="hidden" value={o.activa ? "0" : "1"} />
                    <span>{o.activa ? "Activa" : "Inactiva"}</span>
                    <button className={o.activa ? "sga-boton-peligro" : undefined} type="submit">{o.activa ? "Desactivar" : "Reactivar"}</button>
                  </form>
                </td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={4}>Todavía no hay organizaciones cargadas.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Nueva organización</h3>
      <form action={crearOrganizacion} className="sga-form-publicacion">
        <label><span>Nombre</span><input name="nombre" required /></label>
        <label><span>Descripción</span><textarea name="descripcion" rows={3} /></label>
        <div className="sga-acciones-form"><button type="submit">Crear organización</button></div>
      </form>
    </section>
  );
}
