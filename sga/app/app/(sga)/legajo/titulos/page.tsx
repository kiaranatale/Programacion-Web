import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual } from "@/lib/legajo";

type Titulo = {
  id: number;
  fecha: string | null;
  titulo: string;
  institucion: string | null;
  pais: string | null;
  nivel: string | null;
  descripcion: string | null;
};

export default async function Titulos() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const { data: titulos } = await supabase
    .schema("sga")
    .from("titulo_previo")
    .select("id, fecha, titulo, institucion, pais, nivel, descripcion")
    .eq("legajo_id", legajo?.id ?? 0)
    .order("fecha", { ascending: false })
    .returns<Titulo[]>();

  return (
    <>
      <h3 className="sga-subtitulo">Títulos</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead>
            <tr><th>Fecha</th><th>Título</th><th>Institución</th><th>País</th><th>Nivel</th><th>Descripción</th></tr>
          </thead>
          <tbody>
            {titulos && titulos.length > 0 ? (
              titulos.map((t) => (
                <tr key={t.id}>
                  <td>{fecha(t.fecha)}</td><td>{t.titulo}</td><td>{t.institucion}</td>
                  <td>{t.pais}</td><td>{t.nivel}</td><td>{t.descripcion}</td>
                </tr>
              ))
            ) : (
              <tr><td className="sga-vacio" colSpan={6}>No hay registros para mostrar.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
