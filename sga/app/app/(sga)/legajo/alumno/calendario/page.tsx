import { getCursadas } from "@/lib/cursadas";
import { fecha, getLegajoActual, periodo } from "@/lib/legajo";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";

type Suspendida = { codigo: string; materia: string; comision: string; fecha_inicio: string; fecha_fin: string; docente: string };

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

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const sesion = await getSesion();
  const [cursadas, { data: suspendidasData }] = await Promise.all([
    getCursadas(legajo.id),
    sga.rpc("clases_suspendidas_para_mi"),
    // Al ver el calendario, los avisos de clases suspendidas quedan leídos
    sga.from("notificacion").update({ leida: true }).eq("persona_id", sesion?.persona?.id ?? 0).eq("tipo", "AUSENCIA").eq("leida", false),
  ]);
  const suspendidas = (suspendidasData ?? []) as Suspendida[];
  const cursando = cursadas.filter((c) => c.estado === "CURSANDO");
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
      {suspendidas.length > 0 && (
        <div className="sga-alerta sga-suspendidas">
          <strong>Clases suspendidas</strong>
          <ul>
            {suspendidas.map((c, i) => (
              <li key={i}>
                {c.codigo} {c.materia} · comisión {c.comision} ·{" "}
                {c.fecha_inicio === c.fecha_fin ? `el ${fecha(c.fecha_inicio)}` : `del ${fecha(c.fecha_inicio)} al ${fecha(c.fecha_fin)}`} (ausencia de {c.docente})
              </li>
            ))}
          </ul>
        </div>
      )}
      {/* En el celular: lista por día en vez de la grilla */}
      <div className="sga-calendario-lista">
        {[...dias.slice(1), dias[0]].map(([dia, nombre]) => {
          const delDia = bloques.filter((b) => b.dia === dia).sort((a, b) => a.desde - b.desde);
          return delDia.length === 0 ? null : (
            <div key={dia}>
              <h4>{nombre}</h4>
              <ul>
                {delDia.map((b, i) => (
                  <li key={i} style={{ borderColor: b.color }}>{aHora(b.desde)} a {aHora(b.hasta)} · {b.texto}</li>
                ))}
              </ul>
            </div>
          );
        })}
        {bloques.length === 0 && <p className="sga-vacio">No tenés clases esta semana.</p>}
      </div>
      <div className="sga-tabla-scroll sga-calendario-tabla">
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
