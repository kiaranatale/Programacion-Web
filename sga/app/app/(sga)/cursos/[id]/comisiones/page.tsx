import { formatearHorario } from "@/lib/cursos";
import { getCurso } from "@/lib/curso";

export default async function Comisiones({ params }: PageProps<"/cursos/[id]/comisiones">) {
  const curso = await getCurso(Number((await params).id));
  if (!curso) return null;
  const comisiones = [...curso.comision].sort((a, b) => a.nombre.localeCompare(b.nombre));

  return (
    <div className="sga-tabla-scroll">
      <table className="sga-tabla">
        <thead><tr><th>Comisión</th><th>Cupo</th><th>Horarios</th></tr></thead>
        <tbody>
          {comisiones.length > 0 ? comisiones.map((c) => (
            <tr key={c.id}>
              <td><strong>{c.nombre}</strong></td>
              <td>{c.cupo ?? "—"}</td>
              <td className="sga-horarios">
                {c.horario_comision.length > 0 ? c.horario_comision.map(formatearHorario).join(" | ") : "Sin horarios cargados"}
              </td>
            </tr>
          )) : (
            <tr><td className="sga-vacio" colSpan={3}>Este curso todavía no tiene comisiones cargadas.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
