import { createClient } from "@/lib/supabase/server";
import { diaYHora } from "@/lib/finales";
import { fechaHora } from "@/lib/hoy";
import { anotarme, darmeDeBaja } from "./actions";

type Evento = {
  evento_id: number;
  nombre: string;
  tipo: string | null;
  descripcion: string | null;
  fecha: string;
  hora_inicio: string;
  hora_fin: string;
  aula: string | null;
  edificio: string | null;
  cupo: number | null;
  inscriptos: number;
  cierre: string;
  inscripto: boolean;
};

// Inscripción a eventos académicos: charlas, jornadas y talleres
// próximos con inscripción.
export default async function InscripcionEventos({ searchParams }: PageProps<"/inscripciones/eventos">) {
  const { ok, error } = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").rpc("eventos_para_mi");
  const eventos = (data ?? []) as Evento[];
  const ahora = new Date().toISOString();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Inscripción a eventos académicos</h2>
      <p className="sga-texto">Charlas, jornadas y talleres. Te podés anotar o dar de baja hasta que cierre la inscripción.</p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {eventos.length === 0 && <p className="sga-vacio">No hay eventos con inscripción abierta.</p>}

      {eventos.map((e) => {
        const cerrada = ahora >= e.cierre;
        const lleno = e.cupo !== null && e.inscriptos >= e.cupo;
        return (
          <article className={`sga-post ${e.inscripto ? "sga-post-anotado" : ""}`} key={e.evento_id}>
            <header>
              {e.tipo && <span className="sga-etiqueta sga-etiqueta-evento">{e.tipo}</span>}
              {e.inscripto && <strong className="sga-al-dia">Anotado ✓</strong>}
            </header>
            <h3>{e.nombre}</h3>
            <p className="sga-post-evento">
              📅 {diaYHora(e.fecha, e.hora_inicio)} a {e.hora_fin.slice(0, 5)} hs
              {e.aula && ` · Aula ${e.aula}${e.edificio ? ` (${e.edificio})` : ""}`}
            </p>
            {e.descripcion && <p className="sga-post-cuerpo">{e.descripcion}</p>}
            <p className="sga-ayuda">
              {e.cupo === null ? `${e.inscriptos} anotados` : `${Math.max(e.cupo - e.inscriptos, 0)} lugares libres de ${e.cupo}`}
              {" · "}Inscripción hasta el {fechaHora(e.cierre)}
            </p>
            <div className="sga-acciones-form">
              {e.inscripto ? (
                !cerrada && (
                  <form action={darmeDeBaja}>
                    <input name="evento_id" type="hidden" value={e.evento_id} />
                    <input name="nombre" type="hidden" value={e.nombre} />
                    <button className="sga-boton-peligro" type="submit">Darme de baja</button>
                  </form>
                )
              ) : cerrada ? (
                <span className="sga-ayuda">La inscripción cerró.</span>
              ) : lleno ? (
                <span className="sga-ayuda">No quedan lugares.</span>
              ) : (
                <form action={anotarme}>
                  <input name="evento_id" type="hidden" value={e.evento_id} />
                  <input name="nombre" type="hidden" value={e.nombre} />
                  <button type="submit">Anotarme</button>
                </form>
              )}
            </div>
          </article>
        );
      })}
    </section>
  );
}
