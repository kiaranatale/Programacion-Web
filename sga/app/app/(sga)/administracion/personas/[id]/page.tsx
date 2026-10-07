import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, periodo } from "@/lib/legajo";
import { ROLES, TIPOS_DOCUMENTO, etiquetaRol } from "@/lib/personas";
import { getSesion } from "@/lib/sesion";
import { asignarComision, cambiarRol, crearLegajo, mandarAcceso, quitarComision } from "../actions";

type Persona = {
  id: number;
  tipo_documento: string;
  nro_documento: string;
  nombre: string;
  apellido: string;
  mail_institucional: string;
  fecha_nacimiento: string | null;
  nacionalidad: string | null;
  auth_user_id: string | null;
  persona_rol: { rol: string; activo: boolean }[];
  legajo: UnoOVarios<{ numero_legajo: string; fecha_registracion: string; plan_estudio: { codigo: string; carrera: { nombre_oficial: string } | null } | null }>;
  docente: UnoOVarios<{
    docente_comision: {
      id: number;
      comision: { nombre: string; curso: { anio: number; periodo: string; materia: { codigo: string; nombre: string } | null } | null } | null;
    }[];
  }>;
};
// legajo y docente son 1 a 1 con persona: PostgREST los devuelve como objeto
type UnoOVarios<T> = T | T[] | null;
const uno = <T,>(x: UnoOVarios<T>): T | undefined => (Array.isArray(x) ? x[0] : x ?? undefined);
type Plan = { id: number; codigo: string; carrera: { nombre_oficial: string } | null };

// Ficha de una persona: roles, legajo, comisiones y cuenta de acceso.
export default async function FichaPersona({ params, searchParams }: PageProps<"/administracion/personas/[id]">) {
  const id = Number((await params).id);
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Persona</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: p }, { data: planesData }, { data: cursos }] = await Promise.all([
    sga.from("persona").select(`id, tipo_documento, nro_documento, nombre, apellido, mail_institucional, fecha_nacimiento, nacionalidad,
      auth_user_id, persona_rol(rol, activo),
      legajo(numero_legajo, fecha_registracion, plan_estudio:plan_estudio_id(codigo, carrera:carrera_id(nombre_oficial))),
      docente(docente_comision(id, comision:comision_id(nombre, curso:curso_id(anio, periodo, materia:materia_id(codigo, nombre)))))`)
      .eq("id", id).maybeSingle<Persona>(),
    sga.from("plan_estudio").select("id, codigo, carrera:carrera_id(nombre_oficial)").order("codigo").returns<Plan[]>(),
    sga.from("curso").select("anio, periodo, fecha_inicio, fecha_fin").eq("activo", true)
      .returns<{ anio: number; periodo: string; fecha_inicio: string; fecha_fin: string }[]>(),
  ]);
  if (!p) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Persona</h2>
        <p className="sga-error">La persona no existe.</p>
        <Link className="sga-volver" href="/administracion/personas">← Volver a Personas</Link>
      </section>
    );
  }
  const activos = new Set(p.persona_rol.filter((r) => r.activo).map((r) => r.rol));
  const legajo = uno(p.legajo);
  const comisiones = (uno(p.docente)?.docente_comision ?? []).slice().sort((a, b) =>
    `${b.comision?.curso?.anio}${b.comision?.curso?.periodo}`.localeCompare(`${a.comision?.curso?.anio}${a.comision?.curso?.periodo}`));
  const cuatrimestres = [...new Set((cursos ?? []).map((c) => `${c.anio}|${c.periodo}`))].sort().reverse();
  // Por defecto, el cuatrimestre en curso
  const hoyStr = hoy();
  const enCurso = (cursos ?? []).find((c) => c.fecha_inicio <= hoyStr && hoyStr <= c.fecha_fin);
  const cuatrimestreInicial = enCurso ? `${enCurso.anio}|${enCurso.periodo}` : cuatrimestres[0] ?? "";
  const docente = activos.has("DOCENTE") || activos.has("AYUDANTE");
  const oculto = <input name="persona_id" type="hidden" value={p.id} />;

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{p.apellido}, {p.nombre}</h2>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      <dl className="sga-datos sga-datos-tramite">
        <div><dt>Documento:</dt><dd>{TIPOS_DOCUMENTO[p.tipo_documento] ?? p.tipo_documento} {p.nro_documento}</dd></div>
        <div><dt>Mail institucional:</dt><dd>{p.mail_institucional}</dd></div>
        {p.fecha_nacimiento && <div><dt>Fecha de nacimiento:</dt><dd>{fecha(p.fecha_nacimiento)}</dd></div>}
        {p.nacionalidad && <div><dt>Nacionalidad:</dt><dd>{p.nacionalidad}</dd></div>}
        <div>
          <dt>Cuenta:</dt>
          <dd className="sga-acciones-doc">
            {p.auth_user_id ? <span className="sga-al-dia">Activa ✓</span> : <span className="sga-ayuda">Todavía no entró al SGA</span>}
            <form action={mandarAcceso}>
              {oculto}
              <button type="submit">{p.auth_user_id ? "Mandar mail para cambiar la contraseña" : "Crear cuenta y mandar mail de acceso"}</button>
            </form>
          </dd>
        </div>
      </dl>

      <h3 className="sga-subtitulo">Roles</h3>
      <div className="sga-acciones-doc sga-roles-ficha">
        {ROLES.map((r) => (
          <form action={cambiarRol} key={r}>
            {oculto}
            <input name="rol" type="hidden" value={r} />
            <input name="activar" type="hidden" value={activos.has(r) ? "false" : "true"} />
            <span className={activos.has(r) ? "sga-al-dia" : "sga-ayuda"}>{activos.has(r) ? "✓" : "—"} {etiquetaRol(r)}</span>
            <button className={activos.has(r) ? "sga-boton-peligro" : undefined} type="submit">{activos.has(r) ? "Quitar" : "Asignar"}</button>
          </form>
        ))}
      </div>

      {activos.has("ALUMNO") && (
        <>
          <h3 className="sga-subtitulo">Legajo</h3>
          {legajo ? (
            <p className="sga-texto">
              <strong>{legajo.numero_legajo}</strong> · {legajo.plan_estudio?.codigo} · {legajo.plan_estudio?.carrera?.nombre_oficial} · desde el{" "}
              {fecha(legajo.fecha_registracion)}
            </p>
          ) : (
            <form action={crearLegajo} className="sga-form-fecha-final">
              {oculto}
              <select aria-label="Plan de estudio" defaultValue="" name="plan_id" required>
                <option disabled value="">Plan de estudio…</option>
                {(planesData ?? []).map((pl) => <option key={pl.id} value={pl.id}>{pl.codigo} · {pl.carrera?.nombre_oficial}</option>)}
              </select>
              <input aria-label="Número de legajo" name="numero_legajo" placeholder="Número de legajo" required />
              <button type="submit">Crear legajo</button>
            </form>
          )}
        </>
      )}

      {(docente || comisiones.length > 0) && (
        <>
          <h3 className="sga-subtitulo">Comisiones a cargo</h3>
          <div className="sga-tabla-scroll">
            <table className="sga-tabla sga-tabla-mensajes">
              <thead><tr><th>Cuatrimestre</th><th>Materia</th><th>Comisión</th><th></th></tr></thead>
              <tbody>
                {comisiones.length > 0 ? comisiones.map((dc) => (
                  <tr key={dc.id}>
                    <td>{dc.comision?.curso && periodo(dc.comision.curso.anio, dc.comision.curso.periodo)}</td>
                    <td>{dc.comision?.curso?.materia?.codigo} - {dc.comision?.curso?.materia?.nombre}</td>
                    <td>{dc.comision?.nombre}</td>
                    <td className="sga-acciones-doc">
                      <form action={quitarComision}>
                        {oculto}
                        <input name="docente_comision_id" type="hidden" value={dc.id} />
                        <button className="sga-boton-peligro" type="submit">Quitar</button>
                      </form>
                    </td>
                  </tr>
                )) : <tr><td className="sga-vacio" colSpan={4}>No tiene comisiones asignadas.</td></tr>}
              </tbody>
            </table>
          </div>
          {docente && (
            <form action={asignarComision} className="sga-form-fecha-final">
              {oculto}
              <select aria-label="Cuatrimestre" defaultValue={cuatrimestreInicial} name="cuatrimestre" required>
                {cuatrimestres.map((c) => {
                  const [a, per] = c.split("|");
                  return <option key={c} value={c}>{periodo(Number(a), per)}</option>;
                })}
              </select>
              <input aria-label="Código de materia" name="codigo" placeholder="Código (ej. 71.38)" required />
              <input aria-label="Comisión" defaultValue="A" maxLength={10} name="comision" required />
              <button type="submit">Asignar comisión</button>
            </form>
          )}
        </>
      )}

      <Link className="sga-volver" href="/administracion/personas">← Volver a Personas</Link>
    </section>
  );
}
