import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { formatearHorario, type HorarioRow } from "@/lib/cursos";
import { fecha, periodo } from "@/lib/legajo";

type Curso = {
  id: number;
  anio: number;
  periodo: string;
  fecha_inicio: string;
  fecha_fin: string;
  activo: boolean;
  materia: { codigo: string; nombre: string; creditos: number | null; departamento: { nombre: string } | null } | null;
  comision: { id: number; nombre: string; cupo: number | null; horario_comision: HorarioRow[] }[];
};

export default async function DetalleCurso({ params }: PageProps<"/cursos/[id]">) {
  const id = Number((await params).id);
  if (!Number.isInteger(id)) notFound();

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: curso }, { data: resumen }] = await Promise.all([
    sga.from("curso")
      .select(`id, anio, periodo, fecha_inicio, fecha_fin, activo,
        materia:materia_id(codigo, nombre, creditos, departamento:departamento_id(nombre)),
        comision(id, nombre, cupo, horario_comision(dia_semana, hora_inicio, hora_fin, modalidad,
          aula:aula_id(codigo, edificio:edificio_id(nombre))))`)
      .eq("id", id)
      .maybeSingle<Curso>(),
    sga.from("curso_listado").select("alumnos").eq("id", id).maybeSingle<{ alumnos: number }>(),
  ]);
  if (!curso?.materia) notFound();

  const comisiones = [...curso.comision].sort((a, b) => a.nombre.localeCompare(b.nombre));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{curso.materia.codigo} - {curso.materia.nombre}</h2>
      <dl className="sga-datos sga-datos-carrera">
        <div><dt>Departamento:</dt><dd>{curso.materia.departamento?.nombre}</dd></div>
        <div><dt>Créditos:</dt><dd>{curso.materia.creditos ?? "Sin dato"}</dd></div>
        <div><dt>Período:</dt><dd>{periodo(curso.anio, curso.periodo)}</dd></div>
        <div><dt>Comienzo:</dt><dd>{fecha(curso.fecha_inicio)}</dd></div>
        <div><dt>Fin:</dt><dd>{fecha(curso.fecha_fin)}</dd></div>
        <div><dt>Activo:</dt><dd>{curso.activo ? "Sí" : "No"}</dd></div>
        <div><dt>Alumnos inscriptos:</dt><dd>{resumen?.alumnos ?? 0}</dd></div>
      </dl>

      <h3 className="sga-subtitulo">Comisiones</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead><tr><th>Comisión</th><th>Cupo</th><th>Horarios</th></tr></thead>
          <tbody>
            {comisiones.length > 0 ? comisiones.map((c) => (
              <tr key={c.id}>
                <td><strong>{c.nombre}</strong></td>
                <td>{c.cupo ?? "—"}</td>
                <td className="sga-horarios">
                  {c.horario_comision.length > 0
                    ? c.horario_comision.map(formatearHorario).join(" | ")
                    : "Sin horarios cargados"}
                </td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={3}>Este curso todavía no tiene comisiones cargadas.</td></tr>
            )}
          </tbody>
        </table>
      </div>
      <Link className="sga-volver" href="/cursos">← Volver al listado de cursos</Link>
    </section>
  );
}
