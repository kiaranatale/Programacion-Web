import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

type Carrera = {
  id: number;
  codigo: string;
  nombre: string;
  nivel: string;
  nivel_informatico: string | null;
  activo: boolean;
  escuela: { nombre: string } | null;
};

const niveles: Record<string, string> = { GRADO: "Grado", POSGRADO: "Posgrado" };

function texto(v: string | string[] | undefined): string {
  return typeof v === "string" ? v.trim() : "";
}

// Listado con los filtros del SGA actual. Es un formulario GET: los filtros
// quedan en la URL. `f=1` marca que el formulario se envió, para distinguir
// "Activa destildado" de "primera carga" (por defecto: solo activas, grado).
export default async function Carreras({ searchParams }: PageProps<"/carreras">) {
  const sp = await searchParams;
  const enviado = sp.f === "1";
  const codigo = texto(sp.codigo);
  const nombre = texto(sp.nombre);
  const escuela = texto(sp.escuela);
  const nivel = enviado ? texto(sp.nivel) : "GRADO";
  const soloActivas = enviado ? sp.activa === "1" : true;

  const supabase = await createClient();
  let consulta = supabase
    .schema("sga")
    .from("carrera")
    .select("id, codigo, nombre, nivel, nivel_informatico, activo, escuela:escuela_id!inner(nombre)")
    .order("nombre");
  if (codigo) consulta = consulta.ilike("codigo", `%${codigo}%`);
  if (nombre) consulta = consulta.ilike("nombre", `%${nombre}%`);
  if (escuela) consulta = consulta.ilike("escuela.nombre", `%${escuela}%`);
  if (nivel) consulta = consulta.eq("nivel", nivel);
  if (soloActivas) consulta = consulta.eq("activo", true);
  const { data: carreras, error } = await consulta.returns<Carrera[]>();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Listado de carreras</h2>
      <div className="sga-tab-box sga-listado">
        <h3 className="sga-subtitulo">Carreras</h3>
        <p className="sga-texto"><strong>Referencias:</strong> 🔍 = Ver detalles</p>
        {error && <p className="sga-error">No se pudo leer el listado: {error.message}</p>}

        <form className="sga-tabla-scroll">
          <input name="f" type="hidden" value="1" />
          <table className="sga-tabla sga-tabla-filtros">
            <thead>
              <tr>
                <th>Código</th><th>Nombre</th><th>Escuela</th><th>Nivel</th>
                <th>Nivel informativo</th><th>Activa</th><th>Acciones</th>
              </tr>
              <tr className="sga-fila-filtros">
                <td><input aria-label="Filtrar por código" defaultValue={codigo} name="codigo" /></td>
                <td><input aria-label="Filtrar por nombre" defaultValue={nombre} name="nombre" /></td>
                <td><input aria-label="Filtrar por escuela" defaultValue={escuela} name="escuela" /></td>
                <td>
                  <select aria-label="Filtrar por nivel" defaultValue={nivel} name="nivel">
                    <option value="">Todos</option>
                    <option value="GRADO">Grado</option>
                    <option value="POSGRADO">Posgrado</option>
                  </select>
                </td>
                <td></td>
                <td><input aria-label="Solo activas" defaultChecked={soloActivas} name="activa" type="checkbox" value="1" /></td>
                <td className="sga-acciones-filtro">
                  <button title="Filtrar" type="submit">Filtrar</button>
                  <Link href="/carreras" title="Limpiar filtros">Limpiar</Link>
                </td>
              </tr>
            </thead>
            <tbody>
              {carreras && carreras.length > 0 ? (
                carreras.map((c) => (
                  <tr key={c.id}>
                    <td>{c.codigo}</td>
                    <td className="sga-curso">{c.nombre}</td>
                    <td className="sga-horarios">{c.escuela?.nombre}</td>
                    <td className="sga-curso">{niveles[c.nivel] ?? c.nivel}</td>
                    <td className="sga-curso">{c.nivel_informatico}</td>
                    <td><input aria-label="Activa" checked={c.activo} disabled readOnly type="checkbox" /></td>
                    <td><Link aria-label={`Ver detalles de ${c.nombre}`} href={`/carreras/${encodeURIComponent(c.codigo)}`}>🔍</Link></td>
                  </tr>
                ))
              ) : (
                <tr><td className="sga-vacio" colSpan={7}>No hay carreras que coincidan con los filtros.</td></tr>
              )}
            </tbody>
          </table>
        </form>
      </div>
    </section>
  );
}
