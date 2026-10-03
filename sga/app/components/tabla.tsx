// Tabla con el estilo del SGA. `filas` vacío muestra "No hay registros".
export default function Tabla({
  columnas,
  filas,
}: {
  columnas: string[];
  filas: { key: string | number; celdas: React.ReactNode[] }[];
}) {
  return (
    <div className="sga-tabla-scroll">
      <table className="sga-tabla">
        <thead>
          <tr>{columnas.map((c) => <th key={c}>{c}</th>)}</tr>
        </thead>
        <tbody>
          {filas.length > 0 ? (
            filas.map((f) => (
              <tr key={f.key}>{f.celdas.map((c, i) => <td key={i}>{c}</td>)}</tr>
            ))
          ) : (
            <tr><td className="sga-vacio" colSpan={columnas.length}>No hay registros para mostrar.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

export function SiNo({ valor }: { valor: boolean | null }) {
  if (valor === null) return null;
  return valor
    ? <span className="sga-si" aria-label="Sí">✔</span>
    : <span className="sga-no" aria-label="No">✘</span>;
}
