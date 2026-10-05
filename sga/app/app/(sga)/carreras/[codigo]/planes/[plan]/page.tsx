import Link from "next/link";
import { notFound } from "next/navigation";
import { periodoDeFecha } from "@/lib/legajo";
import { getPlanDetalle, grilla, requisitoBloque, type MateriaPlan } from "@/lib/plan";

const idMateria = (codigo: string) => `materia-${codigo}`;

// Cada correlativa lleva a la fila de esa materia en el plan; si no es del
// plan, al listado de cursos de esa materia.
function FilaMateria({ m, enPlan }: { m: MateriaPlan; enPlan: Set<string> }) {
  return (
    <tr className="sga-fila-materia" id={idMateria(m.codigo)}>
      <td className="sga-materia-plan"><span>{m.codigo}</span> - {m.nombre}</td>
      <td className="sga-curso">{m.creditos}</td>
      <td className="sga-requeridos">{m.creditosRequeridos}</td>
      <td className="sga-correlativas">
        {m.correlativas.map((c) => enPlan.has(c)
          // Enlace común: el salto a #id activa el resaltado (:target), que el
          // Link de Next no dispara.
          ? <a href={`#${idMateria(c)}`} key={c} title="Ver la materia en el plan">{c}</a>
          : <Link href={`/cursos?f=1&codigo=${encodeURIComponent(c)}`} key={c} title="Ver los cursos de la materia">{c}</Link>)}
      </td>
    </tr>
  );
}

const encabezado = (
  <thead><tr><th>Materia</th><th>Créditos</th><th>Créditos requeridos</th><th>Correlativas</th></tr></thead>
);

// "Detalle de Planes de estudio" como en el SGA actual: un recuadro por
// bloque; el obligatorio en grilla año/cuatrimestre con los huecos de
// electivas, y cada bloque de electivas con su contenido.
export default async function DetallePlan({ params }: PageProps<"/carreras/[codigo]/planes/[plan]">) {
  const { codigo, plan: planCodigo } = await params;
  const carrera = decodeURIComponent(codigo);
  const plan = await getPlanDetalle({ carrera, codigo: decodeURIComponent(planCodigo) });
  if (!plan) notFound();
  const enPlan = new Set(plan.bloques.flatMap((b) => b.materias.map((m) => m.codigo)));

  return (
    <>
      <h2 className="sga-titulo sga-titulo-grande sga-titulo-suelto">Detalle de Planes de estudio</h2>
      <section className="sga-panel">
        <h3 className="sga-subtitulo">Plan de estudio: {plan.codigo}</h3>
        <p className="sga-texto">
          {plan.carrera?.nombre} · Versión {plan.version} · Activo desde {periodoDeFecha(plan.vigenciaDesde)}
          {plan.vigenciaHasta ? ` hasta ${periodoDeFecha(plan.vigenciaHasta)}` : ""}
        </p>

        {plan.bloques.length === 0 && <p className="sga-vacio">El plan no tiene materias cargadas.</p>}
        {plan.bloques.map((b) => (
          <div className="sga-bloque-plan" key={b.id ?? "sin-bloque"}>
            <p className="sga-bloque-plan-titulo">{b.nombre} - Requisito: {requisitoBloque(b)}</p>
            {b.requisito === "APROBAR_TODOS" ? (
              grilla(b).map((g) => (
                <div className="sga-bloque-plan-grupo" key={g.titulo}>
                  <h4 className="sga-subtitulo">{g.titulo}</h4>
                  <div className="sga-tabla-scroll">
                    <table className="sga-tabla sga-tabla-plan">
                      {encabezado}
                      <tbody>
                        {g.materias.map((m) => <FilaMateria enPlan={enPlan} key={m.id} m={m} />)}
                        {g.huecos.map((h) => (
                          <tr className="sga-fila-hueco" key={h.bloque}>
                            <td>{h.bloque}</td><td>{h.creditos}</td><td>{h.creditos}</td><td></td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))
            ) : (
              <div className="sga-bloque-plan-grupo">
                <h4 className="sga-subtitulo">Contenido:</h4>
                <div className="sga-tabla-scroll">
                  <table className="sga-tabla sga-tabla-plan">
                    {encabezado}
                    <tbody>{b.materias.map((m) => <FilaMateria enPlan={enPlan} key={m.id} m={m} />)}</tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        ))}

        {plan.titulos.length > 0 && (
          <>
            <h3 className="sga-subtitulo">Títulos otorgados</h3>
            <table className="sga-tabla sga-tabla-plan">
              <thead><tr><th>Tipo</th><th>Título</th><th>Requisitos</th></tr></thead>
              <tbody>
                {plan.titulos.map((t) => (
                  <tr key={t.nombre}>
                    <td className="sga-curso">{t.tipo}</td>
                    <td className="sga-materia-plan">{t.nombre}</td>
                    <td className="sga-curso">{t.requisito}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}
      </section>
      <Link className="sga-volver" href={`/carreras/${encodeURIComponent(carrera)}`}>← Volver a la carrera</Link>
    </>
  );
}
