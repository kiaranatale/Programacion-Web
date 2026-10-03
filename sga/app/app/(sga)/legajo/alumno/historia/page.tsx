import { clavePeriodo, getCursadas } from "@/lib/cursadas";
import { fecha, getLegajoActual, nota, periodo } from "@/lib/legajo";

export default async function HistoriaAcademica() {
  const { legajo, nombre } = await getLegajoActual();
  if (!legajo) return null;

  const cursadas = await getCursadas(legajo.id);
  const porPeriodo = new Map<string, typeof cursadas>();
  for (const c of cursadas) porPeriodo.set(clavePeriodo(c), [...(porPeriodo.get(clavePeriodo(c)) ?? []), c]);
  const periodos = [...porPeriodo.keys()].sort().reverse();

  return (
    <>
      <h3 className="sga-subtitulo">Historia académica de {nombre} - {legajo.numero_legajo}</h3>
      {periodos.length === 0 && <p className="sga-vacio">No hay cursadas registradas.</p>}
      {periodos.map((clave) => {
        const lista = porPeriodo.get(clave)!.sort((a, b) =>
          (a.curso?.materia?.codigo ?? "").localeCompare(b.curso?.materia?.codigo ?? ""));
        const { anio, periodo: p } = lista[0].curso!;
        return (
          <div className="sga-bloque" key={clave}>
            <h4 className="sga-subtitulo-chico">{periodo(anio, p)}</h4>
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-historia">
                <colgroup>
                  <col className="sga-col-materia" />
                  <col className="sga-col-cursada" />
                  <col className="sga-col-finales" />
                </colgroup>
                <thead>
                  <tr><th rowSpan={2}>Materia</th><th>Cursada</th><th>Finales</th></tr>
                  <tr><th>Nota (Fecha)</th><th>Nota (Fecha)</th></tr>
                </thead>
                <tbody>
                  {lista.map((c) => {
                    const m = c.curso?.materia;
                    const aprobada = c.estado === "APROBADA";
                    return (
                      <tr key={c.id}>
                        <td>
                          {aprobada && <span className="sga-check" aria-label="Aprobada">✔</span>}
                          <strong>{m?.codigo} - {m?.nombre}</strong>{" "}
                          <span className="sga-creditos">({m?.creditos} Créditos) - Comisión {c.comision?.nombre}</span>
                        </td>
                        <td className={c.estado === "CURSANDO" ? "sga-cursando" : "sga-aprobado"}>
                          {c.estado === "CURSANDO"
                            ? `Cursando ${periodo(anio, p)}`
                            : c.estado === "DESAPROBADA" || c.estado === "ABANDONADA"
                              ? <span className="sga-desaprobado">{c.estado === "ABANDONADA" ? "Abandonada" : "Desaprobada"}</span>
                              : `${nota(c.nota_cursada)} ${periodo(anio, p)}`}
                        </td>
                        <td>
                          {c.inscripcion_examen_final.map((f) => (
                            <div className={f.nota_final !== null && f.nota_final >= 4 ? "sga-aprobado" : "sga-desaprobado"} key={f.numero_intento}>
                              {nota(f.nota_final)} ({fecha(f.examen_final?.fecha)})
                            </div>
                          ))}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}
    </>
  );
}
