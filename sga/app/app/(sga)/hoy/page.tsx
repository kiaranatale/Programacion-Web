import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import {
  PUBLICACION_SELECT, autor, cuandoEvento, fechaHora, getMisOrganizaciones, hoy, tipos,
  type Organizacion, type Publicacion,
} from "@/lib/hoy";

const POR_PAGINA = 10;
const RESUMEN = 280;

function resumen(cuerpo: string): string {
  return cuerpo.length > RESUMEN ? `${cuerpo.slice(0, RESUMEN).trimEnd()}…` : cuerpo;
}

// Hoy en el ITBA: foro de las organizaciones estudiantiles. Publicaciones
// más nuevas primero, filtrables por organización y tipo, y al costado
// los próximos eventos.
export default async function HoyEnElItba({ searchParams }: PageProps<"/hoy">) {
  const params = await searchParams;
  const org = typeof params.org === "string" ? params.org : "";
  const tipo = params.tipo === "EVENTO" || params.tipo === "NOVEDAD" ? params.tipo : "";
  const pagina = Math.max(1, Number(params.pagina) || 1);
  const ok = typeof params.ok === "string" ? params.ok : null;

  const supabase = await createClient();
  const sga = supabase.schema("sga");

  let consulta = sga
    .from("publicacion_listado")
    .select(PUBLICACION_SELECT, { count: "exact" })
    .order("creada", { ascending: false })
    .range((pagina - 1) * POR_PAGINA, pagina * POR_PAGINA - 1);
  if (org) consulta = consulta.eq("organizacion_id", Number(org));
  if (tipo) consulta = consulta.eq("tipo", tipo);

  const [{ data: publicaciones, count }, { data: proximos }, { data: organizaciones }, misOrganizaciones] = await Promise.all([
    consulta.returns<Publicacion[]>(),
    sga.from("publicacion_listado")
      .select("id, organizacion, titulo, fecha_evento, hora_evento, lugar")
      .eq("tipo", "EVENTO")
      .gte("fecha_evento", hoy())
      .order("fecha_evento")
      .order("hora_evento", { nullsFirst: true })
      .limit(6)
      .returns<Pick<Publicacion, "id" | "organizacion" | "titulo" | "fecha_evento" | "hora_evento" | "lugar">[]>(),
    sga.from("organizacion").select("id, nombre, descripcion, activa").eq("activa", true).order("nombre").returns<Organizacion[]>(),
    getMisOrganizaciones(),
  ]);

  const total = count ?? 0;
  const paginas = Math.max(1, Math.ceil(total / POR_PAGINA));
  const urlPagina = (n: number) => {
    const p = new URLSearchParams();
    if (org) p.set("org", org);
    if (tipo) p.set("tipo", tipo);
    if (n > 1) p.set("pagina", String(n));
    const q = p.toString();
    return q ? `/hoy?${q}` : "/hoy";
  };

  return (
    <section className="sga-panel">
      <div className="sga-hoy-encabezado">
        <h2 className="sga-titulo sga-titulo-grande">Hoy en el ITBA</h2>
        {misOrganizaciones.length > 0 && <Link className="sga-boton" href="/hoy/nueva">+ Nueva publicación</Link>}
      </div>
      <p className="sga-texto">Eventos y novedades de las organizaciones estudiantiles.</p>
      {ok && <p className="sga-mensaje-ok" role="status">{ok}</p>}

      <div className="sga-hoy">
        <div className="sga-hoy-feed">
          <form className="sga-hoy-filtros">
            <select aria-label="Organización" defaultValue={org} name="org">
              <option value="">Todas las organizaciones</option>
              {(organizaciones ?? []).map((o) => <option key={o.id} value={o.id}>{o.nombre}</option>)}
            </select>
            <select aria-label="Tipo" defaultValue={tipo} name="tipo">
              <option value="">Eventos y novedades</option>
              <option value="EVENTO">Solo eventos</option>
              <option value="NOVEDAD">Solo novedades</option>
            </select>
            <button type="submit">Filtrar</button>
            {(org || tipo) && <Link href="/hoy">Limpiar</Link>}
          </form>

          {publicaciones && publicaciones.length > 0 ? publicaciones.map((p) => (
            <article className="sga-post" key={p.id}>
              <header>
                <span className={`sga-etiqueta sga-etiqueta-${p.tipo.toLowerCase()}`}>{tipos[p.tipo]}</span>
                <Link className="sga-post-org" href={`/hoy?org=${p.organizacion_id}`}>{p.organizacion}</Link>
                <span className="sga-post-meta">{fechaHora(p.creada)}{autor(p) && ` · ${autor(p)}`}</span>
              </header>
              <h3><Link href={`/hoy/${p.id}`}>{p.titulo}</Link></h3>
              {p.tipo === "EVENTO" && (
                <p className="sga-post-evento">📅 {cuandoEvento(p.fecha_evento, p.hora_evento)}{p.lugar && ` · ${p.lugar}`}</p>
              )}
              <p className="sga-post-cuerpo">{resumen(p.cuerpo)}</p>
              <Link className="sga-post-comentarios" href={`/hoy/${p.id}#comentarios`}>
                {p.comentarios === 1 ? "1 comentario" : `${p.comentarios} comentarios`}
              </Link>
            </article>
          )) : (
            <p className="sga-vacio">Todavía no hay publicaciones{org || tipo ? " con esos filtros" : ""}.</p>
          )}

          {paginas > 1 && (
            <nav className="sga-hoy-paginas" aria-label="Páginas">
              {pagina > 1 && <Link href={urlPagina(pagina - 1)}>← Más nuevas</Link>}
              <span>Página {pagina} de {paginas}</span>
              {pagina < paginas && <Link href={urlPagina(pagina + 1)}>Más viejas →</Link>}
            </nav>
          )}
        </div>

        <aside className="sga-hoy-lateral">
          <div className="sga-caja">
            <h3>Próximos eventos</h3>
            {proximos && proximos.length > 0 ? (
              <ul className="sga-proximos">
                {proximos.map((e) => (
                  <li key={e.id}>
                    <Link href={`/hoy/${e.id}`}>{e.titulo}</Link>
                    <span>{cuandoEvento(e.fecha_evento, e.hora_evento)}</span>
                    <span>{e.organizacion}{e.lugar && ` · ${e.lugar}`}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="sga-vacio">No hay eventos próximos.</p>
            )}
          </div>
          <div className="sga-caja">
            <h3>Organizaciones</h3>
            <ul className="sga-organizaciones">
              {(organizaciones ?? []).map((o) => (
                <li key={o.id}>
                  <Link href={`/hoy?org=${o.id}`}>{o.nombre}</Link>
                  {o.descripcion && <span>{o.descripcion}</span>}
                </li>
              ))}
            </ul>
          </div>
        </aside>
      </div>
    </section>
  );
}
