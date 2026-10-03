import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import type { Enviado, Recibido } from "@/lib/mensajes";
import { responderMensaje } from "../actions";

// Un mensaje recibido (se marca como leído y se puede responder) o uno
// enviado (con cuántos lo leyeron).
export default async function DetalleMensaje({ params, searchParams }: PageProps<"/usuario/mensajes/[id]">) {
  const id = Number((await params).id);
  if (!Number.isInteger(id)) notFound();
  const { ok, error } = await searchParams;

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: recibido }, { data: enviado }] = await Promise.all([
    sga.from("mensaje_recibido").select("*").eq("id", id).maybeSingle<Recibido>(),
    sga.from("mensaje_enviado").select("*").eq("id", id).maybeSingle<Enviado>(),
  ]);
  const mensaje = recibido ?? enviado;
  if (!mensaje) notFound();
  if (recibido && !recibido.leido_en) await sga.rpc("marcar_mensaje_leido", { p_mensaje_id: id });

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Mensajes</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <article className="sga-post sga-mensaje">
        <h3>{mensaje.asunto}</h3>
        <dl className="sga-mensaje-datos">
          {recibido && <div><dt>De:</dt><dd>{recibido.remitente_apellido}, {recibido.remitente_nombre}</dd></div>}
          <div><dt>Para:</dt><dd>{mensaje.destino_descripcion}</dd></div>
          <div><dt>Fecha:</dt><dd>{fechaHora(mensaje.fecha)}</dd></div>
          {enviado && <div><dt>Leído por:</dt><dd>{enviado.leidos} de {enviado.destinatarios}</dd></div>}
          {mensaje.respuesta_a_id && (
            <div><dt>En respuesta a:</dt><dd><Link href={`/usuario/mensajes/${mensaje.respuesta_a_id}`}>ver mensaje original</Link></dd></div>
          )}
        </dl>
        <p className="sga-post-cuerpo">{mensaje.cuerpo}</p>
      </article>

      {recibido && (
        <form action={responderMensaje} className="sga-form-comentario">
          <input name="mensaje_id" type="hidden" value={recibido.id} />
          <h3 className="sga-subtitulo">Responder a {recibido.remitente_nombre} {recibido.remitente_apellido}</h3>
          <textarea aria-label="Respuesta" maxLength={5000} name="cuerpo" required rows={5} />
          <div className="sga-acciones-form"><button type="submit">Enviar respuesta</button></div>
        </form>
      )}

      <Link className="sga-volver" href={recibido ? "/usuario/mensajes" : "/usuario/mensajes/enviados"}>← Volver a Mensajes</Link>
    </section>
  );
}
