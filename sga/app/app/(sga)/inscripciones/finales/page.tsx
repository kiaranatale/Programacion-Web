import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { diaYHora, type FinalParaMi } from "@/lib/finales";
import { fechaHora, hoy } from "@/lib/hoy";
import { fecha, getLegajoActual } from "@/lib/legajo";
import { anotarme, darmeDeBaja } from "./actions";

// Inscripción a exámenes finales, como en el SGA: arriba los exámenes en
// los que estoy inscripto (aunque ya los haya rendido, mientras no tengan
// nota) y abajo los relacionados con mis cursadas aprobadas, por turno.
// Una fecha por materia y turno; la inscripción cierra 48 h antes.
export default async function InscripcionFinales({ searchParams }: PageProps<"/inscripciones/finales">) {
  const { ok, error } = await searchParams;
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const hoyStr = hoy();
  const [{ data }, { data: conResultado }, { count: impagas }] = legajo
    ? await Promise.all([
        sga.rpc("finales_para_mi"),
        sga.from("inscripcion_examen_final").select("id").or("nota_final.not.is.null,ausente.eq.true").returns<{ id: number }[]>(),
        sga.from("factura").select("id", { count: "exact", head: true }).eq("legajo_id", legajo.id)
          .or(`estado.eq.VENCIDA,and(estado.eq.PENDIENTE,fecha_vencimiento.lt.${hoyStr})`),
      ])
    : [{ data: [] }, { data: [] }, { count: 0 }];
  const finales = (data ?? []) as FinalParaMi[];
  const rendidos = new Set((conResultado ?? []).map((r) => r.id));
  const ahora = new Date().toISOString();

  const inscripto = finales.filter((f) => f.inscripcion_id && !rendidos.has(f.inscripcion_id));
  const turnos = new Map<string, FinalParaMi[]>();
  for (const f of finales.filter((f) => !f.inscripcion_id && f.fecha >= hoyStr)) {
    turnos.set(f.turno, [...(turnos.get(f.turno) ?? []), f]);
  }

  return (
    <>
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Inscripción a exámenes finales</h2>
        <p className="sga-alerta">Recuerde que para rendir exámenes finales debe estar al día con las cuotas.</p>
        {(impagas ?? 0) > 0 && (
          <p className="sga-mensaje-error">
            Tenés {impagas === 1 ? "1 factura vencida" : `${impagas} facturas vencidas`}.{" "}
            <Link href="/legajo/estado-de-cuenta">Ver estado de cuenta</Link>
          </p>
        )}
        {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
        {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
        {!legajo && <p className="sga-vacio">No tenés un legajo de alumno asociado a tu usuario.</p>}
      </section>

      {legajo && (
        <section className="sga-panel">
          <h3 className="sga-titulo">Exámenes en los que se encuentra inscripto</h3>
          <p className="sga-ayuda">
            En este listado se muestran los exámenes en los que usted está inscripto, incluyendo aquellos ya rendidos que aún no
            han sido rubricados por el docente.
          </p>
          {inscripto.length === 0 ? (
            <p className="sga-vacio-grande">Usted no está inscripto en ningún examen final.</p>
          ) : (
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-mensajes">
                <thead><tr><th>Materia</th><th>Turno</th><th>Fecha</th><th>Aula</th><th>Cierre de inscripción</th><th></th></tr></thead>
                <tbody>
                  {inscripto.map((f) => (
                    <tr className="sga-fila-anotado" key={f.examen_final_id}>
                      <td><strong>{f.codigo}</strong> - {f.materia}</td>
                      <td>{f.turno}</td>
                      <td>{diaYHora(f.fecha, f.hora_inicio)}</td>
                      <td>{f.aula ?? "A confirmar"}</td>
                      <td className="sga-ayuda">{fechaHora(f.cierre)}</td>
                      <td className="sga-acciones-doc">
                        {f.fecha < hoyStr ? (
                          <span className="sga-ayuda">Rendido, sin nota todavía</span>
                        ) : ahora < f.cierre ? (
                          <form action={darmeDeBaja}>
                            <input name="inscripcion_id" type="hidden" value={f.inscripcion_id ?? ""} />
                            <button className="sga-boton-peligro" type="submit">Darme de baja</button>
                          </form>
                        ) : (
                          <span className="sga-ayuda">Inscripción cerrada</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {legajo && (
        <section className="sga-panel">
          <h3 className="sga-titulo">Exámenes relacionados</h3>
          <p className="sga-ayuda">
            En este listado se muestran los exámenes relacionados a las materias cursadas pero aún no aprobadas. Te podés anotar
            a <strong>una fecha por materia en cada turno</strong>, desde que Administración abre la inscripción del turno y hasta
            {" "}<strong>48 horas antes</strong> del examen.
          </p>
          {turnos.size === 0 && <p className="sga-vacio-grande">No hay exámenes pendientes a rendir.</p>}
          {[...turnos.entries()].map(([turno, fechas]) => {
            const { inscripcion_desde: desde, inscripcion_hasta: hasta } = fechas[0];
            const abierto = hoyStr >= desde && hoyStr <= hasta;
            return (
              <div key={turno}>
                <h4 className="sga-subtitulo">
                  Turno {turno}{" "}
                  <span className={`sga-estado-encuesta ${abierto ? "sga-estado-activa" : hoyStr < desde ? "sga-estado-programada" : "sga-estado-finalizada"}`}>
                    {abierto ? "Inscripción abierta" : hoyStr < desde ? "Próximamente" : "Inscripción cerrada"}
                  </span>
                </h4>
                <p className="sga-ayuda">Inscripción del {fecha(desde)} al {fecha(hasta)}.</p>
                <div className="sga-tabla-scroll">
                  <table className="sga-tabla sga-tabla-mensajes">
                    <thead><tr><th>Materia</th><th>Fecha</th><th>Aula</th><th>Cierre de inscripción</th><th></th></tr></thead>
                    <tbody>
                      {fechas.map((f) => (
                        <tr key={f.examen_final_id}>
                          <td><strong>{f.codigo}</strong> - {f.materia}</td>
                          <td>{diaYHora(f.fecha, f.hora_inicio)}</td>
                          <td>{f.aula ?? "A confirmar"}</td>
                          <td className="sga-ayuda">{fechaHora(f.cierre)}</td>
                          <td className="sga-acciones-doc">
                            {f.motivo ? (
                              <span className="sga-ayuda">{f.motivo}</span>
                            ) : (
                              <form action={anotarme}>
                                <input name="examen_final_id" type="hidden" value={f.examen_final_id} />
                                <button type="submit">Anotarme</button>
                              </form>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            );
          })}
        </section>
      )}
    </>
  );
}
