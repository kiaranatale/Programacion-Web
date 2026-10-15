"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, type MouseEvent } from "react";
import LogoSga from "@/components/logo-sga";
import { logout } from "@/app/auth/actions";

export type ItemNav = { label: string; href?: string };
export type GrupoNav = { label: string; items: ItemNav[] };

// Íconos de trazo simple (24×24) para cada grupo del menú.
const iconos: Record<string, string> = {
  Inicio: "M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
  Encuestas: "M9 4h6v3H9zM7 5H5v16h14V5h-2M8 12h8M8 16h5",
  Académica: "M2 9l10-5 10 5-10 5zM6 11v5c0 1.5 2.7 3 6 3s6-1.5 6-3v-5M22 9v6",
  Legajos: "M4 4h16v16H4zM9 10a2 2 0 1 0 0-.01M6.5 16c.5-2 4.5-2 5 0M14 9h3M14 13h3",
  Docencia: "M3 4h18v12H3zM8 20h8M12 16v4M7 9h6M7 12h4",
  Administración: "M4 7h16v13H4zM9 7V4h6v3M4 12h16",
  Usuario: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c1-4 4-6 8-6s7 2 8 6",
};

function Icono({ nombre }: { nombre: string }) {
  return (
    <svg aria-hidden="true" className="sga-nav-icono" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" viewBox="0 0 24 24">
      <path d={iconos[nombre] ?? iconos.Inicio} />
    </svg>
  );
}

const nombresRol: Record<string, string> = {
  ALUMNO: "Alumno",
  DOCENTE: "Docente",
  AYUDANTE: "Ayudante",
  ADMINISTRATIVO: "Administración",
};

const activo = (pathname: string, href: string) =>
  href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);

// Menú lateral: grupos desplegables (abierto el de la pantalla actual) y,
// abajo, el usuario con el botón para salir. En el celular es un cajón que
// se abre desde la barra superior.
export default function Navegacion({ grupos, nombre, roles }: { grupos: GrupoNav[]; nombre: string; roles: string[] }) {
  const pathname = usePathname();
  const todos = [...grupos, { label: "Usuario", items: [{ label: "Cambio de clave", href: "/usuario/clave" }, { label: "Mensajes", href: "/usuario/mensajes" }] }];
  const grupoActual = todos.find((g) => g.items.some((i) => i.href && activo(pathname, i.href)))?.label;
  // Grupos que el usuario abrió o cerró a mano, respecto de lo que se ve por
  // defecto (abierto solo el grupo de la pantalla actual).
  const [alternados, setAlternados] = useState<Set<string>>(() => new Set());
  const [cajon, setCajon] = useState(false);
  const abierto = (label: string) => (label === grupoActual) !== alternados.has(label);
  const alternar = (label: string) =>
    setAlternados((a) => {
      const nuevo = new Set(a);
      if (!nuevo.delete(label)) nuevo.add(label);
      return nuevo;
    });
  // Al elegir una pantalla en el celular se cierra el cajón
  const cerrarSiEsLink = (e: MouseEvent) => {
    if ((e.target as HTMLElement).closest("a")) setCajon(false);
  };

  const iniciales = nombre.split(/[\s,]+/).filter(Boolean).slice(0, 2).map((p) => p[0]?.toUpperCase()).join("");

  return (
    <>
      <header className="sga-topbar">
        <button aria-expanded={cajon} aria-label="Abrir menú" className="sga-topbar-menu" onClick={() => setCajon(true)} type="button">
          <svg aria-hidden="true" fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth="2" viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
        </button>
        <Link className="sga-topbar-marca" href="/">
          <LogoSga size={30} />
          <span>SGA</span>
        </Link>
      </header>

      {cajon && <div aria-hidden="true" className="sga-sidebar-fondo" onClick={() => setCajon(false)} />}

      <aside className={`sga-sidebar ${cajon ? "is-abierto" : ""}`} onClick={cerrarSiEsLink}>
        <div className="sga-sidebar-marca">
          <Link href="/">
            <LogoSga size={40} />
            <span>Sistema de<br />Gestión Académica</span>
          </Link>
          <button aria-label="Cerrar menú" className="sga-sidebar-cerrar" onClick={() => setCajon(false)} type="button">×</button>
        </div>

        <nav aria-label="Menú principal" className="sga-nav">
          <Link aria-current={pathname === "/" ? "page" : undefined} className="sga-nav-link" href="/">
            <Icono nombre="Inicio" />Inicio
          </Link>
          {todos.map((grupo) => {
            return (
              <div className={`sga-nav-menu ${abierto(grupo.label) ? "is-abierto" : ""} ${grupo.label === grupoActual ? "is-actual" : ""}`} key={grupo.label}>
                <button aria-expanded={abierto(grupo.label)} onClick={() => alternar(grupo.label)} type="button">
                  <Icono nombre={grupo.label} />
                  {grupo.label}
                  <svg aria-hidden="true" className="sga-nav-flecha" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="m9 6 6 6-6 6" /></svg>
                </button>
                <ul>
                  {grupo.items.map((item) => (
                    <li key={item.label}>
                      {item.href ? (
                        <Link aria-current={activo(pathname, item.href) ? "page" : undefined} href={item.href}>{item.label}</Link>
                      ) : (
                        <span title="Próximamente">{item.label}</span>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </nav>

        <div className="sga-sidebar-usuario">
          <span aria-hidden="true" className="sga-avatar">{iniciales || "?"}</span>
          <div>
            <strong>{nombre}</strong>
            <small>{roles.map((r) => nombresRol[r] ?? r).join(" · ")}</small>
          </div>
          <form action={logout}>
            <button className="sga-salir" title="Cerrar sesión" type="submit">Salir</button>
          </form>
        </div>
      </aside>
    </>
  );
}
