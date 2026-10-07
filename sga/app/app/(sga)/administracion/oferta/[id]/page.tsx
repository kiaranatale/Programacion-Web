import Link from "next/link";
import { dias, formatearHorario, modalidades, type HorarioRow } from "@/lib/cursos";
import { createClient } from "@/lib/supabase/server";
import { fecha, periodo } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { agregarHorario, borrarComision, borrarCurso, borrarHorario, cambiarCupo, crearComision } from "../actions";

type Curso = {
  id: number;
  anio: number;
  periodo: string;
  fecha_inicio: string;
  fecha_fin: string;
  materia: { codigo: string; nombre: string } | null;
  comision: {
    id: number;
    nombre: string;
    cupo: number | null;
    inscripcion_curso: { count: number }[];
    horario_comision: (HorarioRow & { id: number })[];
    docente_comision: { docente: { persona: { apellido: string; nombre: string } | null } | null }[];
  }[];
};
type Edificio = { id: number; nombre: string };

// Comisiones, cupos y horarios de un curso.
export default async function EditarCurso({ params, searchParams }: PageProps<"/administracion/oferta/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Curso</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: c }, { data: edificios }] = await Promise.all([
    sga.from("curso").select(`id, anio, periodo, fecha_inicio, fecha_fin, materia:materia_id(codigo, nombre),
      comision(id, nombre, cupo, inscripcion_curso(count),
        horario_comision(id, dia_semana, hora_inicio, hora_fin, modalidad, aula:aula_id(codigo, edificio:edificio_id(nombre))),
        docente_comision(docente:docente_id(persona:persona_id(apellido, nombre))))`)
      .eq("id", id).maybeSingle<Curso>(),
    sga.from("edificio").select("id, nombre").order("nombre").returns<Edificio[]>(),
  ]);
  if (!c) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Curso</h2>
        <p className="sga-error">El curso no existe.</p>
        <Link className="sga-volver" href="/administracion/oferta">← Volver a Oferta de cursos</Link>
      </section>
    );
  }
  const comisiones = [...c.comision].sort((a, b) => a.nombre.localeCompare(b.nombre));
  const totalInscriptos = comisiones.reduce((t, co) => t + (co.inscripcion_curso[0]?.count ?? 0), 0);
  const volverA = `/administracion/oferta?cuatrimestre=${c.anio}|${c.periodo}`;
  const curso = <input name="curso_id" type="hidden" value={c.id} />;
  const siguiente = String.fromCharCode(65 + comisiones.length);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{c.materia?.codigo} - {c.materia?.nombre}</h2>
      <p className="sga-texto">
        {periodo(c.anio, c.periodo)} · del {fecha(c.fecha_inicio)} al {fecha(c.fecha_fin)} · {totalInscriptos} inscriptos ·{" "}
        <Link href={`/cursos/${c.id}`}>Ver como lo ven los alumnos</Link>
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {comisiones.length === 0 && <p className="sga-vacio-grande">Todavía no tiene comisiones.</p>}
      {comisiones.map((co) => {
        const inscriptos = co.inscripcion_curso[0]?.count ?? 0;
        const docentes = co.docente_comision.flatMap((d) => (d.docente?.persona ? [`${d.docente.persona.apellido}, ${d.docente.persona.nombre}`] : []));
        const comision = <><input name="curso_id" type="hidden" value={c.id} /><input name="comision_id" type="hidden" value={co.id} /></>;
        return (
          <div className="sga-caja sga-comision-oferta" key={co.id}>
            <div className="sga-cv-cabecera">
              <h3 className="sga-subtitulo">Comisión {co.nombre}</h3>
              <span className="sga-ayuda">{inscriptos} inscriptos · {docentes.length ? docentes.join("; ") : "Sin docentes"}</span>
            </div>
            <div className="sga-acciones-doc">
              <form action={cambiarCupo}>
                {comision}
                <span className="sga-ayuda">Cupo</span>
                <input aria-label={`Cupo de la comisión ${co.nombre}`} defaultValue={co.cupo ?? ""} min={1} name="cupo" placeholder="Sin cupo" type="number" />
                <button type="submit">Guardar cupo</button>
              </form>
              {inscriptos === 0 && (
                <form action={borrarComision}>
                  {comision}
                  <button className="sga-boton-peligro" type="submit">Borrar comisión</button>
                </form>
              )}
            </div>
            <ul className="sga-horarios-oferta">
              {co.horario_comision.length === 0 && <li className="sga-estado-cargado">Sin horarios: no aparece bien en la inscripción ni en el calendario.</li>}
              {co.horario_comision.map((h) => (
                <li key={h.id}>
                  {formatearHorario(h)}
                  <form action={borrarHorario}>
                    {comision}
                    <input name="horario_id" type="hidden" value={h.id} />
                    <button aria-label="Borrar horario" className="sga-boton-peligro" type="submit">Borrar</button>
                  </form>
                </li>
              ))}
            </ul>
            <form action={agregarHorario} className="sga-form-fecha-final">
              {comision}
              <select aria-label="Día" defaultValue="LUNES" name="dia">
                {Object.entries(dias).filter(([d]) => d !== "DOMINGO").map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
              </select>
              <input aria-label="Desde" defaultValue="09:00" name="desde" required type="time" />
              <input aria-label="Hasta" defaultValue="12:00" name="hasta" required type="time" />
              <select aria-label="Modalidad" defaultValue="PRESENCIAL" name="modalidad">
                {Object.entries(modalidades).map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
              </select>
              <select aria-label="Sede" defaultValue={edificios?.[0]?.id ?? ""} name="edificio_id">
                {(edificios ?? []).map((e) => <option key={e.id} value={e.id}>{e.nombre}</option>)}
              </select>
              <input aria-label="Aula" name="aula" placeholder="Aula (ej. 304)" />
              <button type="submit">Agregar horario</button>
            </form>
          </div>
        );
      })}

      <h3 className="sga-subtitulo">Nueva comisión</h3>
      <form action={crearComision} className="sga-form-fecha-final">
        {curso}
        <input aria-label="Nombre de la comisión" defaultValue={siguiente} maxLength={10} name="nombre" required />
        <input aria-label="Cupo" min={1} name="cupo" placeholder="Cupo (opcional)" type="number" />
        <button type="submit">Crear comisión</button>
      </form>
      <p className="sga-ayuda">Los docentes se asignan desde Administración → Personas, en la ficha de cada docente.</p>

      {totalInscriptos === 0 && (
        <form action={borrarCurso} className="sga-acciones-doc">
          {curso}
          <button className="sga-boton-peligro" type="submit">Borrar el curso</button>
        </form>
      )}
      <Link className="sga-volver" href={volverA}>← Volver a Oferta de cursos</Link>
    </section>
  );
}
