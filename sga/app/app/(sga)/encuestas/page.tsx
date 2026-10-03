import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { estados, tiposEncuesta, type EncuestaParaMi, type EncuestaResumen } from "@/lib/encuestas";
import { fecha } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { finalizarEncuesta, generarEncuestasDesempeno } from "./actions";

const Estado = ({ estado }: { estado: string }) => (
  <span className={`sga-estado-encuesta sga-estado-${estado.toLowerCase()}`}>{estados[estado] ?? estado}</span>
);

// Encuestas → General: las que me toca responder y, para docentes y
// Administración, el seguimiento de las encuestas con su participación.
export default async function Encuestas({ searchParams }: PageProps<"/encuestas">) {
  const sesion = await getSesion();
  if (!sesion) return null;
  const { ok, error } = await searchParams;
  const admin = sesion.roles.includes("ADMINISTRATIVO");
  const docente = sesion.roles.includes("DOCENTE") || sesion.roles.includes("AYUDANTE");

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: mias }, { data: resumen }] = await Promise.all([
    sga.rpc("encuestas_para_mi"),
    admin || docente ? sga.rpc("encuestas_resumen") : Promise.resolve({ data: [] }),
  ]);
  const paraMi = (mias ?? []) as EncuestaParaMi[];
  const seguimiento = (resumen ?? []) as EncuestaResumen[];

  return (
    <section className="sga-panel">
      <div className="sga-hoy-encabezado">
        <h2 className="sga-titulo sga-titulo-grande">Encuestas</h2>
        {admin && <Link className="sga-boton" href="/encuestas/nueva">+ Nueva encuesta general</Link>}
      </div>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {(paraMi.length > 0 || (!admin && !docente)) && (
        <>
          <h3 className="sga-subtitulo">Mis encuestas</h3>
          <p className="sga-texto">Las respuestas son anónimas: se guarda que respondiste, pero no qué respondiste.</p>
          <div className="sga-tabla-scroll">
            <table className="sga-tabla sga-tabla-mensajes">
              <thead><tr><th>Encuesta</th><th>Sobre</th><th>Desde</th><th>Hasta</th><th>Estado</th><th>Acción</th></tr></thead>
              <tbody>
                {paraMi.length > 0 ? paraMi.map((e) => (
                  <tr key={e.id}>
                    <td><strong>{e.nombre}</strong><div className="sga-ayuda">{tiposEncuesta[e.tipo]}</div></td>
                    <td>{e.sobre ?? "—"}</td>
                    <td className="sga-col-cupo">{fecha(e.fecha_inicio)}</td>
                    <td className="sga-col-cupo">{fecha(e.fecha_fin)}</td>
                    <td className="sga-col-cupo"><Estado estado={e.estado} /></td>
                    <td className="sga-col-cupo">
                      {e.respondida ? "Respondida ✓" : e.estado === "ACTIVA" ? <Link className="sga-boton" href={`/encuestas/${e.id}`}>Responder</Link> : "—"}
                    </td>
                  </tr>
                )) : (
                  <tr><td className="sga-vacio" colSpan={6}>No tenés encuestas.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}

      {(admin || docente) && (
        <>
          <h3 className="sga-subtitulo">{admin ? "Todas las encuestas" : "Encuestas de mis comisiones"}</h3>
          {!admin && (
            <p className="sga-texto">
              Los resultados se publican cuando la encuesta termina y la respondieron al menos 3 alumnos.
            </p>
          )}
          <div className="sga-tabla-scroll">
            <table className="sga-tabla sga-tabla-mensajes">
              <thead><tr><th>Encuesta</th><th>Sobre</th><th>Desde</th><th>Hasta</th><th>Estado</th><th>Respuestas</th><th>Acciones</th></tr></thead>
              <tbody>
                {seguimiento.length > 0 ? seguimiento.map((e) => (
                  <tr key={e.id}>
                    <td><strong>{e.nombre}</strong><div className="sga-ayuda">{tiposEncuesta[e.tipo]}</div></td>
                    <td>{e.sobre ?? "Todos los alumnos"}</td>
                    <td className="sga-col-cupo">{fecha(e.fecha_inicio)}</td>
                    <td className="sga-col-cupo">{fecha(e.fecha_fin)}</td>
                    <td className="sga-col-cupo"><Estado estado={e.estado} /></td>
                    <td className="sga-col-cupo">{e.respuestas}/{e.destinatarios}</td>
                    <td className="sga-acciones-doc">
                      {(admin || (e.estado === "FINALIZADA" && e.respuestas >= 3))
                        ? <Link href={`/encuestas/${e.id}/resultados`}>Ver resultados</Link>
                        : <span className="sga-ayuda">Resultados al cerrar</span>}
                      {admin && e.estado !== "FINALIZADA" && (
                        <form action={finalizarEncuesta}>
                          <input name="id" type="hidden" value={e.id} />
                          <button className="sga-boton-peligro" type="submit">Cerrar</button>
                        </form>
                      )}
                    </td>
                  </tr>
                )) : (
                  <tr><td className="sga-vacio" colSpan={7}>No hay encuestas.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}

      {admin && (
        <>
          <h3 className="sga-subtitulo">Generar encuestas de desempeño docente</h3>
          <p className="sga-texto">
            Crea una encuesta por cada docente de cada comisión de los cursos activos, con las preguntas estándar de
            desempeño. Las comisiones que ya tienen una encuesta con el mismo nombre se saltean.
          </p>
          <form action={generarEncuestasDesempeno} className="sga-form-publicacion">
            <label><span>Nombre</span><input defaultValue={`Desempeño docente - ${new Date().getMonth() < 6 ? "1C" : "2C"} ${new Date().getFullYear()}`} name="nombre" required /></label>
            <fieldset className="sga-fieldset-fechas">
              <legend>Período</legend>
              <label><span>Desde</span><input defaultValue={hoy()} name="desde" required type="date" /></label>
              <label><span>Hasta</span><input name="hasta" required type="date" /></label>
            </fieldset>
            <div className="sga-acciones-form"><button type="submit">Generar encuestas</button></div>
          </form>
        </>
      )}
    </section>
  );
}
