import Link from "next/link";
import { notFound } from "next/navigation";
import { getPublicacion } from "@/lib/hoy";
import { editarPublicacion } from "../../actions";
import FormularioPublicacion from "../../formulario";

export default async function EditarPublicacion({ params, searchParams }: PageProps<"/hoy/[id]/editar">) {
  const publicacion = await getPublicacion(Number((await params).id));
  if (!publicacion) notFound();
  const { error } = await searchParams;
  const volver = `/hoy/${publicacion.id}`;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Editar publicación</h2>
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {publicacion.puede_editar ? (
        <FormularioPublicacion action={editarPublicacion} cancelar={volver} publicacion={publicacion} />
      ) : (
        <p className="sga-error">Solo los miembros de {publicacion.organizacion} pueden editar esta publicación.</p>
      )}
      <Link className="sga-volver" href={volver}>← Volver a la publicación</Link>
    </section>
  );
}
