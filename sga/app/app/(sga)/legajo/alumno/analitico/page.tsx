import { createClient } from "@/lib/supabase/server";
import { getCursadas, type Cursada } from "@/lib/cursadas";
import { fecha, getLegajoActual, nota, periodo } from "@/lib/legajo";

type PlanMateria = {
  anio_sugerido: number | null;
  cuatrimestre_sugerido: number | null;
  materia: { id: number; codigo: string; nombre: string; creditos: number } | null;
};

const ordinal = ["", "1", "2", "3", "4", "5", "6"];

function celdaCursada(c: Cursada) {
  if (c.estado === "CURSANDO") return <span className="sga-cursando">Cursando {periodo(c.curso!.anio, c.curso!.periodo)}</span>;
  return <>{nota(c.nota_cursada)} {periodo(c.curso!.anio, c.curso!.periodo)}</>;
}

function celdaFinales(c: Cursada) {
  return c.inscripcion_examen_final.map((f) => (
    <div className={f.nota_final !== null && f.nota_final >= 4 ? "sga-aprobado" : "sga-desaprobado"} key={f.numero_intento}>
      {nota(f.nota_final)} ({fecha(f.examen_final?.fecha)})
    </div>
  ));
}

export default async function Analitico() {
  const { legajo, nombre } = await getLegajoActual();
  if (!legajo?.plan_estudio) return null;

  const supabase = await createClient();
  const [{ data: planMaterias }, cursadas] = await Promise.all([
    supabase
      .schema("sga")
      .from("plan_materia")
      .select("anio_sugerido, cuatrimestre_sugerido, materia:materia_id(id, codigo, nombre, creditos)")
      .eq("plan_id", legajo.plan_estudio.id)
      .returns<PlanMateria[]>(),
    getCursadas(legajo.id),
  ]);

  const porMateria = new Map<number, Cursada[]>();
  for (const c of cursadas) {
    const id = c.curso?.materia?.id;
    if (id) porMateria.set(id, [...(porMateria.get(id) ?? []), c]);
  }

  const aprobada = (id: number) => porMateria.get(id)?.some((c) => c.estado === "APROBADA") ?? false;
  const materias = (planMaterias ?? []).filter((pm) => pm.materia);
  const creditosAprobados = materias.filter((pm) => aprobada(pm.materia!.id)).reduce((s, pm) => s + pm.materia!.creditos, 0);
  const creditosEnCurso = cursadas.filter((c) => c.estado === "CURSANDO").reduce((s, c) => s + (c.curso?.materia?.creditos ?? 0), 0);
  const total = legajo.plan_estudio.creditos_totales;
  const porcentaje = total > 0 ? Math.round((creditosAprobados / total) * 100) : 0;

  // Agrupa por "Año X - Cuatrimestre Y" del plan
  const grupos = new Map<string, PlanMateria[]>();
  for (const pm of [...materias].sort((a, b) =>
    (a.anio_sugerido ?? 99) - (b.anio_sugerido ?? 99) ||
    (a.cuatrimestre_sugerido ?? 99) - (b.cuatrimestre_sugerido ?? 99) ||
    a.materia!.codigo.localeCompare(b.materia!.codigo))) {
    const clave = pm.anio_sugerido
      ? `Año ${ordinal[pm.anio_sugerido]} - Cuatrimestre ${ordinal[pm.cuatrimestre_sugerido ?? 0] || "—"}`
      : "Sin ubicación en el plan";
    grupos.set(clave, [...(grupos.get(clave) ?? []), pm]);
  }

  return (
    <>
      <h3 className="sga-subtitulo">Analítico de notas de {nombre} - {legajo.numero_legajo}</h3>
      <p className="sga-texto">Plan de estudios: <strong>{legajo.plan_estudio.codigo}</strong></p>

      <p className="sga-banner">
        IMPORTANTE: Los alumnos con rendimiento académico inferior a 4 (cuatro) puntos dejan de ser
        alumnos regulares y se consideran Alumnos Condicionales Especiales.
      </p>
      {legajo.condicional_especial && (
        <p className="sga-error">Tu rendimiento académico es inferior a 4: sos Alumno Condicional Especial.</p>
      )}

      <p className="sga-texto">Rendimiento académico: <strong>{nota(legajo.rendimiento_academico) || "—"}</strong></p>

      <div className="sga-resumen">
        <table className="sga-tabla sga-tabla-compacta">
          <thead><tr><th colSpan={2}>Resumen de créditos aprobados</th></tr></thead>
          <tbody>
            <tr><td>Créditos aprobados</td><td>{creditosAprobados}</td></tr>
            <tr><td>Créditos totales del plan</td><td>{total}</td></tr>
          </tbody>
        </table>
        <div className="sga-texto">
          Créditos en curso: <strong>{creditosEnCurso}</strong><br />
          Créditos totales del plan: <strong>{total}</strong>
        </div>
      </div>

      <p className="sga-texto">Porcentaje de carrera completado</p>
      <div className="sga-progreso" role="progressbar" aria-valuenow={porcentaje} aria-valuemin={0} aria-valuemax={100}>
        <span style={{ width: `${porcentaje}%` }} />
      </div>
      <p className="sga-texto">{porcentaje}%</p>

      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead>
            <tr><th>Materia</th><th>Cursada</th><th>Finales</th></tr>
          </thead>
          {[...grupos.entries()].map(([grupo, pms]) => (
            <tbody key={grupo}>
              <tr className="sga-fila-grupo"><td colSpan={3}>{grupo}</td></tr>
              {pms.map((pm) => {
                const m = pm.materia!;
                const historial = (porMateria.get(m.id) ?? []).sort((a, b) =>
                  `${a.curso?.anio}${a.curso?.periodo}`.localeCompare(`${b.curso?.anio}${b.curso?.periodo}`));
                return (
                  <tr className={aprobada(m.id) ? "sga-fila-aprobada" : ""} key={m.id}>
                    <td>
                      {aprobada(m.id) && <span className="sga-check" aria-label="Aprobada">✔</span>}
                      <strong>{m.codigo} - {m.nombre}</strong> <span className="sga-creditos">({m.creditos} Créditos)</span>
                    </td>
                    <td>{historial.map((c) => <div key={c.id}>{celdaCursada(c)}</div>)}</td>
                    <td>{historial.map((c) => <div key={c.id}>{celdaFinales(c)}</div>)}</td>
                  </tr>
                );
              })}
            </tbody>
          ))}
        </table>
      </div>
    </>
  );
}
