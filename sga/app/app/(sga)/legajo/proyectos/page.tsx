import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getLegajoActual, periodo } from "@/lib/legajo";
import { estadosProyecto, periodoProyecto, tiposProyecto, type EstadoProyecto, type TipoProyecto } from "@/lib/proyectos";
import { borrarProyecto, guardarProyecto } from "./actions";

type Proyecto = {
  id: number;
  tipo: TipoProyecto;
  titulo: string;
  materia_id: number | null;
  responsable: string | null;
  descripcion: string | null;
  desde: string;
  hasta: string | null;
  estado: EstadoProyecto;
  observaciones: string | null;
  materia: { codigo: string; nombre: string } | null;
};
type Ayudantia = { anio: number; periodo: string; codigo: string; materia: string; comision: string };
type Materia = { materia: { id: number; codigo: string; nombre: string } | null };

// Proyectos: registro estilo CV de las ayudantías y proyectos que el
// alumno hizo para el ITBA. Las ayudantías asignadas en el sistema salen
// solas; el resto lo carga el alumno y lo valida Administración.
export default async function Proyectos({ searchParams }: PageProps<"/legajo/proyectos">) {
  const params = await searchParams;
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data }, { data: ayudantiasData }, { data: materiasData }] = await Promise.all([
    sga.from("proyecto_alumno")
      .select("id, tipo, titulo, materia_id, responsable, descripcion, desde, hasta, estado, observaciones, materia:materia_id(codigo, nombre)")
      .eq("legajo_id", legajo?.id ?? 0)
      .order("desde", { ascending: false })
      .returns<Proyecto[]>(),
    sga.rpc("mis_ayudantias"),
    sga.from("plan_materia").select("materia:materia_id(id, codigo, nombre)").eq("plan_id", legajo?.plan_estudio?.id ?? 0).returns<Materia[]>(),
  ]);
  const proyectos = data ?? [];
  const ayudantias = (ayudantiasData ?? []) as Ayudantia[];
  const materias = (materiasData ?? []).flatMap((m) => (m.materia ? [m.materia] : [])).sort((a, b) => a.codigo.localeCompare(b.codigo));
  const editando = proyectos.find((p) => p.id === Number(params.editar) && p.estado !== "VALIDADO");
  const validados = proyectos.filter((p) => p.estado === "VALIDADO").length;

  return (
    <>
      <p className="sga-texto">
        Tu registro de ayudantías y proyectos hechos para el ITBA, como un CV. Lo que cargás queda <strong>pendiente de
        validación</strong> hasta que Administración lo confirma; los validados figuran con ✓.
      </p>
      {typeof params.ok === "string" && <p className="sga-mensaje-ok" role="status">{params.ok}</p>}
      {typeof params.error === "string" && <p className="sga-mensaje-error" role="alert">{params.error}</p>}

      <h3 className="sga-subtitulo">Ayudantías registradas por el ITBA</h3>
      {ayudantias.length > 0 ? (
        <ul className="sga-cv">
          {ayudantias.map((a) => (
            <li key={`${a.anio}-${a.periodo}-${a.codigo}-${a.comision}`}>
              <div className="sga-cv-cabecera">
                <strong>Ayudante de {a.codigo} - {a.materia}</strong>
                <span className="sga-estado-validado">Registrada ✓</span>
              </div>
              <div className="sga-ayuda">Comisión {a.comision} · {periodo(a.anio, a.periodo)}</div>
            </li>
          ))}
        </ul>
      ) : (
        <p className="sga-vacio">No figurás como ayudante en ninguna comisión. Si fuiste ayudante y no aparece, cargalo abajo.</p>
      )}

      <h3 className="sga-subtitulo">Proyectos y antecedentes ({validados} validados de {proyectos.length})</h3>
      {proyectos.length > 0 ? (
        <ul className="sga-cv">
          {proyectos.map((p) => (
            <li className={p.id === editando?.id ? "sga-cv-editando" : undefined} key={p.id}>
              <div className="sga-cv-cabecera">
                <strong>{p.titulo}</strong>
                <span className={estadosProyecto[p.estado].clase}>{estadosProyecto[p.estado].texto}</span>
              </div>
              <div className="sga-ayuda">
                {tiposProyecto[p.tipo]} · {periodoProyecto(p.desde, p.hasta)}
                {p.materia && <> · {p.materia.codigo} - {p.materia.nombre}</>}
                {p.responsable && <> · A cargo: {p.responsable}</>}
              </div>
              {p.descripcion && <p className="sga-cv-descripcion">{p.descripcion}</p>}
              {p.estado === "RECHAZADO" && p.observaciones && <p className="sga-mensaje-error">Motivo: {p.observaciones}</p>}
              {p.estado !== "VALIDADO" && (
                <div className="sga-acciones-doc">
                  <form action={borrarProyecto}>
                    <a href={`?editar=${p.id}#formulario`}>Editar</a>
                    <input name="id" type="hidden" value={p.id} />
                    <button className="sga-boton-peligro" type="submit">Borrar</button>
                  </form>
                </div>
              )}
            </li>
          ))}
        </ul>
      ) : (
        <p className="sga-vacio">Todavía no cargaste proyectos.</p>
      )}

      <h3 className="sga-subtitulo" id="formulario">{editando ? `Editar "${editando.titulo}"` : "Agregar un proyecto"}</h3>
      <form action={guardarProyecto} className="sga-form-publicacion" key={editando?.id ?? "nuevo"}>
        {editando && <input name="id" type="hidden" value={editando.id} />}
        <label>
          <span>Tipo</span>
          <select defaultValue={editando?.tipo ?? ""} name="tipo" required>
            <option disabled value="">Elegí el tipo…</option>
            {Object.entries(tiposProyecto).map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
          </select>
        </label>
        <label>
          <span>Título</span>
          <input defaultValue={editando?.titulo} maxLength={200} name="titulo" placeholder="Ej.: Ayudante de Programación web" required />
        </label>
        <fieldset>
          <legend>Período</legend>
          <label>
            <span>Desde</span>
            <input defaultValue={editando?.desde} name="desde" required type="date" />
          </label>
          <label>
            <span>Hasta</span>
            <input defaultValue={editando?.hasta ?? ""} name="hasta" type="date" />
          </label>
          <span className="sga-ayuda">Dejá &quot;Hasta&quot; vacío si sigue en curso.</span>
        </fieldset>
        <label>
          <span>Materia (opcional)</span>
          <select defaultValue={editando?.materia_id ?? ""} name="materia_id">
            <option value="">Ninguna</option>
            {materias.map((m) => <option key={m.id} value={m.id}>{m.codigo} - {m.nombre}</option>)}
          </select>
        </label>
        <label>
          <span>A cargo (opcional)</span>
          <input defaultValue={editando?.responsable ?? ""} maxLength={150} name="responsable" placeholder="Docente, departamento o área" />
        </label>
        <label>
          <span>Descripción (opcional)</span>
          <textarea defaultValue={editando?.descripcion ?? ""} maxLength={2000} name="descripcion" rows={4} />
        </label>
        <div className="sga-acciones-form">
          <button type="submit">{editando ? "Guardar cambios" : "Agregar"}</button>
          {editando && <Link href="/legajo/proyectos">Cancelar</Link>}
        </div>
      </form>
    </>
  );
}
