import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { autor, cuandoEvento, fechaHora, getPublicacion, tipos } from "@/lib/hoy";
import { borrarComentario, borrarPublicacion, comentar } from "../actions";

type Comentario = {
  id: number;
  cuerpo: string;
  creado: string;
  autor_apellido: string | null;
  autor_nombre: string | null;
  puede_borrar: boolean;
};

export default async function DetallePublicacion({ params, searchParams }: PageProps<"/hoy/[id]">) {
  const publicacion = await getPublicacion(Number((await params).id));
  if (!publicacion) notFound();
  const { ok, error } = await searchParams;

  const supabase = await createClient();
  const { data: comentarios } = await supabase
    .schema("sga")
    .from("comentario_listado")
    .select("id, cuerpo, creado, autor_apellido, autor_nombre, puede_borrar")
    .eq("publicacion_id", publicacion.id)
    .order("creado")
    .returns<Comentario[]>();

  const p = publicacion;
  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Hoy en el ITBA</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <article className="sga-post sga-post-completo">
        <header>
          <span className={`sga-etiqueta sga-etiqueta-${p.tipo.toLowerCase()}`}>{tipos[p.tipo]}</span>
          <Link className="sga-post-org" href={`/hoy?org=${p.organizacion_id}`}>{p.organizacion}</Link>
          <span className="sga-post-meta">
            {fechaHora(p.creada)}{autor(p) && ` · ${autor(p)}`}{p.editada && ` · editada ${fechaHora(p.editada)}`}
          </span>
        </header>
        <h3>{p.titulo}</h3>
        {p.tipo === "EVENTO" && (
          <p className="sga-post-evento">📅 {cuandoEvento(p.fecha_evento, p.hora_evento)}{p.lugar && ` · ${p.lugar}`}</p>
        )}
        <p className="sga-post-cuerpo">{p.cuerpo}</p>
        {p.puede_editar && (
          <div className="sga-acciones-form">
            <Link href={`/hoy/${p.id}/editar`}>Editar</Link>
            <form action={borrarPublicacion}>
              <input name="id" type="hidden" value={p.id} />
              <button className="sga-boton-peligro" type="submit">Borrar publicación</button>
            </form>
          </div>
        )}
      </article>

      <h3 className="sga-subtitulo" id="comentarios">Comentarios ({comentarios?.length ?? 0})</h3>
      <ul className="sga-comentarios">
        {(comentarios ?? []).map((c) => (
          <li key={c.id}>
            <div className="sga-post-meta">
              <strong>{autor(c) ?? "Usuario eliminado"}</strong> · {fechaHora(c.creado)}
              {c.puede_borrar && (
                <form action={borrarComentario}>
                  <input name="id" type="hidden" value={c.id} />
                  <input name="publicacion_id" type="hidden" value={p.id} />
                  <button type="submit">Borrar</button>
                </form>
              )}
            </div>
            <p>{c.cuerpo}</p>
          </li>
        ))}
      </ul>
      <form action={comentar} className="sga-form-comentario">
        <input name="publicacion_id" type="hidden" value={p.id} />
        <textarea aria-label="Comentario" maxLength={2000} name="cuerpo" placeholder="Escribí un comentario" required rows={3} />
        <div className="sga-acciones-form"><button type="submit">Comentar</button></div>
      </form>

      <Link className="sga-volver" href="/hoy">← Volver a Hoy en el ITBA</Link>
    </section>
  );
}
