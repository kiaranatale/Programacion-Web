import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { requisitos, type Convocatoria } from "@/lib/intercambios";
import { borrarConvocatoria, crearConvocatoria } from "./actions";

type Fila = Convocatoria & { postulacion_intercambio: { count: number }[] };

function estado(c: Convocatoria, hoyStr: string) {
  if (c.resultados_publicados) return { texto: "Resultados publicados", clase: "sga-estado-finalizada" };
  if (hoyStr < c.postulacion_desde) return { texto: "Próximamente", clase: "sga-estado-programada" };
  if (hoyStr <= c.postulacion_hasta) return { texto: "Postulación abierta", clase: "sga-estado-activa" };
  return { texto: "A seleccionar", clase: "sga-estado-activa" };
}

// Convocatorias de intercambio: alta, estado y acceso a la selección.
export default async function ConvocatoriasDeIntercambio({ searchParams }: PageProps<"/administracion/intercambios">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Intercambios</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("convocatoria_intercambio")
    .select("*, postulacion_intercambio(count)").order("postulacion_hasta", { ascending: false }).returns<Fila[]>();
  const convocatorias = data ?? [];
  const hoyStr = hoy();
  const anio = Number(hoyStr.slice(0, 4));
  const cuatrimestres = [anio, anio + 1].flatMap((a) => [`${a}|1C`, `${a}|2C`]);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Intercambios</h2>
      <p className="sga-texto">
        Publicá las plazas en universidades del exterior. Cuando cierra la postulación, entrá a la convocatoria para elegir a
        los seleccionados y publicar los resultados.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Universidad</th><th>Cuatrimestre</th><th>Vacantes</th><th>Requisitos</th><th>Postulación</th><th>Postulantes</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {convocatorias.length > 0 ? convocatorias.map((c) => {
              const e = estado(c, hoyStr);
              const postulantes = c.postulacion_intercambio[0]?.count ?? 0;
              return (
                <tr key={c.id}>
                  <td><strong>{c.universidad}</strong><div className="sga-ayuda">{[c.ciudad, c.pais].filter(Boolean).join(", ")}</div></td>
                  <td>{periodo(c.anio, c.periodo)}</td>
                  <td>{c.vacantes}</td>
                  <td>{requisitos(c)}</td>
                  <td>Del {fecha(c.postulacion_desde)} al {fecha(c.postulacion_hasta)}</td>
                  <td>{postulantes}</td>
                  <td><span className={`sga-estado-encuesta ${e.clase}`}>{e.texto}</span></td>
                  <td className="sga-acciones-doc">
                    <Link href={`/administracion/intercambios/${c.id}`}>Postulantes</Link>
                    {postulantes === 0 && (
                      <form action={borrarConvocatoria}>
                        <input name="id" type="hidden" value={c.id} />
                        <button className="sga-boton-peligro" type="submit">Borrar</button>
                      </form>
                    )}
                  </td>
                </tr>
              );
            }) : <tr><td className="sga-vacio" colSpan={8}>Todavía no hay convocatorias.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Nueva convocatoria</h3>
      <form action={crearConvocatoria} className="sga-form-publicacion">
        <fieldset>
          <legend>Destino</legend>
          <label><span>Universidad</span><input maxLength={150} name="universidad" required /></label>
          <label><span>País</span><input maxLength={80} name="pais" required /></label>
          <label><span>Ciudad (opcional)</span><input maxLength={80} name="ciudad" /></label>
        </fieldset>
        <fieldset>
          <legend>Plazas y requisitos</legend>
          <label>
            <span>Cuatrimestre</span>
            <select defaultValue="" name="cuatrimestre" required>
              <option disabled value="">Elegí…</option>
              {cuatrimestres.map((c) => {
                const [a, p] = c.split("|");
                return <option key={c} value={c}>{periodo(Number(a), p)}</option>;
              })}
            </select>
          </label>
          <label><span>Vacantes</span><input min={1} name="vacantes" required type="number" /></label>
          <label><span>Créditos aprobados mínimos</span><input defaultValue={0} min={0} name="creditos_minimos" type="number" /></label>
        </fieldset>
        <fieldset>
          <legend>Postulación</legend>
          <label><span>Desde</span><input name="desde" required type="date" /></label>
          <label><span>Hasta</span><input name="hasta" required type="date" /></label>
          <label><span>Promedio mínimo (opcional)</span><input max={10} min={0} name="promedio_minimo" step="0.01" type="number" /></label>
        </fieldset>
        <label>
          <span>Descripción (opcional)</span>
          <textarea maxLength={2000} name="descripcion" placeholder="Idioma de cursada, materias reconocidas, documentación, etc." rows={3} />
        </label>
        <div className="sga-acciones-form"><button type="submit">Publicar convocatoria</button></div>
      </form>
    </section>
  );
}
