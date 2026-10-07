import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getSesion } from "@/lib/sesion";
import { etiquetaRol } from "@/lib/personas";

type Resultado = {
  id: number;
  apellido: string;
  nombre: string;
  tipo_documento: string;
  nro_documento: string;
  mail_institucional: string;
  roles: string | null;
  numero_legajo: string | null;
  con_cuenta: boolean;
};

// Búsqueda de personas para Administración.
export default async function Personas({ searchParams }: PageProps<"/administracion/personas">) {
  const params = await searchParams;
  const q = typeof params.q === "string" ? params.q.trim() : "";
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Personas</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const { data } = q.length >= 2 ? await supabase.schema("sga").rpc("buscar_personas", { p_texto: q }) : { data: [] };
  const personas = (data ?? []) as Resultado[];

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Personas</h2>
      <p className="sga-texto">
        Alumnos, docentes y administrativos. Buscá por apellido, nombre, documento, mail o legajo, o{" "}
        <Link href="/administracion/personas/nueva">dá de alta una persona nueva</Link>.
      </p>
      <form className="sga-hoy-filtros">
        <input aria-label="Buscar personas" defaultValue={q} minLength={2} name="q" placeholder="Apellido, nombre, DNI, mail o legajo" />
        <button type="submit">Buscar</button>
      </form>
      {q.length >= 2 && (
        <div className="sga-tabla-scroll">
          <table className="sga-tabla sga-tabla-mensajes">
            <thead><tr><th>Apellido y nombre</th><th>Documento</th><th>Mail institucional</th><th>Roles</th><th>Legajo</th><th>Cuenta</th><th>Acciones</th></tr></thead>
            <tbody>
              {personas.length > 0 ? personas.map((p) => (
                <tr key={p.id}>
                  <td>{p.apellido}, {p.nombre}</td>
                  <td>{p.tipo_documento} {p.nro_documento}</td>
                  <td>{p.mail_institucional}</td>
                  <td>{(p.roles ?? "").split(",").filter(Boolean).map(etiquetaRol).join(", ") || "—"}</td>
                  <td>{p.numero_legajo ?? "—"}</td>
                  <td>{p.con_cuenta ? <span className="sga-al-dia">Activa ✓</span> : <span className="sga-ayuda">Sin cuenta</span>}</td>
                  <td className="sga-col-lupa"><Link aria-label={`Ver a ${p.apellido}, ${p.nombre}`} href={`/administracion/personas/${p.id}`}>🔍</Link></td>
                </tr>
              )) : <tr><td className="sga-vacio" colSpan={7}>No se encontró a nadie.</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
