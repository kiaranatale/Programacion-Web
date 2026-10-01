"use client";

import { useState } from "react";

const modules = [
  { id: "overview", label: "Inicio", mark: "IN", detail: "Resumen de actividad" },
  { id: "students", label: "Alumnos", mark: "AL", detail: "Legajos y trayectoria" },
  { id: "courses", label: "Cursadas", mark: "CU", detail: "Cursos e inscripciones" },
  { id: "exams", label: "Exámenes", mark: "EX", detail: "Finales y calificaciones" },
  { id: "rooms", label: "Aulas", mark: "AU", detail: "Espacios y horarios" },
  { id: "billing", label: "Facturación", mark: "FA", detail: "Aranceles y pagos" },
  { id: "staff", label: "Docentes", mark: "DO", detail: "Equipo y comisiones" },
] as const;

const metrics = [
  { label: "Alumnos activos", value: "1.284", change: "+ 3,2%", tone: "green" },
  { label: "Cursos abiertos", value: "42", change: "Este período", tone: "yellow" },
  { label: "Docentes", value: "86", change: "En 12 carreras", tone: "coral" },
  { label: "Trámites", value: "18", change: "6 requieren atención", tone: "ink" },
];

const schedule = [
  { time: "09:00", title: "Análisis Matemático II", meta: "Aula 304 · Comisión A", tag: "En curso" },
  { time: "11:30", title: "Introducción a la Programación", meta: "Lab. 2 · Comisión B", tag: "Próxima" },
  { time: "14:00", title: "Economía de la Empresa", meta: "Aula 108 · Comisión A", tag: "Presencial" },
];

const moduleNotes: Record<string, string[]> = {
  students: ["Consulta de legajos y datos personales", "Seguimiento de trayectoria académica", "Documentación y situación del alumno"],
  courses: ["Oferta académica por período", "Comisiones, cupos e inscripciones", "Seguimiento de cursadas"],
  exams: ["Calendario de exámenes finales", "Inscripciones e intentos", "Carga y consulta de calificaciones"],
  rooms: ["Disponibilidad de aulas", "Horarios de comisiones", "Agenda de espacios académicos"],
  billing: ["Aranceles e ítems facturables", "Facturas y órdenes de pago", "Becas y descuentos"],
  staff: ["Plantel docente", "Asignación a comisiones", "Ausencias y evaluaciones"],
};

export default function Home() {
  const [activeModule, setActiveModule] = useState<string>("overview");
  const [search, setSearch] = useState("");
  const visibleModules = modules.filter((module) =>
    `${module.label} ${module.detail}`.toLowerCase().includes(search.toLowerCase()),
  );
  const active = modules.find((module) => module.id === activeModule) ?? modules[0];

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="#inicio" onClick={() => setActiveModule("overview")}>
          <span className="brand-mark">S</span>
          <span className="brand-copy"><strong>SGA</strong><small>ITBA · ACADÉMICO</small></span>
        </a>

        <div className="nav-heading">ESPACIO DE TRABAJO</div>
        <nav className="module-nav" aria-label="Módulos del sistema">
          {visibleModules.map((module) =>
            module.id === "rooms" ? (
              <a className="nav-item" href="/aulas" key={module.id}>
                <span className="nav-mark">{module.mark}</span>
                <span>{module.label}</span>
              </a>
            ) : (
              <button
                className={`nav-item ${activeModule === module.id ? "is-active" : ""}`}
                key={module.id}
                onClick={() => setActiveModule(module.id)}
                type="button"
              >
                <span className="nav-mark">{module.mark}</span>
                <span>{module.label}</span>
                {module.id === "overview" && <span className="nav-dot" aria-hidden="true" />}
              </button>
            ),
          )}
          {visibleModules.length === 0 && <p className="empty-search">No hay módulos coincidentes.</p>}
        </nav>

        <div className="sidebar-bottom">
          <div className="connection-card">
            <span className="connection-light" />
            <div><strong>Modo demostración</strong><small>Sin conexión a Supabase</small></div>
          </div>
          <div className="profile">
            <span className="avatar">LF</span>
            <span className="profile-copy"><strong>Lucía Fernández</strong><small>Administración</small></span>
            <span className="profile-more" aria-hidden="true">···</span>
          </div>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div className="breadcrumb"><span>SGA</span><span className="breadcrumb-slash">/</span><strong>{active.label}</strong></div>
          <label className="module-search">
            <span aria-hidden="true">⌕</span>
            <input
              aria-label="Filtrar módulos"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Filtrar módulos"
              type="search"
              value={search}
            />
            <kbd>/</kbd>
          </label>
          <span className="demo-badge"><span /> DATOS DE MUESTRA</span>
        </header>

        {activeModule === "overview" ? (
          <div className="page-content">
            <section className="welcome-band">
              <div>
                <p className="eyebrow">LUNES · VISTA GENERAL</p>
                <h1>El día, en perspectiva.</h1>
                <p className="welcome-subtitle">Un vistazo a la actividad académica de la institución.</p>
              </div>
              <div className="welcome-aside"><span className="welcome-symbol">S</span><span>PERÍODO ACADÉMICO<br /><strong>2.º cuatrimestre · 2026</strong></span></div>
            </section>

            <section className="metrics-grid" aria-label="Indicadores académicos de muestra">
              {metrics.map((metric) => (
                <article className={`metric metric-${metric.tone}`} key={metric.label}>
                  <p>{metric.label}</p><strong>{metric.value}</strong><span>{metric.change}</span>
                </article>
              ))}
            </section>

            <div className="dashboard-columns">
              <section className="schedule-panel">
                <div className="section-heading"><div><p className="eyebrow">AGENDA</p><h2>Actividad de hoy</h2></div><span className="date-label">LUN · 28 SEP</span></div>
                <div className="schedule-list">
                  {schedule.map((item) => (
                    <article className="schedule-row" key={item.time}>
                      <time>{item.time}</time>
                      <span className="schedule-line" aria-hidden="true" />
                      <div className="schedule-detail"><strong>{item.title}</strong><span>{item.meta}</span></div>
                      <span className={`schedule-tag ${item.tag === "En curso" ? "tag-current" : ""}`}>{item.tag}</span>
                    </article>
                  ))}
                </div>
                <a className="text-action" href="/aulas">Explorar aulas y horarios <span aria-hidden="true">→</span></a>
              </section>

              <aside className="attention-panel">
                <p className="eyebrow">PARA REVISAR</p>
                <h2>Atención académica</h2>
                <div className="attention-item"><span className="attention-count">06</span><span><strong>Legajos incompletos</strong><small>Documentación pendiente</small></span><span className="attention-arrow">↗</span></div>
                <div className="attention-item"><span className="attention-count count-coral">03</span><span><strong>Pagos por conciliar</strong><small>Órdenes pendientes</small></span><span className="attention-arrow">↗</span></div>
                <div className="attention-foot">Cifras ilustrativas, no vinculadas a registros reales.</div>
              </aside>
            </div>

            <footer className="page-foot"><span>SGA · SISTEMA DE GESTIÓN ACADÉMICA</span><span>INTERFAZ EN DESARROLLO</span></footer>
          </div>
        ) : (
          <div className="page-content module-content">
            <p className="eyebrow">MÓDULO ACADÉMICO</p>
            <h1>{active.label}</h1>
            <p className="module-intro">{active.detail}. Este espacio forma parte de la estructura inicial del SGA.</p>
            <section className="module-status">
              <span className="status-mark">{active.mark}</span>
              <div><span className="status-label">ESTADO DEL MÓDULO</span><h2>Preparado para conectar</h2><p>La interfaz está en construcción. Los datos reales estarán disponibles al conectar Supabase y definir los permisos de acceso.</p></div>
              <span className="status-pill">SIN DATOS REALES</span>
            </section>
            <section className="scope-section"><p className="eyebrow">ALCANCE PREVISTO</p><h2>Qué incluirá</h2><ul>{(moduleNotes[activeModule] ?? []).map((note) => <li key={note}>{note}</li>)}</ul></section>
            <button className="back-action" onClick={() => setActiveModule("overview")} type="button"><span aria-hidden="true">←</span> Volver al resumen</button>
            <footer className="page-foot"><span>SGA · SISTEMA DE GESTIÓN ACADÉMICA</span><span>INTERFAZ EN DESARROLLO</span></footer>
          </div>
        )}
      </section>
    </main>
  );
}
