import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { crearCurso } from "./actions";

type Curso = { id: number; codigo: string; materia: string; departamento: string; fecha_inicio: string; fecha_fin: string; alumnos: number };
type Comision = { curso_id: number; nombre: string; cupo: number | null; horario_comision: { id: number }[] };

// Fechas sugeridas de cada cuatrimestre para un curso nuevo.
const fechasSugeridas = (anio: number, per: string) =>
  per === "1C" ? { desde: `${anio}-03-09`, hasta: `${anio}-07-04` } : { desde: `${anio}-08-10`, hasta: `${anio}-12-05` };

// Oferta de cursos de un cuatrimestre: listado, búsqueda y alta.
export default async function OfertaDeCursos({ searchParams }: PageProps<"/administracion/oferta">) {
  const params = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Oferta de cursos</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const anioActual = Number(hoy().slice(0, 4));
  const cuatrimestres = [anioActual - 1, anioActual, anioActual + 1].flatMap((a) => [`${a}|1C`, `${a}|2C`]).reverse();
  const elegido = typeof params.cuatrimestre === "string" && cuatrimestres.includes(params.cuatrimestre)
    ? params.cuatrimestre : `${anioActual}|${Number(hoy().slice(5, 7)) >= 8 ? "2C" : "1C"}`;
  const [anio, per] = [Number(elegido.split("|")[0]), elegido.split("|")[1]];
  const q = typeof params.q === "string" ? params.q.trim() : "";

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  let consulta = sga.from("curso_listado").select("id, codigo, materia, departamento, fecha_inicio, fecha_fin, alumnos")
    .eq("anio", anio).eq("periodo", per).eq("activo", true);
  if (q) consulta = consulta.or(`codigo.ilike.%${q.replace(/[%_,()]/g, "")}%,materia.ilike.%${q.replace(/[%_,()]/g, "")}%`);
  const { data } = await consulta.order("codigo").limit(60).returns<Curso[]>();
  const cursos = data ?? [];
  const { data: comisionesData } = cursos.length
    ? await sga.from("comision").select("curso_id, nombre, cupo, horario_comision(id)").in("curso_id", cursos.map((c) => c.id)).returns<Comision[]>()
    : { data: [] };
  const porCurso = new Map<number, Comision[]>();
  for (const c of comisionesData ?? []) porCurso.set(c.curso_id, [...(porCurso.get(c.curso_id) ?? []), c]);
  const sugeridas = fechasSugeridas(anio, per);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Oferta de cursos</h2>
      <p className="sga-texto">
        Cursos de cada cuatrimestre con sus comisiones, cupos y horarios. Lo que cargues acá es lo que ven los alumnos en Cursos
        y en la inscripción a cursadas.
      </p>
      {typeof params.ok === "string" && <p className="sga-mensaje-ok" role="status">{params.ok}</p>}
      {typeof params.error === "string" && <p className="sga-mensaje-error" role="alert">{params.error}</p>}

      <form className="sga-hoy-filtros">
        <select aria-label="Cuatrimestre" defaultValue={elegido} name="cuatrimestre">
          {cuatrimestres.map((c) => <option key={c} value={c}>{periodo(Number(c.split("|")[0]), c.split("|")[1])}</option>)}
        </select>
        <input aria-label="Buscar materia" defaultValue={q} name="q" placeholder="Código o nombre de la materia" />
        <button type="submit">Ver</button>
      </form>

      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Materia</th><th>Departamento</th><th>Fechas</th><th>Comisiones</th><th>Inscriptos</th><th>Acciones</th></tr></thead>
          <tbody>
            {cursos.length > 0 ? cursos.map((c) => {
              const coms = (porCurso.get(c.id) ?? []).sort((a, b) => a.nombre.localeCompare(b.nombre));
              const sinHorario = coms.filter((co) => co.horario_comision.length === 0).length;
              return (
                <tr key={c.id}>
                  <td><strong>{c.codigo}</strong> - {c.materia}</td>
                  <td>{c.departamento}</td>
                  <td>{fecha(c.fecha_inicio)} al {fecha(c.fecha_fin)}</td>
                  <td>
                    {coms.length ? coms.map((co) => `${co.nombre}${co.cupo ? ` (${co.cupo})` : ""}`).join(", ") : <span className="sga-estado-rechazado">Sin comisiones</span>}
                    {sinHorario > 0 && <div className="sga-estado-cargado">{sinHorario === 1 ? "1 sin horarios" : `${sinHorario} sin horarios`}</div>}
                  </td>
                  <td>{c.alumnos}</td>
                  <td className="sga-col-lupa"><Link aria-label={`Editar ${c.codigo}`} href={`/administracion/oferta/${c.id}`}>🔍</Link></td>
                </tr>
              );
            }) : <tr><td className="sga-vacio" colSpan={6}>{q ? "No hay cursos que coincidan." : "Todavía no hay cursos en este cuatrimestre."}</td></tr>}
          </tbody>
        </table>
      </div>
      {cursos.length === 60 && <p className="sga-ayuda">Se muestran los primeros 60: buscá por código o nombre para encontrar otros.</p>}

      <h3 className="sga-subtitulo">Nuevo curso en {periodo(anio, per)}</h3>
      <form action={crearCurso} className="sga-form-fecha-final" key={elegido}>
        <input name="cuatrimestre" type="hidden" value={elegido} />
        <input aria-label="Código de materia" name="codigo" placeholder="Código (ej. 71.38)" required />
        <span className="sga-ayuda">del</span>
        <input aria-label="Inicio del curso" defaultValue={sugeridas.desde} name="desde" required type="date" />
        <span className="sga-ayuda">al</span>
        <input aria-label="Fin del curso" defaultValue={sugeridas.hasta} name="hasta" required type="date" />
        <button type="submit">Crear curso</button>
      </form>
    </section>
  );
}
