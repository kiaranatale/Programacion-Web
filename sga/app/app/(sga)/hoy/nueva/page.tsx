import Link from "next/link";
import { getMisOrganizaciones } from "@/lib/hoy";
import { crearPublicacion } from "../actions";
import FormularioPublicacion from "../formulario";

export default async function NuevaPublicacion({ searchParams }: PageProps<"/hoy/nueva">) {
  const { error, org } = await searchParams;
  const organizaciones = await getMisOrganizaciones();
  // Si viene del listado filtrado por una organización suya, queda elegida.
  const inicial = organizaciones.find((o) => String(o.id) === org)?.id;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Nueva publicación</h2>
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {organizaciones.length > 0 ? (
        <FormularioPublicacion action={crearPublicacion} cancelar="/hoy" organizacionInicial={inicial} organizaciones={organizaciones} />
      ) : (
        <p className="sga-vacio">
          Solo pueden publicar los miembros de una organización estudiantil. Si sos parte de una, pedile a
          Administración que te agregue.
        </p>
      )}
      <Link className="sga-volver" href="/hoy">← Volver a Hoy en el ITBA</Link>
    </section>
  );
}
