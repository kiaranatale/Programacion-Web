import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { formatearHorario, type HorarioRow } from "@/lib/cursos";
import { hoy } from "@/lib/hoy";
import { fecha, getLegajoActual, periodo } from "@/lib/legajo";
import { darmeDeBaja, inscribirme } from "./actions";

type Opcion = {
  comision_id: number;
  curso_id: number;
  anio: number;
  periodo: string;
  inscripcion_desde: string;
  inscripcion_hasta: string;
  codigo: string;
  materia: string;
  creditos: number;
  comision: string;
  cupo: number | null;
  inscriptos: number;
  inscripcion_id: number | null;
  motivo: string | null;
};
type Horario = HorarioRow & { comision_id: number };

// Inscripción a cursadas: comisiones de las materias del plan en los
// cuatrimestres con inscripción abierta. Una comisión por materia.
export default async function InscripcionCursadas({ searchParams }: PageProps<"/inscripciones/cursadas">) {
  const params = await searchParams;
  const q = typeof params.q === "string" ? params.q.trim() : "";
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data } = legajo ? await sga.rpc("cursadas_para_mi") : { data: [] };
  const todas = (data ?? []) as Opcion[];
  const { data: hs } = todas.length
    ? await sga.from("horario_comision")
        .select("comision_id, dia_semana, hora_inicio, hora_fin, modalidad, aula:aula_id(codigo, edificio:edificio_id(nombre))")
        .in("comision_id", todas.map((o) => o.comision_id))
        .returns<Horario[]>()
    : { data: [] };
  const horarios = new Map<number, Horario[]>();
  for (const h of hs ?? []) horarios.set(h.comision_id, [...(horarios.get(h.comision_id) ?? []), h]);

  const filtro = q.toLowerCase();
  const opciones = filtro ? todas.filter((o) => `${o.codigo} ${o.materia}`.toLowerCase().includes(filtro)) : todas;
  const mias = todas.filter((o) => o.inscripcion_id);
  const hoyStr = hoy();

  // Cuatrimestre → materia → comisiones
  const cuatrimestres = new Map<string, Map<string, Opcion[]>>();
  for (const o of opciones) {
    const clave = `${o.anio}-${o.periodo}`;
    const materias = cuatrimestres.get(clave) ?? new Map<string, Opcion[]>();
    materias.set(o.codigo, [...(materias.get(o.codigo) ?? []), o]);
    cuatrimestres.set(clave, materias);
  }

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Inscripción a cursadas</h2>
      <p className="sga-texto">
        Elegí <strong>una comisión por materia</strong>. Las vacantes se asignan por orden de inscripción y los horarios no se
        pueden superponer. Mientras la inscripción esté abierta te podés dar de baja o cambiar de comisión.
      </p>
      {typeof params.ok === "string" && <p className="sga-mensaje-ok" role="status">{params.ok}</p>}
      {typeof params.error === "string" && <p className="sga-mensaje-error" role="alert">{params.error}</p>}
      {!legajo && <p className="sga-vacio">No tenés un legajo de alumno asociado a tu usuario.</p>}

      {mias.length > 0 && (
        <div className="sga-caja sga-mis-inscripciones">
          <h3>Tus inscripciones</h3>
          <ul>
            {mias.map((o) => (
              <li key={o.comision_id}>
                <strong>{o.codigo}</strong> {o.materia} · Comisión {o.comision} ({periodo(o.anio, o.periodo)})
              </li>
            ))}
          </ul>
        </div>
      )}

      {legajo && todas.length > 0 && (
        <form className="sga-hoy-filtros">
          <input aria-label="Buscar materia" defaultValue={q} name="q" placeholder="Buscar por código o nombre" />
          <button type="submit">Buscar</button>
          {q && <Link href="/inscripciones/cursadas">Limpiar</Link>}
        </form>
      )}
      {legajo && todas.length === 0 && <p className="sga-vacio">No hay cuatrimestres con inscripción abierta.</p>}
      {legajo && todas.length > 0 && opciones.length === 0 && <p className="sga-vacio">Ninguna materia coincide con la búsqueda.</p>}

      {[...cuatrimestres.entries()].map(([clave, materias]) => {
        const primera = [...materias.values()][0][0];
        const abierta = hoyStr >= primera.inscripcion_desde && hoyStr <= primera.inscripcion_hasta;
        return (
          <div key={clave}>
            <h3 className="sga-subtitulo">
              {periodo(primera.anio, primera.periodo)}{" "}
              <span className={`sga-estado-encuesta ${abierta ? "sga-estado-activa" : hoyStr < primera.inscripcion_desde ? "sga-estado-programada" : "sga-estado-finalizada"}`}>
                {abierta ? "Inscripción abierta" : hoyStr < primera.inscripcion_desde ? "Próximamente" : "Inscripción cerrada"}
              </span>
            </h3>
            <p className="sga-ayuda">Inscripción del {fecha(primera.inscripcion_desde)} al {fecha(primera.inscripcion_hasta)}.</p>
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-mensajes">
                <thead><tr><th>Materia</th><th>Comisión</th><th>Horarios</th><th>Vacantes</th><th>Estado</th></tr></thead>
                <tbody>
                  {[...materias.values()].flatMap((comisiones) => comisiones.map((o, i) => (
                    <tr className={o.inscripcion_id ? "sga-fila-anotado" : undefined} key={o.comision_id}>
                      {i === 0 && (
                        <td rowSpan={comisiones.length}>
                          <Link href={`/cursos/${o.curso_id}`}><strong>{o.codigo}</strong> - {o.materia}</Link>
                          <div className="sga-ayuda">{o.creditos} créditos</div>
                        </td>
                      )}
                      <td className="sga-col-cupo"><strong>{o.comision}</strong></td>
                      <td className="sga-horarios">
                        {(horarios.get(o.comision_id) ?? []).map((h) => <div key={`${h.dia_semana}${h.hora_inicio}`}>{formatearHorario(h)}</div>)}
                        {!horarios.get(o.comision_id)?.length && <span className="sga-ayuda">Sin horarios cargados</span>}
                      </td>
                      <td className="sga-col-cupo">{o.cupo === null ? "Sin cupo" : Math.max(o.cupo - o.inscriptos, 0)}</td>
                      <td className="sga-acciones-doc">
                        {o.inscripcion_id ? (
                          <>
                            <strong className="sga-al-dia">Inscripto ✓</strong>
                            {abierta && (
                              <form action={darmeDeBaja}>
                                <input name="inscripcion_id" type="hidden" value={o.inscripcion_id} />
                                <input name="materia" type="hidden" value={`${o.codigo} ${o.materia}`} />
                                <input name="q" type="hidden" value={q} />
                                <button className="sga-boton-peligro" type="submit">Darme de baja</button>
                              </form>
                            )}
                          </>
                        ) : o.motivo ? (
                          <span className="sga-ayuda">{o.motivo}</span>
                        ) : (
                          <form action={inscribirme}>
                            <input name="comision_id" type="hidden" value={o.comision_id} />
                            <input name="materia" type="hidden" value={`${o.codigo} ${o.materia}`} />
                            <input name="q" type="hidden" value={q} />
                            <button type="submit">Inscribirme</button>
                          </form>
                        )}
                      </td>
                    </tr>
                  )))}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}
    </section>
  );
}
