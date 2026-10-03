import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getCurso } from "@/lib/curso";
import { guardarContenidos } from "./actions";

// Contenidos mínimos de la materia. El responsable del curso (jefe de
// cátedra) y Administración los pueden editar.
export default async function ContenidosMinimos({ params, searchParams }: PageProps<"/cursos/[id]/contenidos">) {
  const curso = await getCurso(Number((await params).id));
  if (!curso) return null;
  const { editar, ok, error } = await searchParams;
  const contenidos = curso.materia?.contenidos_minimos;

  const supabase = await createClient();
  const { data: puedeEditar } = await supabase.schema("sga").rpc("puede_editar_contenidos", { p_curso_id: curso.id });
  const base = `/cursos/${curso.id}/contenidos`;

  return (
    <>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {puedeEditar === true && editar === "1" ? (
        <form action={guardarContenidos} className="sga-form-contenidos">
          <input name="curso_id" type="hidden" value={curso.id} />
          <textarea aria-label="Contenidos mínimos" defaultValue={contenidos ?? ""} name="contenidos" rows={12} />
          <p className="sga-ayuda">
            Los contenidos mínimos son de la materia: el cambio se ve en todos sus cursos.
          </p>
          <div className="sga-acciones-form">
            <button type="submit">Guardar</button>
            <Link href={base}>Cancelar</Link>
          </div>
        </form>
      ) : (
        <>
          {contenidos
            ? <p className="sga-texto sga-texto-largo">{contenidos}</p>
            : <p className="sga-vacio">Esta materia todavía no tiene contenidos mínimos cargados.</p>}
          {puedeEditar === true && (
            <p className="sga-acciones-form"><Link href={`${base}?editar=1`}>Editar contenidos mínimos</Link></p>
          )}
        </>
      )}
    </>
  );
}
