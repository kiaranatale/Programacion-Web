import { getCursadas, resultadoFinal, type Cursada } from "@/lib/cursadas";
import { fecha, getLegajoActual, nota, periodo } from "@/lib/legajo";
import { getPlanDetalle, grilla, type Bloque, type MateriaPlan } from "@/lib/plan";

function celdaCursada(c: Cursada) {
  if (c.estado === "CURSANDO") return <span className="sga-cursando">Cursando {periodo(c.curso!.anio, c.curso!.periodo)}</span>;
  if (c.estado === "DESAPROBADA" || c.estado === "ABANDONADA") {
    return <span className="sga-desaprobado">{c.estado === "ABANDONADA" ? "Abandonada" : "Desaprobada"} {periodo(c.curso!.anio, c.curso!.periodo)}</span>;
  }
  return <>{nota(c.nota_cursada)} {periodo(c.curso!.anio, c.curso!.periodo)}</>;
}

function celdaFinales(c: Cursada) {
  return c.inscripcion_examen_final.map((f) => {
    const r = resultadoFinal(f, nota);
    return <div className={r.clase} key={f.numero_intento}>{r.texto} ({fecha(f.examen_final?.fecha)})</div>;
  });
}

export default async function Analitico() {
  const { legajo, nombre } = await getLegajoActual();
  if (!legajo?.plan_estudio) return null;

  const [plan, cursadas] = await Promise.all([getPlanDetalle({ id: legajo.plan_estudio.id }), getCursadas(legajo.id)]);
  if (!plan) return null;

  const porMateria = new Map<number, Cursada[]>();
  for (const c of cursadas) {
    const id = c.curso?.materia?.id;
    if (id) porMateria.set(id, [...(porMateria.get(id) ?? []), c]);
  }
  const historial = (id: number) => (porMateria.get(id) ?? []).sort((a, b) =>
    `${a.curso?.anio}${a.curso?.periodo}`.localeCompare(`${b.curso?.anio}${b.curso?.periodo}`));
  const aprobada = (id: number) => porMateria.get(id)?.some((c) => c.estado === "APROBADA") ?? false;

  // Créditos por bloque: los de electivas cuentan hasta lo que pide el bloque
  const aprobadosEn = (b: Bloque) => b.materias.filter((m) => aprobada(m.id)).reduce((s, m) => s + m.creditos, 0);
  const resumen = plan.bloques.map((b) => {
    const aprobados = aprobadosEn(b);
    const requeridos = b.requisito === "APROBAR_TODOS" ? b.materias.reduce((s, m) => s + m.creditos, 0) : b.creditos;
    return { bloque: b, aprobados, computables: Math.min(aprobados, requeridos), requeridos };
  });
  const creditosAprobados = resumen.reduce((s, r) => s + r.computables, 0);
  const creditosEnCurso = cursadas.filter((c) => c.estado === "CURSANDO").reduce((s, c) => s + (c.curso?.materia?.creditos ?? 0), 0);
  const porcentaje = plan.creditosTotales > 0 ? Math.round((creditosAprobados / plan.creditosTotales) * 100) : 0;
  const aprobadosBloque = new Map(resumen.map((r) => [r.bloque.nombre, r.aprobados]));

  const filaMateria = (m: MateriaPlan) => (
    <tr className={aprobada(m.id) ? "sga-fila-aprobada" : ""} key={m.id}>
      <td>
        {aprobada(m.id) && <span className="sga-check" aria-label="Aprobada">✔</span>}
        <strong>{m.codigo} - {m.nombre}</strong> <span className="sga-creditos">({m.creditos} Créditos)</span>
      </td>
      <td>{historial(m.id).map((c) => <div key={c.id}>{celdaCursada(c)}</div>)}</td>
      <td>{historial(m.id).map((c) => <div key={c.id}>{celdaFinales(c)}</div>)}</td>
    </tr>
  );

  return (
    <>
      <h3 className="sga-subtitulo">Analítico de notas de {nombre} - {legajo.numero_legajo}</h3>
      <p className="sga-texto">Plan de estudios: <strong>{plan.codigo}</strong> ({plan.carrera?.nombre})</p>

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
          <thead><tr><th>Resumen de créditos aprobados</th><th>Aprobados</th><th>Requeridos</th></tr></thead>
          <tbody>
            {resumen.map((r) => (
              <tr key={r.bloque.nombre}><td>{r.bloque.huecos.length > 0 ? `${r.bloque.nombre} (materias obligatorias)` : r.bloque.nombre}</td><td>{r.aprobados}</td><td>{r.requeridos}</td></tr>
            ))}
          </tbody>
        </table>
        <div className="sga-texto">
          Créditos aprobados: <strong>{creditosAprobados}</strong><br />
          Créditos en curso: <strong>{creditosEnCurso}</strong><br />
          Créditos totales del plan: <strong>{plan.creditosTotales}</strong>
        </div>
      </div>

      <p className="sga-texto">Porcentaje de carrera completado</p>
      <div className="sga-progreso" role="progressbar" aria-valuenow={porcentaje} aria-valuemin={0} aria-valuemax={100}>
        <span style={{ width: `${porcentaje}%` }} />
      </div>
      <p className="sga-texto">{porcentaje}%</p>

      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Materia</th><th>Cursada</th><th>Finales</th></tr></thead>
          {plan.bloques.map((b) =>
            b.requisito === "APROBAR_TODOS" ? (
              grilla(b).map((g) => (
                <tbody key={`${b.nombre}-${g.titulo}`}>
                  <tr className="sga-fila-grupo"><td colSpan={3}>{g.titulo}</td></tr>
                  {g.materias.map(filaMateria)}
                  {g.huecos.map((h) => (
                    <tr className="sga-fila-hueco" key={h.bloque}>
                      <td>{h.bloque} ({h.creditos} Créditos)</td>
                      <td colSpan={2}>{aprobadosBloque.get(h.bloque) ?? 0} de {h.creditos} créditos aprobados</td>
                    </tr>
                  ))}
                </tbody>
              ))
            ) : (
              <tbody key={b.nombre}>
                <tr className="sga-fila-grupo">
                  <td colSpan={3}>{b.nombre} — {aprobadosBloque.get(b.nombre) ?? 0} de {b.creditos} créditos aprobados</td>
                </tr>
                {b.materias.filter((m) => porMateria.has(m.id)).map(filaMateria)}
                {!b.materias.some((m) => porMateria.has(m.id)) && (
                  <tr><td className="sga-vacio" colSpan={3}>Todavía no cursaste materias de este bloque.</td></tr>
                )}
              </tbody>
            ),
          )}
        </table>
      </div>
    </>
  );
}
