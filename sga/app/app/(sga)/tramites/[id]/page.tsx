import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { abierto, destinos, estadosTramite, type Destino, type EstadoTramite } from "@/lib/tramites";
import { cambiarEstadoTramite, cancelarTramite, comentarTramite } from "../actions";

type Tramite = {
  id: number;
  persona_id: number;
  titulo: string;
  destino: Destino;
  descripcion: string;
  estado: EstadoTramite;
  fecha_creacion: string;
  enviado_por: string;
  numero_legajo: string | null;
  asignado_a: string | null;
};
type Movimiento = {
  id: number;
  fecha: string;
  estado: EstadoTramite | null;
  comentario: string | null;
  autor: string | null;
  de_administracion: boolean;
};

// Detalle de un trámite: historial, comentarios y, para Administración,
// tomarlo, resolverlo o rechazarlo.
export default async function DetalleTramite({ params, searchParams }: PageProps<"/tramites/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  const admin = sesion?.roles.includes("ADMINISTRATIVO") ?? false;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: t }, { data: movimientos }] = await Promise.all([
    sga.from("tramite_listado")
      .select("id, persona_id, titulo, destino, descripcion, estado, fecha_creacion, enviado_por, numero_legajo, asignado_a")
      .eq("id", id).maybeSingle<Tramite>(),
    sga.from("tramite_movimiento_listado").select("id, fecha, estado, comentario, autor, de_administracion")
      .eq("tramite_id", id).order("fecha").order("id").returns<Movimiento[]>(),
  ]);
  const volver = admin ? { href: "/administracion/tramites", texto: "Trámites" } : { href: "/tramites", texto: "Historial de trámites" };

  if (!t) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Trámite</h2>
        <p className="sga-error">No se encontró el trámite.</p>
        <Link className="sga-volver" href={volver.href}>← Volver a {volver.texto}</Link>
      </section>
    );
  }

  const propio = t.persona_id === sesion?.persona?.id;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{t.titulo}</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      <dl className="sga-datos sga-datos-tramite">
        <div><dt>Enviado por:</dt><dd>{t.enviado_por}{t.numero_legajo && ` (legajo ${t.numero_legajo})`}</dd></div>
        <div><dt>Fecha de creación:</dt><dd>{fechaHora(t.fecha_creacion)}</dd></div>
        <div><dt>Destino:</dt><dd>{destinos[t.destino]}</dd></div>
        <div><dt>Asignado a:</dt><dd>{t.asignado_a ?? "Todavía nadie lo tomó"}</dd></div>
        <div>
          <dt>Estado:</dt>
          <dd><span className={`sga-estado-encuesta ${estadosTramite[t.estado].clase}`}>{estadosTramite[t.estado].texto}</span></dd>
        </div>
      </dl>
      <div className="sga-caja sga-tramite-detalle">{t.descripcion}</div>

      <h3 className="sga-subtitulo">Historial</h3>
      <ol className="sga-tramite-historial">
        {(movimientos ?? []).map((m) => (
          <li className={m.de_administracion ? "sga-tramite-admin" : undefined} key={m.id}>
            <div className="sga-post-meta">
              <strong>{m.autor ?? "Sistema"}</strong>
              {m.de_administracion && <span>(Administración)</span>}
              <span>· {fechaHora(m.fecha)}</span>
              {m.estado && <span className={`sga-estado-encuesta ${estadosTramite[m.estado].clase}`}>{estadosTramite[m.estado].texto}</span>}
            </div>
            {m.comentario && <p>{m.comentario}</p>}
          </li>
        ))}
      </ol>

      {abierto(t.estado) && (propio || admin) && (
        <form action={comentarTramite} className="sga-form-comentario">
          <input name="id" type="hidden" value={t.id} />
          <textarea aria-label="Comentario" maxLength={8000} name="comentario" placeholder="Agregar un comentario" required rows={3} />
          <button type="submit">Comentar</button>
        </form>
      )}

      {propio && t.estado === "PENDIENTE" && (
        <form action={cancelarTramite} className="sga-acciones-doc">
          <input name="id" type="hidden" value={t.id} />
          <button className="sga-boton-peligro" type="submit">Cancelar trámite</button>
        </form>
      )}

      {admin && abierto(t.estado) && (
        <>
          <h3 className="sga-subtitulo">Gestionar</h3>
          <div className="sga-acciones-doc sga-tramite-gestion">
            {t.estado === "PENDIENTE" && (
              <form action={cambiarEstadoTramite}>
                <input name="id" type="hidden" value={t.id} />
                <button name="estado" type="submit" value="EN_CURSO">Tomar trámite</button>
              </form>
            )}
            <form action={cambiarEstadoTramite}>
              <input name="id" type="hidden" value={t.id} />
              <input aria-label="Comentario de la resolución" name="comentario" placeholder="Comentario (opcional)" />
              <button name="estado" type="submit" value="RESUELTO">Resolver</button>
            </form>
            <form action={cambiarEstadoTramite}>
              <input name="id" type="hidden" value={t.id} />
              <input aria-label="Motivo del rechazo" name="comentario" placeholder="Motivo del rechazo" required />
              <button className="sga-boton-peligro" name="estado" type="submit" value="RECHAZADO">Rechazar</button>
            </form>
          </div>
        </>
      )}

      <Link className="sga-volver" href={volver.href}>← Volver a {volver.texto}</Link>
    </section>
  );
}
