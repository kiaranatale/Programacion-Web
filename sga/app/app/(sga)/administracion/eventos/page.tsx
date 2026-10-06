import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { diaYHora } from "@/lib/finales";
import { fechaHora, hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import { borrarEvento, cambiarInscripcion, crearEvento } from "./actions";

type Evento = {
  id: number;
  nombre: string;
  tipo: string | null;
  fecha: string;
  hora_inicio: string;
  hora_fin: string;
  cupo: number | null;
  con_inscripcion: boolean;
  inscripcion_hasta: string | null;
  aula: { codigo: string } | null;
  evento_inscripcion: { fecha: string; persona: { apellido: string; nombre: string; mail_institucional: string } | null }[];
};

// Eventos académicos: alta, inscripción y lista de anotados.
export default async function EventosAcademicos({ searchParams }: PageProps<"/administracion/eventos">) {
  const { ok, error, ver } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Eventos académicos</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("evento_academico")
    .select("id, nombre, tipo, fecha, hora_inicio, hora_fin, cupo, con_inscripcion, inscripcion_hasta, aula:aula_id(codigo), evento_inscripcion(fecha, persona:persona_id(apellido, nombre, mail_institucional))")
    .gte("fecha", hoy())
    .order("fecha").order("hora_inicio")
    .returns<Evento[]>();
  const eventos = data ?? [];
  const elegido = eventos.find((e) => String(e.id) === ver);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Eventos académicos</h2>
      <p className="sga-texto">Próximos eventos. Los que tienen inscripción aparecen en Inicio → Trámites → Inscripción a eventos académicos.</p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Evento</th><th>Fecha</th><th>Aula</th><th>Inscripción</th><th>Anotados</th><th>Acciones</th></tr></thead>
          <tbody>
            {eventos.length > 0 ? eventos.map((e) => (
              <tr key={e.id}>
                <td><strong>{e.nombre}</strong>{e.tipo && <div className="sga-ayuda">{e.tipo}</div>}</td>
                <td>{diaYHora(e.fecha, e.hora_inicio)} a {e.hora_fin.slice(0, 5)}</td>
                <td>{e.aula?.codigo ?? "—"}</td>
                <td>
                  {e.con_inscripcion ? "Sí" : "No"}
                  {e.con_inscripcion && e.inscripcion_hasta && <div className="sga-ayuda">hasta {fechaHora(e.inscripcion_hasta)}</div>}
                </td>
                <td className="sga-col-cupo">
                  <Link href={`?ver=${e.id}`}>{e.evento_inscripcion.length}{e.cupo !== null && `/${e.cupo}`}</Link>
                </td>
                <td className="sga-acciones-doc">
                  <form action={cambiarInscripcion}>
                    <input name="id" type="hidden" value={e.id} />
                    <input name="abrir" type="hidden" value={e.con_inscripcion ? "0" : "1"} />
                    <button className={e.con_inscripcion ? "sga-boton-peligro" : undefined} type="submit">
                      {e.con_inscripcion ? "Cerrar inscripción" : "Habilitar inscripción"}
                    </button>
                  </form>
                  <form action={borrarEvento}>
                    <input name="id" type="hidden" value={e.id} />
                    <button className="sga-boton-peligro" type="submit">Borrar</button>
                  </form>
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={6}>No hay eventos próximos.</td></tr>}
          </tbody>
        </table>
      </div>

      {elegido && (
        <>
          <h3 className="sga-subtitulo">Anotados a {elegido.nombre} ({elegido.evento_inscripcion.length})</h3>
          {elegido.evento_inscripcion.length > 0 ? (
            <ol className="sga-lista-inscriptos">
              {elegido.evento_inscripcion.filter((i) => i.persona)
                .sort((a, b) => a.persona!.apellido.localeCompare(b.persona!.apellido))
                .map((i) => <li key={i.persona!.mail_institucional}>{i.persona!.apellido}, {i.persona!.nombre} · {i.persona!.mail_institucional}</li>)}
            </ol>
          ) : <p className="sga-vacio">Todavía nadie se anotó.</p>}
          <Link className="sga-volver" href="/administracion/eventos">Ocultar lista</Link>
        </>
      )}

      <h3 className="sga-subtitulo">Nuevo evento</h3>
      <form action={crearEvento} className="sga-form-publicacion">
        <label><span>Nombre</span><input name="nombre" required /></label>
        <label><span>Tipo</span><input name="tipo" placeholder="Charla, Jornada, Taller…" /></label>
        <label><span>Descripción</span><textarea name="descripcion" rows={3} /></label>
        <fieldset>
          <legend>Cuándo y dónde</legend>
          <label><span>Fecha</span><input name="fecha" required type="date" /></label>
          <label><span>Desde</span><input defaultValue="18:00" name="hora_inicio" required type="time" /></label>
          <label><span>Hasta</span><input defaultValue="20:00" name="hora_fin" required type="time" /></label>
          <label><span>Aula</span><input name="aula" placeholder="Código (opcional)" /></label>
        </fieldset>
        <fieldset>
          <legend>Inscripción</legend>
          <label className="sga-check"><input defaultChecked name="con_inscripcion" type="checkbox" value="1" /> <span>Con inscripción</span></label>
          <label><span>Cupo</span><input min={1} name="cupo" placeholder="Sin límite" type="number" /></label>
          <label><span>Cierra el</span><input name="cierre_fecha" type="date" /></label>
          <label><span>a las</span><input name="cierre_hora" type="time" /></label>
        </fieldset>
        <p className="sga-ayuda">Si no indicás el cierre, la inscripción cierra cuando empieza el evento.</p>
        <div className="sga-acciones-form"><button type="submit">Crear evento</button></div>
      </form>
    </section>
  );
}
