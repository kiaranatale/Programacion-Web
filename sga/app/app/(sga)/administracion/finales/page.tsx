import { createClient } from "@/lib/supabase/server";
import { diaYHora } from "@/lib/finales";
import { fecha } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { agregarFecha, borrarFecha, crearTurno } from "./actions";

type Turno = {
  id: number;
  nombre: string;
  inscripcion_desde: string;
  inscripcion_hasta: string;
  examen_final: {
    id: number;
    fecha: string;
    hora_inicio: string;
    hora_fin: string;
    aula: { codigo: string } | null;
    curso: { materia: { codigo: string; nombre: string } | null } | null;
    inscripcion_examen_final: { count: number }[];
  }[];
};

// Turnos de examen (julio, diciembre, febrero) con su período de
// inscripción y las fechas de final de cada materia.
export default async function TurnosDeExamen({ searchParams }: PageProps<"/administracion/finales">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Turnos de examen</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("turno_examen")
    .select("id, nombre, inscripcion_desde, inscripcion_hasta, examen_final(id, fecha, hora_inicio, hora_fin, aula:aula_id(codigo), curso:curso_id(materia:materia_id(codigo, nombre)), inscripcion_examen_final(count))")
    .order("inscripcion_desde", { ascending: false })
    .returns<Turno[]>();
  const turnos = data ?? [];
  const hoyStr = hoy();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Turnos de examen</h2>
      <p className="sga-texto">
        Los alumnos se anotan a una fecha por materia en cada turno, durante el período de inscripción y hasta 48 h antes del examen.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {turnos.map((t) => {
        const fechas = [...t.examen_final].sort((a, b) => (a.fecha + a.hora_inicio).localeCompare(b.fecha + b.hora_inicio));
        const abierto = hoyStr >= t.inscripcion_desde && hoyStr <= t.inscripcion_hasta;
        return (
          <div key={t.id}>
            <h3 className="sga-subtitulo">
              {t.nombre}{" "}
              <span className={`sga-estado-encuesta ${abierto ? "sga-estado-activa" : hoyStr < t.inscripcion_desde ? "sga-estado-programada" : "sga-estado-finalizada"}`}>
                {abierto ? "Inscripción abierta" : hoyStr < t.inscripcion_desde ? "Próximamente" : "Inscripción cerrada"}
              </span>
            </h3>
            <p className="sga-ayuda">Inscripción del {fecha(t.inscripcion_desde)} al {fecha(t.inscripcion_hasta)}.</p>
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-mensajes">
                <thead><tr><th>Materia</th><th>Fecha</th><th>Hasta</th><th>Aula</th><th>Anotados</th><th></th></tr></thead>
                <tbody>
                  {fechas.length > 0 ? fechas.map((f) => (
                    <tr key={f.id}>
                      <td><strong>{f.curso?.materia?.codigo}</strong> - {f.curso?.materia?.nombre}</td>
                      <td>{diaYHora(f.fecha, f.hora_inicio)}</td>
                      <td>{f.hora_fin.slice(0, 5)} hs</td>
                      <td>{f.aula?.codigo ?? "A confirmar"}</td>
                      <td className="sga-col-cupo">{f.inscripcion_examen_final[0]?.count ?? 0}</td>
                      <td className="sga-acciones-doc">
                        <form action={borrarFecha}>
                          <input name="id" type="hidden" value={f.id} />
                          <button className="sga-boton-peligro" type="submit">Borrar</button>
                        </form>
                      </td>
                    </tr>
                  )) : <tr><td className="sga-vacio" colSpan={6}>Todavía no hay fechas en este turno.</td></tr>}
                </tbody>
              </table>
            </div>
            <form action={agregarFecha} className="sga-form-fecha-final">
              <input name="turno_id" type="hidden" value={t.id} />
              <input aria-label="Código de materia" name="codigo" placeholder="Código (ej. 71.38)" required />
              <input aria-label="Fecha" name="fecha" required type="date" />
              <input aria-label="Hora de inicio" defaultValue="09:00" name="hora_inicio" required type="time" />
              <input aria-label="Hora de fin" defaultValue="12:00" name="hora_fin" required type="time" />
              <input aria-label="Aula" name="aula" placeholder="Aula (opcional)" />
              <button type="submit">Agregar fecha</button>
            </form>
          </div>
        );
      })}
      {turnos.length === 0 && <p className="sga-vacio">Todavía no hay turnos de examen.</p>}

      <h3 className="sga-subtitulo">Nuevo turno</h3>
      <form action={crearTurno} className="sga-form-publicacion">
        <label><span>Nombre</span><input name="nombre" placeholder="Ej.: Diciembre 2026" required /></label>
        <fieldset className="sga-fieldset-fechas">
          <legend>Período de inscripción</legend>
          <label><span>Desde</span><input name="desde" required type="date" /></label>
          <label><span>Hasta</span><input name="hasta" required type="date" /></label>
        </fieldset>
        <div className="sga-acciones-form"><button type="submit">Crear turno</button></div>
      </form>
    </section>
  );
}
