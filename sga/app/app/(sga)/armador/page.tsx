import Armador from "@/components/armador";
import type { MateriaArmador } from "@/lib/armador";
import { clavePeriodo, deClave, getMateriasArmador, getPeriodosArmador, getPlanesArmador } from "@/lib/armador-datos";
import { hoy } from "@/lib/hoy";
import { getLegajoActual, periodo as nombrePeriodo } from "@/lib/legajo";
import { createClient } from "@/lib/supabase/server";

type PeriodoInscripcion = { desde: string; hasta: string; segunda_desde: string | null; segunda_hasta: string | null };

// Armador de horarios: combina las comisiones de las materias que se
// quieren cursar según días libres y horarios. El alumno ve su plan con lo
// que puede cursar; cualquiera puede elegir otro plan.
export default async function ArmadorDeHorarios({ searchParams }: PageProps<"/armador">) {
  const params = await searchParams;
  const [{ legajo }, periodos, planes] = await Promise.all([getLegajoActual(), getPeriodosArmador(), getPlanesArmador()]);
  const planId = Number(params.plan) || legajo?.plan_estudio?.id || planes[0]?.id || 0;
  const esMiPlan = !!legajo && legajo.plan_estudio?.id === planId;
  const legajoId = esMiPlan ? legajo.id : null;

  // Sin cuatrimestre elegido: aquel en el que se dictan más materias que le
  // faltan cursar (a igualdad, el más nuevo)
  const pedido = deClave(typeof params.periodo === "string" ? params.periodo : undefined);
  const candidatos = pedido ? [pedido] : periodos;
  const cargados = await Promise.all(candidatos.map((p) => getMateriasArmador(planId, p, legajoId)));
  const ofrecidas = (ms: MateriaArmador[]) =>
    ms.filter((m) => m.comisiones.length > 0 && !["APROBADA", "CURSADA", "CURSANDO"].includes(m.estado)).length;
  const elegido = cargados.reduce((mejor, ms, i) => (ofrecidas(ms) > ofrecidas(cargados[mejor]) ? i : mejor), 0);
  const periodo = candidatos[elegido] ?? null;
  const materias = cargados[elegido] ?? [];

  const supabase = await createClient();
  const { data: inscripcion } = periodo
    ? await supabase.schema("sga").from("periodo_inscripcion_cursada")
        .select("desde, hasta, segunda_desde, segunda_hasta")
        .eq("anio", periodo.anio).eq("periodo", periodo.periodo)
        .maybeSingle<PeriodoInscripcion>()
    : { data: null };
  const h = hoy();
  const abierta = !!inscripcion && esMiPlan && ((inscripcion.desde <= h && h <= inscripcion.hasta)
    || (!!inscripcion.segunda_desde && inscripcion.segunda_desde <= h && h <= (inscripcion.segunda_hasta ?? "")));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Armador de horarios</h2>
      <p className="sga-texto">
        Contale qué días querés libres, en qué horario podés cursar y qué materias querés hacer: el armador combina las
        comisiones del cuatrimestre sin superposiciones y te muestra primero las opciones con menos días y menos huecos.
        {esMiPlan && " La lista muestra las materias de tu plan que te faltan cursar, en el orden del plan."}
      </p>
      <form className="sga-hoy-filtros">
        <label>
          <span className="sga-ayuda">Cuatrimestre </span>
          <select defaultValue={periodo ? clavePeriodo(periodo) : ""} name="periodo">
            {periodos.map((p) => <option key={clavePeriodo(p)} value={clavePeriodo(p)}>{nombrePeriodo(p.anio, p.periodo)}</option>)}
          </select>
        </label>
        <label>
          <span className="sga-ayuda">Plan </span>
          <select defaultValue={planId} name="plan">
            {planes.map((p) => (
              <option key={p.id} value={p.id}>{p.codigo} — {p.carrera}{legajo?.plan_estudio?.id === p.id ? " (el tuyo)" : ""}</option>
            ))}
          </select>
        </label>
        <button type="submit">Ver</button>
      </form>
      {!periodo && <p className="sga-vacio">Todavía no hay comisiones con horarios cargadas.</p>}
      {periodo && (
        <Armador
          conLegajo={esMiPlan}
          inscripcionAbierta={abierta}
          key={`${clavePeriodo(periodo)}-${planId}`}
          materias={materias}
        />
      )}
    </section>
  );
}
