import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { borrarPeriodo, guardarPeriodo } from "./actions";

type Periodo = { id: number; anio: number; periodo: string; desde: string; hasta: string };

// Períodos de inscripción a cursadas de cada cuatrimestre.
export default async function PeriodosDeInscripcion({ searchParams }: PageProps<"/administracion/inscripciones">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Inscripción a cursadas</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data }, { data: cursos }] = await Promise.all([
    sga.from("periodo_inscripcion_cursada").select("id, anio, periodo, desde, hasta").order("anio", { ascending: false }).order("periodo", { ascending: false }).returns<Periodo[]>(),
    sga.from("curso").select("anio, periodo").eq("activo", true).returns<{ anio: number; periodo: string }[]>(),
  ]);
  const periodos = data ?? [];
  const cuatrimestres = [...new Set((cursos ?? []).map((c) => `${c.anio}|${c.periodo}`))].sort().reverse();
  const hoyStr = hoy();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Inscripción a cursadas</h2>
      <p className="sga-texto">
        Durante el período de inscripción, los alumnos eligen una comisión por materia de los cursos activos de ese cuatrimestre.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Cuatrimestre</th><th>Inscripción</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {periodos.length > 0 ? periodos.map((p) => {
              const abierto = hoyStr >= p.desde && hoyStr <= p.hasta;
              return (
                <tr key={p.id}>
                  <td><strong>{periodo(p.anio, p.periodo)}</strong></td>
                  <td>Del {fecha(p.desde)} al {fecha(p.hasta)}</td>
                  <td>
                    <span className={`sga-estado-encuesta ${abierto ? "sga-estado-activa" : hoyStr < p.desde ? "sga-estado-programada" : "sga-estado-finalizada"}`}>
                      {abierto ? "Abierta" : hoyStr < p.desde ? "Próximamente" : "Cerrada"}
                    </span>
                  </td>
                  <td className="sga-acciones-doc">
                    <form action={borrarPeriodo}>
                      <input name="id" type="hidden" value={p.id} />
                      <button className="sga-boton-peligro" type="submit">Borrar</button>
                    </form>
                  </td>
                </tr>
              );
            }) : <tr><td className="sga-vacio" colSpan={4}>Todavía no hay períodos de inscripción.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Abrir o cambiar un período</h3>
      <form action={guardarPeriodo} className="sga-form-fecha-final">
        <select aria-label="Cuatrimestre" name="cuatrimestre" required defaultValue="">
          <option disabled value="">Cuatrimestre…</option>
          {cuatrimestres.map((c) => {
            const [anio, per] = c.split("|");
            return <option key={c} value={c}>{periodo(Number(anio), per)}</option>;
          })}
        </select>
        <input aria-label="Inscripción desde" name="desde" required type="date" />
        <input aria-label="Inscripción hasta" name="hasta" required type="date" />
        <button type="submit">Guardar</button>
      </form>
      <p className="sga-ayuda">Si el cuatrimestre ya tiene período, se reemplazan las fechas.</p>
    </section>
  );
}
