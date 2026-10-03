import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fecha as formatoFecha } from "@/lib/legajo";

type Aula = { id: number; codigo: string; capacidad: number | null; edificio: { codigo: string; nombre: string } | null };
type Ocupacion = {
  aula_id: number;
  tipo: "CURSO" | "EVENTO" | "EXAMEN" | "REF_CURSO" | "REF_EVENTO" | "REF_SUPERPOSICION";
  descripcion: string;
  hora_inicio: string;
  hora_fin: string;
  inscriptos: number | null;
};
type Estado = "curso" | "evento" | "examen" | "excedida" | "superpuesta";

const INICIO = 8 * 60;
const FIN = 22 * 60;
const PASO = 30;
const dias = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
const referencias: [Estado, string][] = [
  ["curso", "Horarios de Cursos"],
  ["evento", "Horarios de Eventos Académicos"],
  ["examen", "Horarios de Exámenes"],
  ["excedida", "Capacidad Excedida"],
  ["superpuesta", "Superposición Horaria"],
];

const minutos = (h: string) => Number(h.slice(0, 2)) * 60 + Number(h.slice(3, 5));
const hora = (m: number) => `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
const iso = (d: Date) => d.toISOString().slice(0, 10);

function sumarDias(fechaIso: string, n: number): string {
  const d = new Date(`${fechaIso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return iso(d);
}

// Por defecto hoy; si es fin de semana, el lunes siguiente.
function fechaPorDefecto(): string {
  const hoy = new Date(`${iso(new Date())}T12:00:00Z`);
  const dia = hoy.getUTCDay();
  return dia === 6 ? sumarDias(iso(hoy), 2) : dia === 0 ? sumarDias(iso(hoy), 1) : iso(hoy);
}

const esReferencia = (o: Ocupacion) => o.tipo.startsWith("REF_");
const excede = (o: Ocupacion & { capacidad: number | null }) =>
  o.inscriptos !== null && o.capacidad !== null && o.inscriptos > o.capacidad;

function estadoCelda(items: (Ocupacion & { capacidad: number | null })[]): Estado | null {
  if (items.length === 0) return null;
  if (items.length > 1 || items[0].tipo === "REF_SUPERPOSICION") return "superpuesta";
  const [o] = items;
  if (excede(o)) return "excedida";
  if (o.tipo === "EXAMEN") return "examen";
  return o.tipo === "EVENTO" || o.tipo === "REF_EVENTO" ? "evento" : "curso";
}

export default async function OcupacionAulas({ searchParams }: PageProps<"/aulas">) {
  const sp = await searchParams;
  const fecha = typeof sp.fecha === "string" && /^\d{4}-\d{2}-\d{2}$/.test(sp.fecha) ? sp.fecha : fechaPorDefecto();
  const edificio = typeof sp.edificio === "string" ? sp.edificio : "";
  const aulaFiltro = typeof sp.aula === "string" ? sp.aula.trim().toLowerCase() : "";

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: aulas, error }, { data: ocupacion }, { data: edificios }] = await Promise.all([
    sga.from("aula").select("id, codigo, capacidad, edificio:edificio_id(codigo, nombre)").order("codigo").returns<Aula[]>(),
    sga.rpc("ocupacion_aulas", { p_fecha: fecha }),
    sga.from("edificio").select("codigo, nombre").order("nombre").returns<{ codigo: string; nombre: string }[]>(),
  ]);

  const visibles = (aulas ?? [])
    .filter((a) => !edificio || a.edificio?.codigo === edificio)
    .filter((a) => !aulaFiltro || a.codigo.toLowerCase().includes(aulaFiltro))
    .sort((a, b) => (a.edificio?.nombre ?? "").localeCompare(b.edificio?.nombre ?? "") || a.codigo.localeCompare(b.codigo));
  const capacidad = new Map(visibles.map((a) => [a.id, a.capacidad]));
  const delDia = ((ocupacion ?? []) as Ocupacion[])
    .filter((o) => capacidad.has(o.aula_id))
    .map((o) => ({ ...o, capacidad: capacidad.get(o.aula_id) ?? null }));
  const cargados = delDia.filter((o) => !esReferencia(o));
  const referencia = delDia.filter(esReferencia);

  const franjas: number[] = [];
  for (let m = INICIO; m < FIN; m += PASO) franjas.push(m);
  const enFranja = (aulaId: number, m: number) =>
    delDia.filter((o) => o.aula_id === aulaId && minutos(o.hora_inicio) < m + PASO && minutos(o.hora_fin) > m);

  const url = (f: string) =>
    `/aulas?${new URLSearchParams({ fecha: f, ...(edificio ? { edificio } : {}), ...(aulaFiltro ? { aula: aulaFiltro } : {}) })}`;
  const diaSemana = dias[new Date(`${fecha}T12:00:00Z`).getUTCDay()];
  const aulaNombre = new Map(visibles.map((a) => [a.id, `${a.codigo} (${a.edificio?.nombre ?? "—"})`]));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Ocupación de Aulas</h2>
      {error && <p className="sga-error">No se pudieron leer las aulas: {error.message}</p>}

      <form className="sga-filtros-aulas">
        <Link aria-label="Día anterior" className="sga-flecha" href={url(sumarDias(fecha, -1))}>&lt;</Link>
        <label>Fecha <input defaultValue={fecha} name="fecha" type="date" /></label>
        <Link aria-label="Día siguiente" className="sga-flecha" href={url(sumarDias(fecha, 1))}>&gt;</Link>
        <label>Aula <input defaultValue={aulaFiltro} name="aula" placeholder="Ej.: 101R" /></label>
        <label>
          Edificio{" "}
          <select defaultValue={edificio} name="edificio">
            <option value="">Todos</option>
            {(edificios ?? []).map((e) => <option key={e.codigo} value={e.codigo}>{e.nombre}</option>)}
          </select>
        </label>
        <button type="submit">Buscar</button>
        <span className="sga-texto">{diaSemana} {formatoFecha(fecha)}</span>
      </form>

      <div className="sga-referencias">
        <strong>Referencias:</strong>
        {referencias.map(([estado, texto]) => (
          <span key={estado}><i className={`sga-ocupacion-${estado}`} />{texto}</span>
        ))}
      </div>

      <div className="sga-tabla-scroll">
        <table className="sga-grilla-aulas">
          <thead>
            <tr>
              <th>Aula (cap.)</th>
              {franjas.map((m) => <th key={m}>{hora(m)}</th>)}
            </tr>
          </thead>
          <tbody>
            {visibles.length === 0 && (
              <tr><td className="sga-vacio" colSpan={franjas.length + 1}>No hay aulas cargadas.</td></tr>
            )}
            {visibles.map((a) => (
              <tr key={a.id}>
                <th title={a.edificio?.nombre}>{a.codigo} ({a.capacidad ?? "—"})</th>
                {franjas.map((m) => {
                  const items = enFranja(a.id, m);
                  const estado = estadoCelda(items);
                  return (
                    <td
                      className={estado ? `sga-ocupacion-${estado}` : undefined}
                      key={m}
                      title={items.map((o) => `${o.descripcion} · ${o.hora_inicio.slice(0, 5)}-${o.hora_fin.slice(0, 5)}`
                        + (o.inscriptos !== null ? ` · ${o.inscriptos}/${o.capacidad ?? "—"} inscriptos` : "")).join("\n") || undefined}
                    />
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Detalle del día</h3>
      {referencia.length > 0 && (
        <p className="sga-texto">
          La grilla incluye {referencia.length} bloques de ocupación de referencia tomados del SGA actual{" "}
          {referencia[0].descripcion.replace("Ocupación según el SGA actual ", "")}: muestran qué aulas están
          ocupadas, pero no qué materia las ocupa.
        </p>
      )}
      {cargados.length === 0 ? (
        <p className="sga-vacio">No hay clases, eventos ni exámenes cargados en el sistema para esta fecha.</p>
      ) : (
        <div className="sga-tabla-scroll">
          <table className="sga-tabla">
            <thead><tr><th>Horario</th><th>Aula</th><th>Tipo</th><th>Descripción</th><th>Inscriptos / capacidad</th></tr></thead>
            <tbody>
              {[...cargados].sort((x, y) => x.hora_inicio.localeCompare(y.hora_inicio) || x.aula_id - y.aula_id).map((o, i) => {
                const superpuesta = delDia.some((p) => p !== o && p.aula_id === o.aula_id
                  && minutos(p.hora_inicio) < minutos(o.hora_fin) && minutos(p.hora_fin) > minutos(o.hora_inicio));
                const excedida = excede(o);
                return (
                  <tr key={i}>
                    <td>{o.hora_inicio.slice(0, 5)} - {o.hora_fin.slice(0, 5)}</td>
                    <td>{aulaNombre.get(o.aula_id)}</td>
                    <td>{o.tipo === "CURSO" ? "Curso" : o.tipo === "EVENTO" ? "Evento académico" : "Examen"}</td>
                    <td>
                      {o.descripcion}
                      {superpuesta && <span className="sga-alerta-aula"> · Superposición horaria</span>}
                    </td>
                    <td className={excedida ? "sga-desaprobado" : undefined}>
                      {o.inscriptos !== null ? `${o.inscriptos} / ${o.capacidad ?? "—"}${excedida ? " (excedida)" : ""}` : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
