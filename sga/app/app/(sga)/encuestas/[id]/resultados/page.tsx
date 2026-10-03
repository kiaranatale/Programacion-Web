import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { escala, estados, type EncuestaResumen } from "@/lib/encuestas";
import { fecha } from "@/lib/legajo";

type Resultado = {
  pregunta_id: number;
  orden: number;
  texto: string;
  tipo: "ESCALA" | "TEXTO";
  respuestas: number;
  promedio: number | null;
  distribucion: number[] | null;
  textos: string[] | null;
};

// Resultados agregados y anónimos de una encuesta.
export default async function ResultadosEncuesta({ params }: PageProps<"/encuestas/[id]/resultados">) {
  const id = Number((await params).id);
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: resumen }, { data, error }] = await Promise.all([
    sga.rpc("encuestas_resumen"),
    sga.rpc("resultados_encuesta", { p_encuesta_id: id }),
  ]);
  const encuesta = ((resumen ?? []) as EncuestaResumen[]).find((e) => e.id === id);
  const resultados = (data ?? []) as Resultado[];

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Resultados{encuesta ? `: ${encuesta.nombre}` : ""}</h2>
      {encuesta && (
        <dl className="sga-mensaje-datos">
          {encuesta.sobre && <div><dt>Sobre:</dt><dd>{encuesta.sobre}</dd></div>}
          <div><dt>Período:</dt><dd>{fecha(encuesta.fecha_inicio)} al {fecha(encuesta.fecha_fin)} ({estados[encuesta.estado]})</dd></div>
          <div><dt>Respuestas:</dt><dd>{encuesta.respuestas} de {encuesta.destinatarios}</dd></div>
        </dl>
      )}

      {error ? (
        <p className="sga-error">
          Los resultados todavía no están disponibles: se publican cuando la encuesta termina y la respondieron al menos
          3 alumnos.
        </p>
      ) : resultados.map((r) => (
        <div className="sga-post" key={r.pregunta_id}>
          <h3>{r.orden}. {r.texto}</h3>
          {r.tipo === "ESCALA" ? (
            <>
              <p className="sga-post-evento">Promedio: {r.promedio ?? "—"} / 5 · {r.respuestas === 1 ? "1 respuesta" : `${r.respuestas} respuestas`}</p>
              <ul className="sga-barras">
                {(r.distribucion ?? []).map((n, i) => {
                  const porcentaje = r.respuestas ? Math.round((n / r.respuestas) * 100) : 0;
                  return (
                    <li key={i}>
                      <span>{i + 1} · {escala[i]}</span>
                      <span className="sga-barra"><span style={{ width: `${porcentaje}%` }} /></span>
                      <span>{n} ({porcentaje}%)</span>
                    </li>
                  );
                })}
              </ul>
            </>
          ) : r.textos && r.textos.length > 0 ? (
            <ul className="sga-comentarios">{r.textos.map((t, i) => <li key={i}><p>{t}</p></li>)}</ul>
          ) : (
            <p className="sga-vacio">Sin comentarios.</p>
          )}
        </div>
      ))}
      <Link className="sga-volver" href="/encuestas">← Volver a Encuestas</Link>
    </section>
  );
}
