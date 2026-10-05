import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { estadosCursada } from "@/lib/docencia";
import { fechaHora } from "@/lib/hoy";
import { nota, periodo } from "@/lib/legajo";
import { guardarNotasCursada } from "../../actions";

type Inscripcion = {
  id: number;
  estado: string;
  nota_cursada: number | null;
  fecha_carga_cursada: string | null;
  nota_definitiva: number | null;
  legajo: { numero_legajo: string; persona: { apellido: string; nombre: string } | null } | null;
  inscripcion_examen_final: { id: number }[];
};
type Comision = { id: number; nombre: string; curso: { anio: number; periodo: string; materia: { codigo: string; nombre: string } | null } | null };

// Planilla de notas de cursada de una comisión propia.
export default async function NotasDeCursada({ params, searchParams }: PageProps<"/docencia/comisiones/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: comision }, { data }, { data: dicta }] = await Promise.all([
    sga.from("comision").select("id, nombre, curso:curso_id(anio, periodo, materia:materia_id(codigo, nombre))").eq("id", id).maybeSingle<Comision>(),
    sga.from("inscripcion_curso")
      .select("id, estado, nota_cursada, fecha_carga_cursada, nota_definitiva, legajo:legajo_id(numero_legajo, persona:persona_id(apellido, nombre)), inscripcion_examen_final(id)")
      .eq("comision_id", id)
      .returns<Inscripcion[]>(),
    sga.rpc("es_docente_de_comision", { p_comision_id: id }),
  ]);

  if (!comision || dicta !== true) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Notas de cursada</h2>
        <p className="sga-error">Solo podés ver las comisiones que dictás.</p>
        <Link className="sga-volver" href="/docencia">← Volver a Mis comisiones</Link>
      </section>
    );
  }

  const nombre = (i: Inscripcion) => (i.legajo?.persona ? `${i.legajo.persona.apellido}, ${i.legajo.persona.nombre}` : "—");
  const alumnos = [...(data ?? [])].sort((a, b) => nombre(a).localeCompare(nombre(b)));
  const materia = comision.curso?.materia;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Notas de cursada</h2>
      <p className="sga-texto">
        <strong>{materia?.codigo} - {materia?.nombre}</strong> · Comisión {comision.nombre} · {comision.curso && periodo(comision.curso.anio, comision.curso.periodo)}
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <form action={guardarNotasCursada}>
        <input name="comision_id" type="hidden" value={id} />
        <div className="sga-tabla-scroll">
          <table className="sga-tabla sga-tabla-mensajes sga-planilla">
            <thead><tr><th>Alumno</th><th>Legajo</th><th>Estado</th><th>Nota de cursada</th><th>Cargada</th></tr></thead>
            <tbody>
              {alumnos.length > 0 ? alumnos.map((i) => {
                const bloqueada = i.estado === "APROBADA" || i.estado === "ABANDONADA" || i.inscripcion_examen_final.length > 0;
                return (
                  <tr key={i.id}>
                    <td>{nombre(i)}</td>
                    <td>{i.legajo?.numero_legajo}</td>
                    <td>{estadosCursada[i.estado] ?? i.estado}{i.nota_definitiva !== null && ` (${nota(i.nota_definitiva)})`}</td>
                    <td className="sga-col-cupo">
                      {bloqueada ? (
                        <span title="El alumno rindió finales o dejó la materia">{nota(i.nota_cursada)}</span>
                      ) : (
                        <>
                          <input name={`a_${i.id}`} type="hidden" value={nombre(i)} />
                          <input name={`o_${i.id}`} type="hidden" value={i.nota_cursada ?? ""} />
                          <input aria-label={`Nota de ${nombre(i)}`} className="sga-input-nota" defaultValue={i.nota_cursada ?? ""}
                            inputMode="decimal" name={`n_${i.id}`} pattern="(10|[0-9])([.,][0-9]{1,2})?" placeholder="—" />
                        </>
                      )}
                    </td>
                    <td className="sga-ayuda">{i.fecha_carga_cursada ? fechaHora(i.fecha_carga_cursada) : "—"}</td>
                  </tr>
                );
              }) : <tr><td className="sga-vacio" colSpan={5}>La comisión no tiene inscriptos.</td></tr>}
            </tbody>
          </table>
        </div>
        <p className="sga-ayuda">Notas de 0 a 10 (podés usar decimales). Dejá vacío para quitar una nota.</p>
        {alumnos.length > 0 && <div className="sga-acciones-form"><button type="submit">Guardar notas</button></div>}
      </form>
      <Link className="sga-volver" href="/docencia">← Volver a Mis comisiones</Link>
    </section>
  );
}
