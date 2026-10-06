import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { borrarPeriodo, guardarPeriodo } from "./actions";

type Periodo = {
  id: number; anio: number; periodo: string; desde: string; hasta: string;
  segunda_desde: string | null; segunda_hasta: string | null; asignacion_confirmada: boolean;
};

// Igual que sga.etapa_inscripcion_cursada()
function etapa(p: Periodo, hoyStr: string) {
  if (hoyStr < p.desde) return { texto: "Próximamente", clase: "sga-estado-programada" };
  if (hoyStr <= p.hasta) return { texto: "Primera inscripción", clase: "sga-estado-activa" };
  if (p.segunda_desde && p.segunda_hasta && hoyStr < p.segunda_desde) {
    return p.asignacion_confirmada
      ? { texto: "Asignación confirmada", clase: "sga-estado-programada" }
      : { texto: "Asignación de vacantes", clase: "sga-estado-activa" };
  }
  if (p.segunda_desde && p.segunda_hasta && hoyStr <= p.segunda_hasta) return { texto: "Segunda inscripción", clase: "sga-estado-activa" };
  return { texto: "Cerrada", clase: "sga-estado-finalizada" };
}

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
    sga.from("periodo_inscripcion_cursada").select("id, anio, periodo, desde, hasta, segunda_desde, segunda_hasta, asignacion_confirmada").order("anio", { ascending: false }).order("periodo", { ascending: false }).returns<Periodo[]>(),
    sga.from("curso").select("anio, periodo").eq("activo", true).returns<{ anio: number; periodo: string }[]>(),
  ]);
  const periodos = data ?? [];
  const cuatrimestres = [...new Set((cursos ?? []).map((c) => `${c.anio}|${c.periodo}`))].sort().reverse();
  const hoyStr = hoy();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Inscripción a cursadas</h2>
      <p className="sga-texto">
        La inscripción tiene tres etapas. En la <strong>primera inscripción</strong> los alumnos solicitan una comisión por materia
        (el orden de llegada no importa). Después, Administración <strong>asigna las vacantes</strong> de cada comisión y confirma
        la asignación. En la <strong>segunda inscripción</strong> cada alumno ve dónde quedó y puede darse de baja o anotarse
        donde queden vacantes.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Cuatrimestre</th><th>Primera inscripción</th><th>Segunda inscripción</th><th>Etapa</th><th></th></tr></thead>
          <tbody>
            {periodos.length > 0 ? periodos.map((p) => {
              const e = etapa(p, hoyStr);
              return (
                <tr key={p.id}>
                  <td><strong>{periodo(p.anio, p.periodo)}</strong></td>
                  <td>Del {fecha(p.desde)} al {fecha(p.hasta)}</td>
                  <td>{p.segunda_desde && p.segunda_hasta ? `Del ${fecha(p.segunda_desde)} al ${fecha(p.segunda_hasta)}` : "Sin fechas"}</td>
                  <td><span className={`sga-estado-encuesta ${e.clase}`}>{e.texto}</span></td>
                  <td className="sga-acciones-doc">
                    <Link href={`/administracion/inscripciones/${p.id}`}>Solicitudes y asignación</Link>
                    <form action={borrarPeriodo}>
                      <input name="id" type="hidden" value={p.id} />
                      <button className="sga-boton-peligro" type="submit">Borrar</button>
                    </form>
                  </td>
                </tr>
              );
            }) : <tr><td className="sga-vacio" colSpan={5}>Todavía no hay períodos de inscripción.</td></tr>}
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
        <span className="sga-ayuda">Primera del</span>
        <input aria-label="Primera inscripción desde" name="desde" required type="date" />
        <span className="sga-ayuda">al</span>
        <input aria-label="Primera inscripción hasta" name="hasta" required type="date" />
        <span className="sga-ayuda">· Segunda del</span>
        <input aria-label="Segunda inscripción desde" name="segunda_desde" type="date" />
        <span className="sga-ayuda">al</span>
        <input aria-label="Segunda inscripción hasta" name="segunda_hasta" type="date" />
        <button type="submit">Guardar</button>
      </form>
      <p className="sga-ayuda">
        Si el cuatrimestre ya tiene período, se reemplazan las fechas. La segunda inscripción empieza después de la primera;
        entre las dos queda el tiempo para asignar las vacantes.
      </p>
    </section>
  );
}
