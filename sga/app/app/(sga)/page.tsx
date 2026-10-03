import { createClient } from "@/lib/supabase/server";
import { getCursosEnProgreso } from "@/lib/cursos";
import { getSesion } from "@/lib/sesion";

type Notificacion = { id: number; mensaje: string };
type Cronograma = { id: number; anio: number; nombre: string; url_archivo: string };

// Accesos de las cajas superiores; se convierten en links a medida que se
// implementa cada módulo.
const tareas = ["Iniciar nuevo trámite", "Ver historial de trámites"];
const tramites = ["Inscripción a exámenes finales", "Inscripción a eventos académicos"];

export default async function Inicio() {
  const sesion = await getSesion();
  if (!sesion) return null;

  const supabase = await createClient();
  const sga = supabase.schema("sga");

  const [{ data: notificaciones }, { data: cronogramas }, cursos] = await Promise.all([
    sga
      .from("notificacion")
      .select("id, mensaje")
      .eq("persona_id", sesion.persona?.id ?? 0)
      .eq("leida", false)
      .order("fecha", { ascending: false })
      .limit(5)
      .returns<Notificacion[]>(),
    sga
      .from("cronograma_academico")
      .select("id, anio, nombre, url_archivo")
      .order("anio", { ascending: false })
      .returns<Cronograma[]>(),
    getCursosEnProgreso(sesion),
  ]);

  return (
    <>
      {!sesion.persona && (
        <section className="sga-panel sga-aviso">
          Tu usuario ({sesion.email}) no está vinculado a ninguna persona del sistema.
          Pedile a Administración que cargue tus datos con este mismo mail.
        </section>
      )}

      <section className="sga-panel sga-cajas">
        <div className="sga-caja">
          <h3>Notificaciones</h3>
          {notificaciones && notificaciones.length > 0 ? (
            <ul>{notificaciones.map((n) => <li key={n.id}>{n.mensaje}</li>)}</ul>
          ) : (
            <p className="sga-vacio">Sin notificaciones pendientes</p>
          )}
        </div>
        <div className="sga-caja">
          <h3>Tareas</h3>
          <ul>{tareas.map((t) => <li key={t}><span className="sga-proximamente" title="Próximamente">{t}</span></li>)}</ul>
        </div>
        <div className="sga-caja">
          <h3>Trámites</h3>
          <ul>{tramites.map((t) => <li key={t}><span className="sga-proximamente" title="Próximamente">{t}</span></li>)}</ul>
        </div>
      </section>

      <section className="sga-panel">
        <h2 className="sga-titulo">Cronogramas Académicos</h2>
        {cronogramas && cronogramas.length > 0 ? (
          <ul className="sga-cronogramas">
            {cronogramas.map((c) => (
              <li key={c.id}>
                <a href={c.url_archivo} rel="noreferrer" target="_blank">{c.nombre.toUpperCase()}</a>
              </li>
            ))}
          </ul>
        ) : (
          <p className="sga-vacio">No hay cronogramas cargados.</p>
        )}
      </section>

      <section className="sga-panel">
        <h2 className="sga-titulo">Cursos en progreso</h2>
        {cursos.length > 0 ? (
          <div className="sga-tabla-scroll">
            <table className="sga-tabla">
              <thead>
                <tr><th>Curso</th><th>Horarios</th></tr>
              </thead>
              <tbody>
                {cursos.map((curso) => (
                  <tr key={curso.id}>
                    <td className="sga-curso">{curso.codigo} - {curso.nombre}</td>
                    <td className="sga-horarios">
                      {curso.comisiones.map((comision) => (
                        <div key={comision.nombre}>
                          <strong>{comision.nombre}</strong>{" "}
                          {comision.horarios.length > 0 ? comision.horarios.join(" | ") : "Sin horarios cargados"}
                        </div>
                      ))}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="sga-vacio">No tenés cursos en progreso.</p>
        )}
      </section>
    </>
  );
}
