import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Semana, { type BloqueSemana } from "@/components/semana";
import { DIA_DE, minutos } from "@/lib/armador";
import { getCursosEnProgreso, type CursoEnProgreso } from "@/lib/cursos";
import { hoy } from "@/lib/hoy";
import { getLegajoActual, periodo } from "@/lib/legajo";
import { destinoNotificacion } from "@/lib/notificaciones";
import { getSesion } from "@/lib/sesion";

type Notificacion = { id: number; tipo: string; mensaje: string };
type Cronograma = { id: number; anio: number; nombre: string; url_archivo: string };

// Bloques de la grilla semanal: un color por curso
function bloquesDe(cursos: CursoEnProgreso[]): BloqueSemana[] {
  return cursos.flatMap((c, color) => c.comisiones.flatMap((co) => co.bloques.map((h) => ({
    dia: DIA_DE[h.dia_semana] ?? 0,
    desde: minutos(h.hora_inicio),
    hasta: minutos(h.hora_fin),
    modalidad: h.modalidad as BloqueSemana["modalidad"],
    codigo: c.codigo,
    materia: c.nombre,
    comision: co.nombre,
    detalle: h.aula ? `Aula ${h.aula.codigo}${h.aula.edificio ? ` · ${h.aula.edificio.nombre}` : ""}` : "",
    color,
  }))));
}

// Tabla de cursos con sus comisiones y horarios
function TablaCursos({ cursos }: { cursos: CursoEnProgreso[] }) {
  return (
    <div className="sga-tabla-scroll">
      <table className="sga-tabla">
        <thead>
          <tr><th>Curso</th><th>Horarios</th><th>Acciones</th></tr>
        </thead>
        <tbody>
          {cursos.map((curso) => (
            <tr key={curso.id}>
              <td className="sga-curso">{curso.codigo} - {curso.nombre}</td>
              <td className="sga-horarios">
                {curso.comisiones.map((comision) => (
                  <div key={comision.nombre}>
                    <strong>{comision.nombre}</strong>{" "}
                    {comision.horarios.length > 0 ? comision.horarios.join(" | ") : "Sin horarios cargados"}
                  </div>
                ))}
              </td>
              <td className="sga-col-lupa">
                <Link aria-label={`Ver detalles de ${curso.nombre}`} href={`/cursos/${curso.id}`}>🔍</Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Accesos de las cajas superiores; se convierten en links a medida que se
// implementa cada módulo.
const tareas = [
  { label: "Iniciar nuevo trámite", href: "/tramites/nuevo" },
  { label: "Ver historial de trámites", href: "/tramites" },
];
function tramites(plan: string | undefined): { label: string; href?: string }[] {
  return [
    { label: "Inscripción a cursadas", href: "/inscripciones/cursadas" },
    { label: `Inscripción a exámenes finales${plan ? ` (${plan})` : ""}`, href: "/inscripciones/finales" },
    { label: "Inscripción a eventos académicos", href: "/inscripciones/eventos" },
    { label: "Ver intercambio/s", href: "/intercambios" },
  ];
}

export default async function Inicio() {
  const sesion = await getSesion();
  if (!sesion) return null;

  const supabase = await createClient();
  const sga = supabase.schema("sga");

  const [{ data: notificaciones }, { data: cronogramas }, cursos, { count: sinLeer }, { data: encuestas }, { legajo }] = await Promise.all([
    sga
      .from("notificacion")
      .select("id, tipo, mensaje")
      .eq("persona_id", sesion.persona?.id ?? 0)
      .eq("leida", false)
      .order("fecha", { ascending: false })
      .limit(5)
      .returns<Notificacion[]>(),
    sga
      .from("cronograma_academico")
      .select("id, anio, nombre, url_archivo")
      .order("anio", { ascending: false })
      .returns<Cronograma[]>(),
    getCursosEnProgreso(sesion),
    sga.from("mensaje_recibido").select("id", { count: "exact", head: true }).is("leido_en", null),
    sga.rpc("encuestas_para_mi"),
    getLegajoActual(),
  ]);
  // Solicitudes de cursada que esperan la asignación de vacantes (el
  // alumno queda inscripto recién cuando Administración la confirma)
  const [{ data: solicitudes }, { data: periodosInscripcion }] = legajo
    ? await Promise.all([
        sga.from("solicitud_cursada").select("curso:curso_id(anio, periodo)")
          .eq("legajo_id", legajo.id).in("estado", ["PENDIENTE", "ASIGNADA"])
          .returns<{ curso: { anio: number; periodo: string } | null }[]>(),
        sga.from("periodo_inscripcion_cursada").select("anio, periodo")
          .eq("asignacion_confirmada", false).returns<{ anio: number; periodo: string }[]>(),
      ])
    : [{ data: [] }, { data: [] }];
  const sinConfirmar = new Set((periodosInscripcion ?? []).map((p) => `${p.anio}-${p.periodo}`));
  const solicitudesEnEspera = (solicitudes ?? []).filter((s) => s.curso && sinConfirmar.has(`${s.curso.anio}-${s.curso.periodo}`)).length;
  // En curso (ya empezaron) y del próximo cuatrimestre (todavía no)
  const hoyStr = hoy();
  const enCurso = cursos.filter((c) => c.fechaInicio <= hoyStr);
  const proximos = cursos.filter((c) => c.fechaInicio > hoyStr);
  const conGrilla = !sesion.roles.includes("ADMINISTRATIVO");
  const encuestasPendientes = ((encuestas ?? []) as { estado: string; respondida: boolean }[])
    .filter((e) => e.estado === "ACTIVA" && !e.respondida).length;
  // Docentes: notas de final pendientes de mesas ya tomadas
  const docente = sesion.roles.includes("DOCENTE") || sesion.roles.includes("AYUDANTE");
  const { data: mesas } = docente ? await sga.rpc("mesas_de_final_docente") : { data: [] };
  // Administración: trámites sin resolver
  const admin = sesion.roles.includes("ADMINISTRATIVO");
  const { count: tramitesAbiertos } = admin
    ? await sga.from("tramite").select("id", { count: "exact", head: true }).in("estado", ["PENDIENTE", "EN_CURSO"])
    : { count: 0 };
  const notasPendientes = ((mesas ?? []) as { fecha: string; sin_nota: number }[])
    .filter((m) => m.fecha <= hoy()).reduce((total, m) => total + m.sin_nota, 0);

  return (
    <>
      {!sesion.persona && (
        <section className="sga-panel sga-aviso">
          Tu usuario ({sesion.email}) no está vinculado a ninguna persona del sistema.
          Pedile a Administración que cargue tus datos con este mismo mail.
        </section>
      )}

      <section className="sga-panel sga-cajas">
        <div className="sga-caja">
          <h3>Notificaciones</h3>
          {(sinLeer ?? 0) > 0 || solicitudesEnEspera > 0 || encuestasPendientes > 0 || notasPendientes > 0 || (tramitesAbiertos ?? 0) > 0 || (notificaciones && notificaciones.length > 0) ? (
            <ul>
              {(sinLeer ?? 0) > 0 && (
                <li>
                  <Link href="/usuario/mensajes">
                    {sinLeer === 1 ? "Tenés 1 mensaje sin leer" : `Tenés ${sinLeer} mensajes sin leer`}
                  </Link>
                </li>
              )}
              {solicitudesEnEspera > 0 && (
                <li>
                  <Link href="/inscripciones/cursadas">
                    {solicitudesEnEspera === 1
                      ? "Tenés 1 solicitud de cursada esperando la asignación de vacantes"
                      : `Tenés ${solicitudesEnEspera} solicitudes de cursada esperando la asignación de vacantes`}
                  </Link>
                </li>
              )}
              {notasPendientes > 0 && (
                <li>
                  <Link href="/docencia/notas">
                    {notasPendientes === 1 ? "Tenés 1 nota de final para cargar" : `Tenés ${notasPendientes} notas de final para cargar`}
                  </Link>
                </li>
              )}
              {(tramitesAbiertos ?? 0) > 0 && (
                <li>
                  <Link href="/administracion/tramites">
                    {tramitesAbiertos === 1 ? "Hay 1 trámite sin resolver" : `Hay ${tramitesAbiertos} trámites sin resolver`}
                  </Link>
                </li>
              )}
              {encuestasPendientes > 0 && (
                <li>
                  <Link href="/encuestas">
                    {encuestasPendientes === 1 ? "Tenés 1 encuesta para responder" : `Tenés ${encuestasPendientes} encuestas para responder`}
                  </Link>
                </li>
              )}
              {(notificaciones ?? []).map((n) => (
                <li key={n.id}>
                  {destinoNotificacion[n.tipo] ? <Link href={destinoNotificacion[n.tipo]}>{n.mensaje}</Link> : n.mensaje}
                </li>
              ))}
            </ul>
          ) : (
            <p className="sga-vacio">Sin notificaciones pendientes</p>
          )}
        </div>
        <div className="sga-caja">
          <h3>Tareas</h3>
          <ul>{tareas.map((t) => <li key={t.href}><Link href={t.href}>{t.label}</Link></li>)}</ul>
        </div>
        <div className="sga-caja">
          <h3>Trámites</h3>
          <ul>
            {tramites(legajo?.plan_estudio?.codigo).map((t) => (
              <li key={t.label}>
                {t.href ? <Link href={t.href}>{t.label}</Link> : <span className="sga-proximamente" title="Próximamente">{t.label}</span>}
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* Calendarios académicos en PDF: solo si hay alguno cargado */}
      {cronogramas && cronogramas.length > 0 && (
        <section className="sga-panel">
          <h2 className="sga-titulo">Cronogramas Académicos</h2>
          <ul className="sga-cronogramas">
            {cronogramas.map((c) => (
              <li key={c.id}>
                <a href={c.url_archivo} rel="noreferrer" target="_blank">{c.nombre.toUpperCase()}</a>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="sga-panel">
        <h2 className="sga-titulo">Cursos en progreso</h2>
        {enCurso.length > 0 ? (
          <>
            {conGrilla && <Semana bloques={bloquesDe(enCurso)} />}
            <TablaCursos cursos={enCurso} />
          </>
        ) : (
          <p className="sga-vacio">No tenés cursos en progreso.</p>
        )}
      </section>

      {proximos.length > 0 && (
        <section className="sga-panel">
          <h2 className="sga-titulo">Próximo cuatrimestre · {periodo(proximos[0].anio, proximos[0].periodo)}</h2>
          {conGrilla && <Semana bloques={bloquesDe(proximos)} />}
          <TablaCursos cursos={proximos} />
        </section>
      )}
    </>
  );
}
