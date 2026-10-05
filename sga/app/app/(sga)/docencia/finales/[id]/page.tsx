import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fecha, nota } from "@/lib/legajo";
import { hoy } from "@/lib/hoy";
import { guardarNotasFinal } from "../../actions";

type Inscripto = {
  id: number;
  numero_intento: number;
  nota_final: number | null;
  inscripcion_curso: {
    nota_cursada: number | null;
    nota_definitiva: number | null;
    comision: { nombre: string } | null;
    legajo: { numero_legajo: string; persona: { apellido: string; nombre: string } | null } | null;
  } | null;
};
type Mesa = { id: number; fecha: string; hora_inicio: string; hora_fin: string; curso: { materia: { codigo: string; nombre: string } | null } | null };

// Inscriptos de las comisiones propias a una mesa de final, para cargar
// las notas una vez tomada.
export default async function NotasDeFinal({ params, searchParams }: PageProps<"/docencia/finales/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: mesa }, { data }] = await Promise.all([
    sga.from("examen_final").select("id, fecha, hora_inicio, hora_fin, curso:curso_id(materia:materia_id(codigo, nombre))").eq("id", id).maybeSingle<Mesa>(),
    // RLS: el docente solo ve las inscripciones de sus comisiones
    sga.from("inscripcion_examen_final")
      .select("id, numero_intento, nota_final, inscripcion_curso:inscripcion_curso_id(nota_cursada, nota_definitiva, comision:comision_id(nombre), legajo:legajo_id(numero_legajo, persona:persona_id(apellido, nombre)))")
      .eq("examen_final_id", id)
      .returns<Inscripto[]>(),
  ]);
  if (!mesa) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Notas de final</h2>
        <p className="sga-error">No se encontró la mesa.</p>
      </section>
    );
  }

  const nombre = (i: Inscripto) => {
    const p = i.inscripcion_curso?.legajo?.persona;
    return p ? `${p.apellido}, ${p.nombre}` : "—";
  };
  const inscriptos = [...(data ?? [])].sort((a, b) => nombre(a).localeCompare(nombre(b)));
  const tomada = mesa.fecha <= hoy();
  const pendientes = inscriptos.filter((i) => i.nota_final === null).length;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Notas de final</h2>
      <p className="sga-texto">
        <strong>{mesa.curso?.materia?.codigo} - {mesa.curso?.materia?.nombre}</strong> · {fecha(mesa.fecha)} de {mesa.hora_inicio.slice(0, 5)} a {mesa.hora_fin.slice(0, 5)} hs
      </p>
      {!tomada && <p className="sga-texto">La mesa todavía no se tomó: las notas se cargan a partir del {fecha(mesa.fecha)}.</p>}
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <form action={guardarNotasFinal}>
        <input name="examen_final_id" type="hidden" value={id} />
        <div className="sga-tabla-scroll">
          <table className="sga-tabla sga-tabla-mensajes sga-planilla">
            <thead><tr><th>Alumno</th><th>Legajo</th><th>Comisión</th><th>Intento</th><th>Cursada</th><th>Nota de final</th><th>Definitiva</th></tr></thead>
            <tbody>
              {inscriptos.length > 0 ? inscriptos.map((i) => (
                <tr key={i.id}>
                  <td>{nombre(i)}</td>
                  <td>{i.inscripcion_curso?.legajo?.numero_legajo}</td>
                  <td className="sga-col-cupo">{i.inscripcion_curso?.comision?.nombre}</td>
                  <td className="sga-col-cupo">{i.numero_intento}º</td>
                  <td className="sga-col-cupo">{nota(i.inscripcion_curso?.nota_cursada)}</td>
                  <td className="sga-col-cupo">
                    {i.nota_final !== null || !tomada ? nota(i.nota_final) : (
                      <>
                        <input name={`a_${i.id}`} type="hidden" value={nombre(i)} />
                        <input aria-label={`Nota de final de ${nombre(i)}`} className="sga-input-nota" inputMode="decimal"
                          name={`n_${i.id}`} pattern="(10|[0-9])([.,][0-9]{1,2})?" placeholder="—" />
                      </>
                    )}
                  </td>
                  <td className="sga-col-cupo">{nota(i.inscripcion_curso?.nota_definitiva)}</td>
                </tr>
              )) : <tr><td className="sga-vacio" colSpan={7}>No hay alumnos de tus comisiones inscriptos a esta mesa.</td></tr>}
            </tbody>
          </table>
        </div>
        {tomada && pendientes > 0 && (
          <>
            <p className="sga-ayuda">
              Las notas de final se cargan una sola vez: revisalas antes de guardar. Para corregir una nota ya cargada, pedíselo a Administración.
            </p>
            <div className="sga-acciones-form"><button type="submit">Guardar notas</button></div>
          </>
        )}
      </form>
      <Link className="sga-volver" href="/docencia/notas">← Volver a Carga de notas</Link>
    </section>
  );
}
