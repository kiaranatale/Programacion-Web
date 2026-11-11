import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora, hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { asignarAutomaticamente, confirmarAsignacion, marcarSolicitud } from "./actions";

type Periodo = {
  id: number; anio: number; periodo: string; desde: string; hasta: string;
  segunda_desde: string | null; segunda_hasta: string | null; asignacion_confirmada: boolean;
};
type Solicitud = {
  solicitud_id: number;
  comision_id: number;
  codigo: string;
  materia: string;
  comision: string;
  cupo: number | null;
  ya_inscriptos: number;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  creditos_aprobados: number;
  rendimiento: number | null;
  fecha: string;
  estado: "PENDIENTE" | "ASIGNADA" | "NO_ASIGNADA";
};

const etiquetaEstado: Record<Solicitud["estado"], { texto: string; clase: string }> = {
  PENDIENTE: { texto: "Pendiente", clase: "sga-estado-programada" },
  ASIGNADA: { texto: "Asignada", clase: "sga-estado-activa" },
  NO_ASIGNADA: { texto: "No asignada", clase: "sga-estado-finalizada" },
};

// Solicitudes de la primera inscripción y asignación de vacantes.
export default async function AsignacionDeVacantes({ params, searchParams }: PageProps<"/administracion/inscripciones/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Asignación de vacantes</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: p }, { data }] = await Promise.all([
    sga.from("periodo_inscripcion_cursada")
      .select("id, anio, periodo, desde, hasta, segunda_desde, segunda_hasta, asignacion_confirmada")
      .eq("id", id).maybeSingle<Periodo>(),
    sga.rpc("solicitudes_cursada", { p_periodo_id: id }),
  ]);

  if (!p) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Asignación de vacantes</h2>
        <p className="sga-error">El período no existe.</p>
        <Link className="sga-volver" href="/administracion/inscripciones">← Volver a Inscripción a cursadas</Link>
      </section>
    );
  }

  const solicitudes = (data ?? []) as Solicitud[];
  const comisiones = new Map<number, Solicitud[]>();
  for (const s of solicitudes) comisiones.set(s.comision_id, [...(comisiones.get(s.comision_id) ?? []), s]);
  const editable = !p.asignacion_confirmada && hoy() > p.hasta;
  const pendientes = solicitudes.filter((s) => s.estado === "PENDIENTE").length;
  const asignadas = solicitudes.filter((s) => s.estado === "ASIGNADA").length;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Asignación de vacantes · {periodo(p.anio, p.periodo)}</h2>
      <p className="sga-texto">
        Primera inscripción del {fecha(p.desde)} al {fecha(p.hasta)}
        {p.segunda_desde && p.segunda_hasta ? <> · Segunda inscripción del {fecha(p.segunda_desde)} al {fecha(p.segunda_hasta)}</> : <> · Sin fechas de segunda inscripción</>}.
      </p>
      <p className="sga-texto">
        Pautas: en cada comisión tienen prioridad los alumnos con <strong>más créditos aprobados</strong>; a igualdad, el
        de <strong>mejor rendimiento académico</strong>; y si siguen empatados, el que solicitó primero. La lista de cada
        comisión ya está ordenada así. Podés asignar automáticamente y después corregir a mano.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {p.asignacion_confirmada ? (
        <p className="sga-mensaje-ok">La asignación está confirmada: los asignados ya están inscriptos y cada alumno lo ve en la segunda inscripción.</p>
      ) : !editable ? (
        <p className="sga-ayuda">La asignación se hace cuando termina la primera inscripción (el {fecha(p.hasta)}).</p>
      ) : (
        <>
          {asignadas > 0 && (
            <p className="sga-panel sga-aviso" role="status">
              {asignadas === 1 ? "Hay 1 solicitud asignada" : `Hay ${asignadas} solicitudes asignadas`} que los alumnos todavía
              no ven: quedan inscriptos recién cuando confirmes la asignación.
            </p>
          )}
          <div className="sga-form-fecha-final">
            <form action={asignarAutomaticamente}>
              <input name="periodo_id" type="hidden" value={p.id} />
              <button className="sga-boton-secundario" type="submit">Asignar automáticamente</button>
            </form>
            <form action={confirmarAsignacion}>
              <input name="periodo_id" type="hidden" value={p.id} />
              <button type="submit">Confirmar asignación</button>
            </form>
            <span className="sga-ayuda">
              {asignadas} asignadas · {pendientes} pendientes. Al confirmar, las asignadas quedan inscriptas y las pendientes, como no asignadas.
            </span>
          </div>
        </>
      )}

      {comisiones.size === 0 && <p className="sga-vacio">Nadie hizo solicitudes en este cuatrimestre.</p>}
      {[...comisiones.values()].map((lista) => {
        const c = lista[0];
        const asignadasComision = lista.filter((s) => s.estado === "ASIGNADA").length;
        const vacantes = c.cupo === null ? null : Math.max(c.cupo - c.ya_inscriptos, 0);
        const excedida = vacantes !== null && !p.asignacion_confirmada && asignadasComision > vacantes;
        return (
          <div key={c.comision_id}>
            <h3 className="sga-subtitulo">{c.codigo} - {c.materia} · Comisión {c.comision}</h3>
            <p className={excedida ? "sga-mensaje-error" : "sga-ayuda"}>
              {vacantes === null ? "Sin cupo" : `${vacantes} vacantes`} · {lista.length} solicitudes · {asignadasComision} asignadas
              {excedida && " · hay más asignados que vacantes"}
            </p>
            <div className="sga-tabla-scroll">
              <table className="sga-tabla sga-tabla-mensajes">
                <thead>
                  <tr><th>#</th><th>Alumno</th><th>Legajo</th><th>Créditos</th><th>Rendimiento</th><th>Solicitud</th><th>Estado</th>{editable && <th></th>}</tr>
                </thead>
                <tbody>
                  {lista.map((s, i) => (
                    <tr key={s.solicitud_id}>
                      <td>{i + 1}</td>
                      <td>{s.apellido}, {s.nombre}</td>
                      <td>{s.numero_legajo}</td>
                      <td>{s.creditos_aprobados}</td>
                      <td>{s.rendimiento ?? "—"}</td>
                      <td>{fechaHora(s.fecha)}</td>
                      <td><span className={`sga-estado-encuesta ${etiquetaEstado[s.estado].clase}`}>{etiquetaEstado[s.estado].texto}</span></td>
                      {editable && (
                        <td className="sga-acciones-doc">
                          <form action={marcarSolicitud}>
                            <input name="periodo_id" type="hidden" value={p.id} />
                            <input name="solicitud_id" type="hidden" value={s.solicitud_id} />
                            {s.estado !== "ASIGNADA" && <button name="asignada" type="submit" value="true">Asignar</button>}
                            {s.estado !== "NO_ASIGNADA" && <button className="sga-boton-peligro" name="asignada" type="submit" value="false">No asignar</button>}
                          </form>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}

      <Link className="sga-volver" href="/administracion/inscripciones">← Volver a Inscripción a cursadas</Link>
    </section>
  );
}
