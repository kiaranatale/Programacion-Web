import { createClient } from "@/lib/supabase/server";

type AulaRow = {
  id: number;
  codigo: string;
  capacidad: number;
  edificio: { codigo: string; nombre: string; direccion: string | null } | null;
};

// Lectura real de sga.aula. Las aulas son un catálogo: RLS deja leerlas a
// cualquier usuario con sesión, y el middleware ya redirige al login a
// quien no la tiene.
export default async function AulasPage() {
  const supabase = await createClient();

  const { data: aulas, error } = await supabase
    .schema("sga")
    .from("aula")
    .select("id, codigo, capacidad, edificio:edificio_id(codigo, nombre, direccion)")
    .order("codigo")
    .returns<AulaRow[]>();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo">Aulas</h2>

      {error ? (
        <p className="sga-error">
          No se pudo leer sga.aula: {error.message}. Verificá las variables de
          `sga/app/.env.local` y que el schema `sga` figure en Exposed schemas
          (Integrations → Data API → Settings en el dashboard de Supabase).
        </p>
      ) : !aulas || aulas.length === 0 ? (
        <p className="sga-vacio">
          No hay aulas cargadas. Corré supabase/seed.sql en el SQL Editor de Supabase.
        </p>
      ) : (
        <div className="sga-tabla-scroll">
          <table className="sga-tabla">
            <thead>
              <tr><th>Aula</th><th>Edificio</th><th>Dirección</th><th>Capacidad</th></tr>
            </thead>
            <tbody>
              {aulas.map((aula) => (
                <tr key={aula.id}>
                  <td className="sga-curso">{aula.codigo}</td>
                  <td>{aula.edificio?.nombre ?? "Sin edificio"}</td>
                  <td>{aula.edificio?.direccion ?? "—"}</td>
                  <td>{aula.capacidad}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
