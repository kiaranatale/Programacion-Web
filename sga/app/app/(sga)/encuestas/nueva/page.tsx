import Link from "next/link";
import { hoy } from "@/lib/hoy";
import { getSesion } from "@/lib/sesion";
import FormularioEncuesta from "./formulario";

export default async function NuevaEncuesta() {
  const sesion = await getSesion();
  const admin = !!sesion?.roles.includes("ADMINISTRATIVO");

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Nueva encuesta general</h2>
      {admin ? <FormularioEncuesta hoy={hoy()} /> : <p className="sga-error">Las encuestas las crea Administración.</p>}
      <Link className="sga-volver" href="/encuestas">← Volver a Encuestas</Link>
    </section>
  );
}
