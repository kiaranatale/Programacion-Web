import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fecha } from "@/lib/legajo";

type CursoListado = {
  id: number;
  codigo: string;
  materia: string;
  departamento: string;
  anio: number;
  periodo: string;
  fecha_inicio: string;
  fecha_fin: string;
  activo: boolean;
  alumnos: number;
};

const POR_PAGINA = 20;
const periodos: Record<string, string> = { "1C": "Primer Cuat.", "2C": "Segundo Cuat." };

function texto(v: string | string[] | undefined): string {
  return typeof v === "string" ? v.trim() : "";
}

// Por defecto, como el SGA actual: el cuatrimestre en curso y solo activos.
function periodoActual() {
  const hoy = new Date();
  return { anio: String(hoy.getFullYear()), periodo: hoy.getMonth() >= 6 ? "2C" : "1C" };
}

export default async function Cursos({ searchParams }: PageProps<"/cursos">) {
  const sp = await searchParams;
  const enviado = sp.f === "1";
  const actual = periodoActual();
  const filtros = {
    codigo: texto(sp.codigo),
    materia: texto(sp.materia),
    departamento: texto(sp.departamento),
    periodo: enviado ? texto(sp.periodo) : actual.periodo,
    anio: enviado ? texto(sp.anio) : actual.anio,
    activo: enviado ? sp.activo === "1" : true,
  };
  const pagina = Math.max(1, Number(texto(sp.pagina)) || 1);

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  let consulta = sga
    .from("curso_listado")
    .select("id, codigo, materia, departamento, anio, periodo, fecha_inicio, fecha_fin, activo, alumnos", { count: "exact" })
    .order("materia")
    .order("codigo")
    .order("fecha_inicio")
    .range((pagina - 1) * POR_PAGINA, pagina * POR_PAGINA - 1);
  if (filtros.codigo) consulta = consulta.ilike("codigo", `%${filtros.codigo}%`);
  if (filtros.materia) consulta = consulta.ilike("materia", `%${filtros.materia}%`);
  if (filtros.departamento) consulta = consulta.eq("departamento", filtros.departamento);
  if (filtros.periodo) consulta = consulta.eq("periodo", filtros.periodo);
  if (/^\d{4}$/.test(filtros.anio)) consulta = consulta.eq("anio", Number(filtros.anio));
  if (filtros.activo) consulta = consulta.eq("activo", true);

  const [{ data: cursos, count, error }, { data: departamentos }] = await Promise.all([
    consulta.returns<CursoListado[]>(),
    sga.from("departamento").select("nombre").order("nombre").returns<{ nombre: string }[]>(),
  ]);

  const total = count ?? 0;
  const paginas = Math.max(1, Math.ceil(total / POR_PAGINA));
  const desde = total === 0 ? 0 : (pagina - 1) * POR_PAGINA + 1;
  const hasta = Math.min(pagina * POR_PAGINA, total);

  // Links de paginación que conservan los filtros
  const urlPagina = (n: number) => {
    const p = new URLSearchParams({ f: "1", pagina: String(n), periodo: filtros.periodo, anio: filtros.anio });
    if (filtros.codigo) p.set("codigo", filtros.codigo);
    if (filtros.materia) p.set("materia", filtros.materia);
    if (filtros.departamento) p.set("departamento", filtros.departamento);
    if (filtros.activo) p.set("activo", "1");
    return `/cursos?${p}`;
  };
  const vecinas = Array.from({ length: paginas }, (_, i) => i + 1).filter((n) => Math.abs(n - pagina) <= 4);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Cursos</h2>
      <div className="sga-tab-box sga-listado">
        <h3 className="sga-subtitulo">Listado de Cursos</h3>
        <p className="sga-texto"><strong>Referencias:</strong> 🔍 = Ver Detalles</p>
        {error && <p className="sga-error">No se pudo leer el listado: {error.message}</p>}

        <div className="sga-paginador">
          <strong>Página {desde} a {hasta} de {total}</strong>
          <nav aria-label="Páginas">
            {pagina > 1 && <><Link href={urlPagina(1)}>&lt;&lt;</Link> <Link href={urlPagina(pagina - 1)}>&lt;</Link></>}
            {vecinas.map((n) => n === pagina
              ? <strong key={n}>{n}</strong>
              : <Link href={urlPagina(n)} key={n}>{n}</Link>)}
            {pagina < paginas && <><Link href={urlPagina(pagina + 1)}>&gt;</Link> <Link href={urlPagina(paginas)}>&gt;&gt;</Link></>}
          </nav>
        </div>

        <form className="sga-tabla-scroll">
          <input name="f" type="hidden" value="1" />
          <table className="sga-tabla sga-tabla-filtros">
            <thead>
              <tr>
                <th>Cód.</th><th>Materia</th><th>Departamento</th><th>Período</th><th>Año</th>
                <th>Comienzo</th><th>Fin</th><th>Activo</th><th>Alumnos</th><th>Acciones</th>
              </tr>
              <tr className="sga-fila-filtros">
                <td><input aria-label="Filtrar por código" defaultValue={filtros.codigo} name="codigo" /></td>
                <td><input aria-label="Filtrar por materia" defaultValue={filtros.materia} name="materia" /></td>
                <td>
                  <select aria-label="Filtrar por departamento" defaultValue={filtros.departamento} name="departamento">
                    <option value="">Todos</option>
                    {(departamentos ?? []).map((d) => <option key={d.nombre} value={d.nombre}>{d.nombre}</option>)}
                  </select>
                </td>
                <td>
                  <select aria-label="Filtrar por período" defaultValue={filtros.periodo} name="periodo">
                    <option value="">Todos</option>
                    <option value="1C">Primer Cuat.</option>
                    <option value="2C">Segundo Cuat.</option>
                  </select>
                </td>
                <td><input aria-label="Filtrar por año" defaultValue={filtros.anio} inputMode="numeric" name="anio" /></td>
                <td></td><td></td>
                <td><input aria-label="Solo activos" defaultChecked={filtros.activo} name="activo" type="checkbox" value="1" /></td>
                <td></td>
                <td className="sga-acciones-filtro">
                  <button type="submit">Filtrar</button>
                  <Link href="/cursos">Limpiar</Link>
                </td>
              </tr>
            </thead>
            <tbody>
              {cursos && cursos.length > 0 ? cursos.map((c) => (
                <tr key={c.id}>
                  <td className="sga-materia-plan">{c.codigo}</td>
                  <td className="sga-curso">{c.materia}</td>
                  <td className="sga-curso">{c.departamento}</td>
                  <td className="sga-curso">{periodos[c.periodo] ?? c.periodo}</td>
                  <td className="sga-materia-plan">{c.anio}</td>
                  <td className="sga-aprobado">{fecha(c.fecha_inicio)}</td>
                  <td className="sga-desaprobado">{fecha(c.fecha_fin)}</td>
                  <td><input aria-label="Activo" checked={c.activo} disabled readOnly type="checkbox" /></td>
                  <td className="sga-curso">{c.alumnos}</td>
                  <td><Link aria-label={`Ver detalles de ${c.materia}`} href={`/cursos/${c.id}`}>🔍</Link></td>
                </tr>
              )) : (
                <tr><td className="sga-vacio" colSpan={10}>No hay cursos que coincidan con los filtros.</td></tr>
              )}
            </tbody>
          </table>
        </form>
      </div>
    </section>
  );
}
