import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { escala, estados, type EncuestaParaMi } from "@/lib/encuestas";
import { fecha } from "@/lib/legajo";
import { responderEncuesta } from "../actions";

type Pregunta = { id: number; orden: number; texto: string; tipo: "ESCALA" | "TEXTO" };

export default async function ResponderEncuesta({ params, searchParams }: PageProps<"/encuestas/[id]">) {
  const id = Number((await params).id);
  if (!Number.isInteger(id)) notFound();
  const { error } = await searchParams;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: mias }, { data: encuesta }, { data: preguntas }] = await Promise.all([
    sga.rpc("encuestas_para_mi"),
    sga.from("encuesta").select("id, descripcion").eq("id", id).maybeSingle<{ id: number; descripcion: string | null }>(),
    sga.from("encuesta_pregunta").select("id, orden, texto, tipo").eq("encuesta_id", id).order("orden").returns<Pregunta[]>(),
  ]);
  if (!encuesta) notFound();
  const mia = ((mias ?? []) as EncuestaParaMi[]).find((e) => e.id === id);

  const aviso = !mia ? "Esta encuesta no es para vos."
    : mia.respondida ? "Ya respondiste esta encuesta. ¡Gracias!"
    : mia.estado !== "ACTIVA" ? `La encuesta está ${estados[mia.estado]?.toLowerCase()}: se puede responder del ${fecha(mia.fecha_inicio)} al ${fecha(mia.fecha_fin)}.`
    : null;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{mia?.nombre ?? "Encuesta"}</h2>
      {mia?.sobre && <p className="sga-texto"><strong>Sobre:</strong> {mia.sobre}</p>}
      {encuesta.descripcion && <p className="sga-texto">{encuesta.descripcion}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {aviso ? <p className="sga-error">{aviso}</p> : (
        <form action={responderEncuesta} className="sga-form-encuesta">
          <input name="encuesta_id" type="hidden" value={id} />
          <p className="sga-texto">Tus respuestas son anónimas. Las preguntas de escala son obligatorias.</p>
          {(preguntas ?? []).map((p) => (
            <fieldset key={p.id}>
              <legend>{p.orden}. {p.texto}</legend>
              {p.tipo === "ESCALA" ? (
                <div className="sga-escala">
                  {escala.map((etiqueta, i) => (
                    <label key={i}>
                      <input name={`e_${p.id}`} required type="radio" value={i + 1} />
                      <span>{i + 1}</span>
                      <small>{etiqueta}</small>
                    </label>
                  ))}
                </div>
              ) : (
                <textarea aria-label={p.texto} maxLength={1000} name={`t_${p.id}`} rows={4} />
              )}
            </fieldset>
          ))}
          <div className="sga-acciones-form"><button type="submit">Enviar respuestas</button></div>
        </form>
      )}
      <Link className="sga-volver" href="/encuestas">← Volver a Encuestas</Link>
    </section>
  );
}
