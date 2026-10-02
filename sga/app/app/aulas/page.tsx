import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

type AulaRow = {
  id: number;
  codigo: string;
  capacidad: number;
  edificio: { codigo: string; nombre: string } | null;
};

// Primer módulo conectado a Supabase: lectura real de sga.aula. Las aulas
// son un catálogo: RLS deja leerlas a cualquier usuario con sesión, y el
// middleware ya redirige al login a quien no la tiene.
export default async function AulasPage() {
  const supabase = await createClient();

  const { data: aulas, error } = await supabase
    .schema("sga")
    .from("aula")
    .select("id, codigo, capacidad, edificio:edificio_id(codigo, nombre)")
    .order("codigo")
    .returns<AulaRow[]>();

  return (
    <main className="page-content module-content">
      <p className="eyebrow">MÓDULO ACADÉMICO</p>
      <h1>Aulas</h1>
      <p className="module-intro">
        Espacios y capacidad, leídos en vivo desde Supabase (schema <code>sga</code>).
      </p>

      {error ? (
        <section className="module-status">
          <span className="status-mark">!</span>
          <div>
            <span className="status-label">ERROR DE CONEXIÓN</span>
            <h2>No se pudo leer sga.aula</h2>
            <p>
              {error.message}. Verificá que `NEXT_PUBLIC_SUPABASE_URL` y
              `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` estén configuradas en
              `sga/app/.env.local` y que el schema `sga` figure en Exposed
              schemas (Integrations → Data API → Settings en el dashboard).
            </p>
          </div>
          <span className="status-pill">SIN CONEXIÓN</span>
        </section>
      ) : !aulas || aulas.length === 0 ? (
        <section className="module-status">
          <span className="status-mark">AU</span>
          <div>
            <span className="status-label">ESTADO DEL MÓDULO</span>
            <h2>No hay aulas cargadas</h2>
            <p>
              La tabla sga.aula está vacía. Cargá los datos de prueba
              corriendo supabase/seed.sql en el SQL Editor de Supabase.
            </p>
          </div>
          <span className="status-pill">SIN DATOS</span>
        </section>
      ) : (
        <section className="scope-section">
          <p className="eyebrow">ESPACIOS</p>
          <h2>Aulas disponibles</h2>
          <ul>
            {aulas.map((aula) => (
              <li key={aula.id}>
                <strong>{aula.codigo}</strong> · {aula.edificio?.nombre ?? "Edificio sin datos"} · Capacidad {aula.capacidad}
              </li>
            ))}
          </ul>
        </section>
      )}

      <Link className="back-action" href="/">
        <span aria-hidden="true">←</span> Volver al resumen
      </Link>
    </main>
  );
}
