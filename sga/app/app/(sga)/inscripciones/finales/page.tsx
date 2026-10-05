import { createClient } from "@/lib/supabase/server";
import { diaYHora, type FinalParaMi } from "@/lib/finales";
import { fechaHora, hoy } from "@/lib/hoy";
import { fecha, getLegajoActual } from "@/lib/legajo";
import { anotarme, darmeDeBaja } from "./actions";

// Inscripción a exámenes finales: por turno, las fechas de las materias
// con cursada aprobada. Una fecha por materia y turno; cierra 48 h antes.
export default async function InscripcionFinales({ searchParams }: PageProps<"/inscripciones/finales">) {
  const { ok, error } = await searchParams;
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const { data } = legajo ? await supabase.schema("sga").rpc("finales_para_mi") : { data: [] };
  const finales = (data ?? []) as FinalParaMi[];
  const ahora = new Date().toISOString();
  const hoyStr = hoy();

  const turnos = new Map<string, FinalParaMi[]>();
  for (const f of finales) turnos.set(f.turno, [...(turnos.get(f.turno) ?? []), f]);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Inscripción a exámenes finales</h2>
      <p className="sga-texto">
        Te podés anotar a <strong>una fecha por materia en cada turno</strong>, mientras la inscripción del turno esté abierta y
        hasta <strong>48 horas antes</strong> del examen. Hasta ese momento también te podés dar de baja.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {!legajo && <p className="sga-vacio">No tenés un legajo de alumno asociado a tu usuario.</p>}
      {legajo && turnos.size === 0 && (
        <p className="sga-vacio">No hay fechas de final para las materias que tenés con la cursada aprobada.</p>
      )}

      {[...turnos.entries()].map(([turno, fechas]) => {
        const { inscripcion_desde: desde, inscripcion_hasta: hasta } = fechas[0];
        const abierto = hoyStr >= desde && hoyStr <= hasta;
        return (
          <div key={turno}>
            <h3 className="sga-subtitulo">
              Turno {turno}{" "}
              <span className={`sga-estado-encuesta ${abierto ? "sga-estado-activa" : hoyStr < desde ? "sga-estado-programada" : "sga-estado-finalizada"}`}>
                {abierto ? "Inscripción abierta" : hoyStr < desde ? "Próximamente" : "Inscripción cerrada"}
              </span>
            </h3>
            <p className="sga-ayuda">Inscripción del {fecha(desde)} al {fecha(hasta)}.</p>
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-mensajes">
                <thead><tr><th>Materia</th><th>Fecha</th><th>Aula</th><th>Cierre de inscripción</th><th>Estado</th></tr></thead>
                <tbody>
                  {fechas.map((f) => {
                    const cerrada = ahora >= f.cierre;
                    return (
                      <tr className={f.inscripcion_id ? "sga-fila-anotado" : undefined} key={f.examen_final_id}>
                        <td><strong>{f.codigo}</strong> - {f.materia}</td>
                        <td>{diaYHora(f.fecha, f.hora_inicio)}</td>
                        <td>{f.aula ?? "A confirmar"}</td>
                        <td className="sga-ayuda">{fechaHora(f.cierre)}</td>
                        <td className="sga-acciones-doc">
                          {f.inscripcion_id ? (
                            <>
                              <strong className="sga-al-dia">Anotado ✓</strong>
                              {!cerrada && (
                                <form action={darmeDeBaja}>
                                  <input name="inscripcion_id" type="hidden" value={f.inscripcion_id} />
                                  <button className="sga-boton-peligro" type="submit">Darme de baja</button>
                                </form>
                              )}
                            </>
                          ) : f.motivo ? (
                            <span className="sga-ayuda">{f.motivo}</span>
                          ) : (
                            <form action={anotarme}>
                              <input name="examen_final_id" type="hidden" value={f.examen_final_id} />
                              <button type="submit">Anotarme</button>
                            </form>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}
    </section>
  );
}
