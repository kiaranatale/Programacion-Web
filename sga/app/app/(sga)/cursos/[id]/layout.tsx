import Link from "next/link";
import { notFound } from "next/navigation";
import Tabs from "@/components/tabs";
import { getCurso } from "@/lib/curso";
import { periodo } from "@/lib/legajo";

export default async function CursoLayout({ children, params }: LayoutProps<"/cursos/[id]">) {
  const { id } = await params;
  const curso = await getCurso(Number(id));
  if (!curso) notFound();

  const base = `/cursos/${curso.id}`;
  const tabs = [
    { label: "Plantel Docente", href: base, exact: true },
    { label: "Comisiones", href: `${base}/comisiones` },
    { label: "Contenidos mínimos", href: `${base}/contenidos` },
    { label: "Información de la materia", href: `${base}/informacion` },
  ];

  return (
    <>
      <h2 className="sga-titulo sga-titulo-grande sga-titulo-suelto">Detalle del curso</h2>
      <section className="sga-panel">
        <dl className="sga-datos sga-datos-curso">
          <div><dt>Materia:</dt><dd>{curso.materia!.codigo} - {curso.materia!.nombre}</dd></div>
          <div><dt>Departamento:</dt><dd>{curso.materia!.departamento?.nombre}</dd></div>
          <div><dt>Cuatrimestre:</dt><dd>{periodo(curso.anio, curso.periodo)}</dd></div>
        </dl>
        <div className="sga-tab-box">
          <Tabs tabs={tabs} />
          <div className="sga-tab-content">{children}</div>
        </div>
      </section>
      <Link className="sga-volver" href="/cursos">← Volver al listado de cursos</Link>
    </>
  );
}
