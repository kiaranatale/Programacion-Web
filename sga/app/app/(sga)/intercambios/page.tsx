import { createClient } from "@/lib/supabase/server";
import { fechaHora, hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { requisitos, resultadosIntercambio, type Convocatoria, type ResultadoIntercambio } from "@/lib/intercambios";
import { postularme, retirarme } from "./actions";

type Fila = Omit<Convocatoria, "id"> & {
  convocatoria_id: number;
  postulantes: number;
  postulacion_id: number | null;
  postulacion_fecha: string | null;
  resultado: ResultadoIntercambio | null;
  motivo: string | null;
};

// Ver intercambio/s: mis postulaciones y las convocatorias abiertas.
export default async function Intercambios({ searchParams }: PageProps<"/intercambios">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data }] = await Promise.all([
    sga.rpc("intercambios_para_mi"),
    sga.from("notificacion").update({ leida: true }).eq("persona_id", sesion?.persona?.id ?? 0).eq("tipo", "INTERCAMBIO").eq("leida", false),
  ]);
  const filas = (data ?? []) as Fila[];
  const hoyStr = hoy();
  const mias = filas.filter((f) => f.postulacion_id);
  const abiertas = filas.filter((f) => !f.postulacion_id && !f.resultados_publicados && f.postulacion_hasta >= hoyStr);
  const lugar = (f: Fila) => [f.ciudad, f.pais].filter(Boolean).join(", ");

  return (
    <>
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Intercambios</h2>
        <p className="sga-texto">
          Programas de intercambio con universidades del exterior. Te podés postular a las convocatorias abiertas si cumplís los
          requisitos; al cerrar, Administración selecciona entre los postulantes y publica los resultados.
        </p>
        {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
        {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      </section>

      <section className="sga-panel">
        <h3 className="sga-titulo">Mis intercambios</h3>
        {mias.length === 0 ? (
          <p className="sga-vacio-grande">No te postulaste a ningún intercambio.</p>
        ) : (
          <div className="sga-tabla-scroll">
            <table className="sga-tabla sga-tabla-mensajes">
              <thead><tr><th>Universidad</th><th>Cuatrimestre</th><th>Postulación</th><th>Estado</th><th></th></tr></thead>
              <tbody>
                {mias.map((f) => {
                  const r = resultadosIntercambio[f.resultado ?? "PENDIENTE"];
                  const puedeRetirarse = !f.resultados_publicados && f.postulacion_hasta >= hoyStr;
                  return (
                    <tr key={f.convocatoria_id}>
                      <td><strong>{f.universidad}</strong><div className="sga-ayuda">{lugar(f)}</div></td>
                      <td>{periodo(f.anio, f.periodo)}</td>
                      <td>{f.postulacion_fecha && fechaHora(f.postulacion_fecha)}</td>
                      <td>
                        <span className={`sga-estado-encuesta ${r.clase}`}>{r.texto}</span>
                        {f.resultado === "PENDIENTE" && (
                          <div className="sga-ayuda">
                            {puedeRetirarse ? `La postulación cierra el ${fecha(f.postulacion_hasta)}` : "Esperando los resultados"}
                          </div>
                        )}
                      </td>
                      <td className="sga-acciones-doc">
                        {puedeRetirarse && (
                          <form action={retirarme}>
                            <input name="postulacion_id" type="hidden" value={f.postulacion_id ?? ""} />
                            <button className="sga-boton-peligro" type="submit">Retirarme</button>
                          </form>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="sga-panel">
        <h3 className="sga-titulo">Convocatorias abiertas</h3>
        {abiertas.length === 0 && <p className="sga-vacio-grande">No hay convocatorias abiertas.</p>}
        <ul className="sga-cv">
          {abiertas.map((f) => (
            <li key={f.convocatoria_id}>
              <div className="sga-cv-cabecera">
                <strong>{f.universidad} · {lugar(f)}</strong>
                <span className="sga-ayuda">{f.vacantes === 1 ? "1 vacante" : `${f.vacantes} vacantes`} · {f.postulantes} postulados</span>
              </div>
              <div className="sga-ayuda">
                {periodo(f.anio, f.periodo)} · Postulación del {fecha(f.postulacion_desde)} al {fecha(f.postulacion_hasta)} ·
                Requisitos: {requisitos(f)}
              </div>
              {f.descripcion && <p className="sga-cv-descripcion">{f.descripcion}</p>}
              {f.motivo ? (
                <p className="sga-ayuda"><strong>{f.motivo}</strong></p>
              ) : (
                <details className="sga-postulacion">
                  <summary>Postularme</summary>
                  <form action={postularme} className="sga-form-comentario">
                    <input name="convocatoria_id" type="hidden" value={f.convocatoria_id} />
                    <textarea
                      aria-label={`Carta de motivación para ${f.universidad}`}
                      maxLength={4000}
                      minLength={50}
                      name="motivacion"
                      placeholder="Carta de motivación: por qué querés hacer este intercambio (mínimo 50 caracteres)"
                      required
                      rows={5}
                    />
                    <div className="sga-acciones-form"><button type="submit">Enviar postulación</button></div>
                  </form>
                </details>
              )}
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}
