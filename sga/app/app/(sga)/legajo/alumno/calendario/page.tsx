import { getCursadas } from "@/lib/cursadas";
import { getLegajoActual, periodo } from "@/lib/legajo";

const dias = [
  ["DOMINGO", "Domingo"], ["LUNES", "Lunes"], ["MARTES", "Martes"], ["MIERCOLES", "Miércoles"],
  ["JUEVES", "Jueves"], ["VIERNES", "Viernes"], ["SABADO", "Sábado"],
] as const;
const colores = ["#f26b6b", "#9fc8f5", "#c9ef9f", "#a9a2f2", "#5fd6e8", "#f5c26b", "#d5a6f0", "#8fe0b8"];

const aMinutos = (h: string) => Number(h.slice(0, 2)) * 60 + Number(h.slice(3, 5));
const aHora = (m: number) => `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;

export default async function CalendarioSemanal() {
  const { legajo } = await getLegajoActual();
  if (!legajo) return null;

  const cursando = (await getCursadas(legajo.id)).filter((c) => c.estado === "CURSANDO");
  const bloques = cursando.flatMap((c, i) =>
    (c.comision?.horario_comision ?? []).map((h) => ({
      dia: h.dia_semana,
      desde: aMinutos(h.hora_inicio),
      hasta: aMinutos(h.hora_fin),
      texto: `${c.curso?.materia?.codigo} - ${c.curso?.materia?.nombre}`,
      color: colores[i % colores.length],
    })),
  );

  // Franjas de 30 minutos entre las 8 y las 23
  const franjas: number[] = [];
  for (let m = 8 * 60; m < 23 * 60; m += 30) franjas.push(m);

  const actual = cursando[0]?.curso;

  return (
    <>
      <p className="sga-texto">
        Calendario actual: <strong>{actual ? periodo(actual.anio, actual.periodo) : "sin cursadas en curso"}</strong>
      </p>
      <div className="sga-tabla-scroll">
        <table className="sga-calendario">
          <thead>
            <tr><th></th>{dias.map(([, nombre]) => <th key={nombre}>{nombre}</th>)}</tr>
          </thead>
          <tbody>
            {franjas.map((m) => (
              <tr key={m}>
                <th>{aHora(m)}</th>
                {dias.map(([dia]) => {
                  const b = bloques.find((x) => x.dia === dia && x.desde <= m && m < x.hasta);
                  return (
                    <td key={dia} style={b ? { background: b.color } : undefined}>
                      {b?.texto}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
