import Link from "next/link";
import ContadorTexto from "@/components/contador-texto";
import { destinos } from "@/lib/tramites";
import { iniciarTramite } from "../actions";

export default async function NuevoTramite({ searchParams }: PageProps<"/tramites/nuevo">) {
  const { error } = await searchParams;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Iniciar nuevo trámite</h2>
      <p className="sga-ayuda">
        Los trámites y/o consultas relacionadas con pagos o certificados deben dirigirse a Secretaría Administrativa. Cualquier
        otro trámite o consulta debe dirigirse a Secretaría Académica.
      </p>
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      <form action={iniciarTramite} className="sga-form-tramite">
        <label htmlFor="titulo">Título:</label>
        <input id="titulo" maxLength={150} name="titulo" required />
        <label htmlFor="destino">Destino:</label>
        <select defaultValue="ACADEMICA" id="destino" name="destino">
          {Object.entries(destinos).map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
        </select>
        <label htmlFor="descripcion">Descripción:</label>
        <ContadorTexto id="descripcion" maximo={8000} name="descripcion" required rows={8} />
        <div className="sga-acciones-form">
          <button type="submit">Enviar</button>
          <Link href="/tramites">Cancelar</Link>
        </div>
      </form>
    </section>
  );
}
