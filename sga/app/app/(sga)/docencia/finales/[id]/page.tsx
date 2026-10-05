import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { diaYHora } from "@/lib/finales";
import { fecha, nota } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { guardarNotasFinal } from "../../actions";

type Anotado = {
  inscripcion_id: number;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  comision: string;
  periodo_cursada: string;
  numero_intento: number;
  nota_cursada: number | null;
  nota_final: number | null;
  ausente: boolean;
  nota_definitiva: number | null;
};
type Fecha = {
  id: number;
  fecha: string;
  hora_inicio: string;
  hora_fin: string;
  turno: { nombre: string } | null;
  curso: { materia: { codigo: string; nombre: string } | null } | null;
};

// Anotados a una fecha de final (todos los de la materia), para cargar
// las notas una vez tomado el examen.
export default async function NotasDeFinal({ params, searchParams }: PageProps<"/docencia/finales/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: ef }, { data, error: sinPermiso }] = await Promise.all([
    sga.from("examen_final").select("id, fecha, hora_inicio, hora_fin, turno:turno_id(nombre), curso:curso_id(materia:materia_id(codigo, nombre))").eq("id", id).maybeSingle<Fecha>(),
    sga.rpc("inscriptos_fecha_final", { p_examen_final_id: id }),
  ]);
  if (!ef || sinPermiso) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Notas de final</h2>
        <p className="sga-error">{ef ? "Solo los docentes de la materia ven esta fecha." : "No se encontró la fecha de final."}</p>
        <Link className="sga-volver" href="/docencia/notas">← Volver a Carga de notas</Link>
      </section>
    );
  }

  const anotados = (data ?? []) as Anotado[];
  const tomada = ef.fecha <= hoy();
  const pendientes = anotados.filter((a) => a.nota_final === null && !a.ausente).length;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Notas de final</h2>
      <p className="sga-texto">
        <strong>{ef.curso?.materia?.codigo} - {ef.curso?.materia?.nombre}</strong>
        {ef.turno && ` · Turno ${ef.turno.nombre}`} · {diaYHora(ef.fecha, ef.hora_inicio)} a {ef.hora_fin.slice(0, 5)} hs
      </p>
      {!tomada && <p className="sga-texto">El examen todavía no se tomó: las notas se cargan a partir del {fecha(ef.fecha)}.</p>}
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <form action={guardarNotasFinal}>
        <input name="examen_final_id" type="hidden" value={id} />
        <div className="sga-tabla-scroll">
          <table className="sga-tabla sga-tabla-mensajes sga-planilla">
            <thead><tr><th>Alumno</th><th>Legajo</th><th>Cursó</th><th>Intento</th><th>Cursada</th><th>Nota de final</th><th>Ausente</th><th>Definitiva</th></tr></thead>
            <tbody>
              {anotados.length > 0 ? anotados.map((a) => {
                const editable = tomada && a.nota_final === null && !a.ausente;
                const nombre = `${a.apellido}, ${a.nombre}`;
                return (
                  <tr key={a.inscripcion_id}>
                    <td>{nombre}</td>
                    <td>{a.numero_legajo}</td>
                    <td className="sga-ayuda">{a.periodo_cursada} · Com. {a.comision}</td>
                    <td className="sga-col-cupo">{a.numero_intento}º</td>
                    <td className="sga-col-cupo">{nota(a.nota_cursada)}</td>
                    <td className="sga-col-cupo">
                      {editable ? (
                        <>
                          <input name={`a_${a.inscripcion_id}`} type="hidden" value={nombre} />
                          <input aria-label={`Nota de final de ${nombre}`} className="sga-input-nota" inputMode="decimal"
                            name={`n_${a.inscripcion_id}`} pattern="(10|[0-9])([.,][0-9]{1,2})?" placeholder="—" />
                        </>
                      ) : a.ausente ? <span className="sga-desaprobado">Ausente</span> : nota(a.nota_final)}
                    </td>
                    <td className="sga-col-cupo">
                      {editable && <input aria-label={`${nombre} estuvo ausente`} name={`x_${a.inscripcion_id}`} type="checkbox" value="1" />}
                    </td>
                    <td className="sga-col-cupo">{nota(a.nota_definitiva)}</td>
                  </tr>
                );
              }) : <tr><td className="sga-vacio" colSpan={8}>No hay alumnos anotados a esta fecha.</td></tr>}
            </tbody>
          </table>
        </div>
        {tomada && pendientes > 0 && (
          <>
            <p className="sga-ayuda">
              Las notas de final se cargan una sola vez: revisalas antes de guardar. Marcá &quot;Ausente&quot; a quien se anotó y no se
              presentó: cuenta como intento. Para corregir una nota ya cargada, pedíselo a Administración.
            </p>
            <div className="sga-acciones-form"><button type="submit">Guardar notas</button></div>
          </>
        )}
      </form>
      <Link className="sga-volver" href="/docencia/notas">← Volver a Carga de notas</Link>
    </section>
  );
}
