import { getCurso } from "@/lib/curso";

export default async function ContenidosMinimos({ params }: PageProps<"/cursos/[id]/contenidos">) {
  const curso = await getCurso(Number((await params).id));
  const contenidos = curso?.materia?.contenidos_minimos;

  return contenidos
    ? <p className="sga-texto sga-texto-largo">{contenidos}</p>
    : <p className="sga-vacio">Esta materia todavía no tiene contenidos mínimos cargados.</p>;
}
