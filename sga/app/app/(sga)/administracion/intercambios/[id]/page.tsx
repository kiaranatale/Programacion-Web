import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora, hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { requisitos, type Convocatoria } from "@/lib/intercambios";
import { marcarPostulacion, publicarResultados } from "../actions";

type Postulante = {
  postulacion_id: number;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  carrera: string | null;
  creditos_aprobados: number;
  rendimiento: number | null;
  motivacion: string;
  fecha: string;
  estado: "PENDIENTE" | "SELECCIONADA" | "NO_SELECCIONADA";
};

const etiqueta = {
  PENDIENTE: { texto: "Sin decidir", clase: "sga-estado-programada" },
  SELECCIONADA: { texto: "Seleccionado/a", clase: "sga-estado-activa" },
  NO_SELECCIONADA: { texto: "No seleccionado/a", clase: "sga-estado-finalizada" },
};

// Postulantes de una convocatoria: selección y publicación de resultados.
export default async function PostulantesDeIntercambio({ params, searchParams }: PageProps<"/administracion/intercambios/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Postulantes</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: c }, { data }] = await Promise.all([
    sga.from("convocatoria_intercambio").select("*").eq("id", id).maybeSingle<Convocatoria>(),
    sga.rpc("postulantes_intercambio", { p_convocatoria_id: id }),
  ]);
  if (!c) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Postulantes</h2>
        <p className="sga-error">La convocatoria no existe.</p>
        <Link className="sga-volver" href="/administracion/intercambios">← Volver a Intercambios</Link>
      </section>
    );
  }
  const postulantes = (data ?? []) as Postulante[];
  const cerrada = hoy() > c.postulacion_hasta;
  const editable = cerrada && !c.resultados_publicados;
  const seleccionados = postulantes.filter((p) => p.estado === "SELECCIONADA").length;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{c.universidad} · {periodo(c.anio, c.periodo)}</h2>
      <p className="sga-texto">
        {c.vacantes === 1 ? "1 vacante" : `${c.vacantes} vacantes`} · Requisitos: {requisitos(c)} · Postulación del{" "}
        {fecha(c.postulacion_desde)} al {fecha(c.postulacion_hasta)}
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {c.resultados_publicados ? (
        <p className="sga-mensaje-ok">Los resultados están publicados y los postulantes ya fueron notificados.</p>
      ) : !cerrada ? (
        <p className="sga-ayuda">La selección se hace cuando cierra la postulación (el {fecha(c.postulacion_hasta)}).</p>
      ) : (
        <div className="sga-form-fecha-final">
          <form action={publicarResultados}>
            <input name="convocatoria_id" type="hidden" value={c.id} />
            <button type="submit">Publicar resultados</button>
          </form>
          <span className={seleccionados > c.vacantes ? "sga-mensaje-error" : "sga-ayuda"}>
            {seleccionados} seleccionados de {c.vacantes} vacantes. Al publicar, los que no marcaste quedan como no seleccionados.
          </span>
        </div>
      )}

      <p className="sga-ayuda">Ordenados por promedio y después por créditos aprobados.</p>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Alumno</th><th>Créditos</th><th>Promedio</th><th>Carta de motivación</th><th>Estado</th>{editable && <th></th>}</tr></thead>
          <tbody>
            {postulantes.length > 0 ? postulantes.map((p) => (
              <tr key={p.postulacion_id}>
                <td>
                  {p.apellido}, {p.nombre}
                  <div className="sga-ayuda">{p.numero_legajo}{p.carrera && ` · ${p.carrera}`}</div>
                  <div className="sga-ayuda">{fechaHora(p.fecha)}</div>
                </td>
                <td>{p.creditos_aprobados}</td>
                <td>{p.rendimiento ?? "—"}</td>
                <td className="sga-cv-descripcion">{p.motivacion}</td>
                <td><span className={`sga-estado-encuesta ${etiqueta[p.estado].clase}`}>{etiqueta[p.estado].texto}</span></td>
                {editable && (
                  <td className="sga-acciones-doc">
                    <form action={marcarPostulacion}>
                      <input name="convocatoria_id" type="hidden" value={c.id} />
                      <input name="postulacion_id" type="hidden" value={p.postulacion_id} />
                      {p.estado !== "SELECCIONADA" && <button name="seleccionada" type="submit" value="true">Seleccionar</button>}
                      {p.estado !== "NO_SELECCIONADA" && <button className="sga-boton-peligro" name="seleccionada" type="submit" value="false">No seleccionar</button>}
                    </form>
                  </td>
                )}
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={editable ? 6 : 5}>Nadie se postuló.</td></tr>}
          </tbody>
        </table>
      </div>
      <Link className="sga-volver" href="/administracion/intercambios">← Volver a Intercambios</Link>
    </section>
  );
}
