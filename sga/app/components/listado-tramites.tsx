import Link from "next/link";
import { fechaHora } from "@/lib/hoy";
import { consulta, destinos, estadosTramite, type FiltrosTramites, type TramiteListado } from "@/lib/tramites";

type Props = {
  base: string; // página del listado (los filtros vuelven acá)
  filtros: FiltrosTramites;
  tramites: TramiteListado[];
  todos?: boolean; // Administración: trámites de todos, con destino
};

// Listado de trámites como el del SGA: filtros por fecha de creación,
// título y estado, orden por fecha y descarga en CSV.
export default function ListadoTramites({ base, filtros, tramites, todos: conDestino }: Props) {
  const otroOrden = consulta({ ...filtros, orden: filtros.orden === "desc" ? "asc" : "desc" });
  const columnas = conDestino ? 7 : 6;
  return (
    <>
      <h3 className="sga-titulo">Trámites</h3>
      <p className="sga-referencias"><strong>Referencias:</strong> 🔍 = Ver detalles</p>
      <a className="sga-csv" href={`/tramites/csv${consulta(filtros, conDestino ? { todos: "1" } : {})}`}>💾 Descargar los datos en formato CSV</a>
      <form action={base} className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead>
            <tr>
              <th>Enviado por</th>
              <th aria-sort={filtros.orden === "asc" ? "ascending" : "descending"}>
                <Link className="sga-orden" href={`${base}${otroOrden}`}>Fecha de creación {filtros.orden === "asc" ? "▲" : "▼"}</Link>
              </th>
              <th>Título</th>
              {conDestino && <th>Destino</th>}
              <th>Asignado a</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
            <tr className="sga-fila-filtros">
              <th></th>
              <th>
                <div className="sga-filtro-fechas">
                  De: <input aria-label="Creado desde" defaultValue={filtros.desde} name="desde" type="date" />
                  A: <input aria-label="Creado hasta" defaultValue={filtros.hasta} name="hasta" type="date" />
                </div>
              </th>
              <th><input aria-label="Filtrar por título" defaultValue={filtros.titulo} name="titulo" type="text" /></th>
              {conDestino && <th></th>}
              <th></th>
              <th>
                <select aria-label="Filtrar por estado" defaultValue={filtros.estado} name="estado">
                  <option value=""></option>
                  {Object.entries(estadosTramite).map(([valor, e]) => <option key={valor} value={valor}>{e.texto}</option>)}
                </select>
              </th>
              <th>
                {filtros.orden === "asc" && <input name="orden" type="hidden" value="asc" />}
                <button aria-label="Aplicar filtros" title="Aplicar filtros" type="submit">⏷</button>
                <Link aria-label="Quitar filtros" href={base} title="Quitar filtros">✕</Link>
              </th>
            </tr>
          </thead>
          <tbody>
            {tramites.length > 0 ? tramites.map((t) => (
              <tr key={t.id}>
                <td>{t.enviado_por}{t.numero_legajo && <div className="sga-ayuda">{t.numero_legajo}</div>}</td>
                <td>{fechaHora(t.fecha_creacion)}</td>
                <td>{t.titulo}</td>
                {conDestino && <td>{destinos[t.destino]}</td>}
                <td>{t.asignado_a ?? "—"}</td>
                <td><span className={`sga-estado-encuesta ${estadosTramite[t.estado].clase}`}>{estadosTramite[t.estado].texto}</span></td>
                <td className="sga-col-lupa"><Link aria-label={`Ver detalles de ${t.titulo}`} href={`/tramites/${t.id}`}>🔍</Link></td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={columnas}>No hay trámites.</td></tr>}
          </tbody>
        </table>
      </form>
    </>
  );
}
