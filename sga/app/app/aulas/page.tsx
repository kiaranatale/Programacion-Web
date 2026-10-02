import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

type AulaRow = {
  id: number;
  codigo: string;
  capacidad: number;
  edificio: { codigo: string; nombre: string } | null;
};

// Primer módulo conectado a Supabase: reemplaza los datos de muestra por
// una lectura real de sga.aula, acotada por las políticas RLS del rol
// autenticado (sin sesión, el rol `anon` no ve ningún registro).
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
            <h2>No hay aulas visibles</h2>
            <p>
              Esperable sin autenticación: las políticas RLS ocultan los datos
              a quien no tiene sesión iniciada. Una vez implementado el login
              (Fase 2 del roadmap), un usuario con rol asignado verá aquí las
              aulas reales.
            </p>
          </div>
          <span className="status-pill">SIN SESIÓN</span>
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
