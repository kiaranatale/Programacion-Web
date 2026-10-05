import Link from "next/link";
import { redirect } from "next/navigation";
import LogoSga from "@/components/logo-sga";
import { logout } from "@/app/auth/actions";
import { getSesion, type Rol } from "@/lib/sesion";

type ItemMenu = { label: string; href?: string; roles?: Rol[] };
type Menu = { label: string; items: ItemMenu[]; roles?: Rol[] };

// Misma estructura de menú que el SGA actual. Los ítems sin href son
// pantallas todavía no implementadas (ver "Pantallas del SGA actual" en
// ROADMAP.md).
const menus: Menu[] = [
  {
    label: "Encuestas",
    items: [{ label: "General", href: "/encuestas" }],
  },
  {
    label: "Académica",
    items: [
      { label: "Autoridades", href: "/autoridades" },
      { label: "Carreras", href: "/carreras" },
      { label: "Cursos", href: "/cursos" },
      { label: "Hoy en el ITBA", href: "/hoy" },
    ],
  },
  {
    label: "Legajos",
    roles: ["ALUMNO"],
    items: [{ label: "Mi legajo", href: "/legajo" }],
  },
  {
    label: "Docencia",
    roles: ["DOCENTE", "AYUDANTE"],
    items: [{ label: "Mis comisiones", href: "/docencia" }, { label: "Carga de notas", href: "/docencia/notas" }],
  },
  {
    label: "Administración",
    items: [
      { label: "Ocupación de Aulas", href: "/aulas" },
      { label: "Documentación pendiente", href: "/administracion/documentacion", roles: ["ADMINISTRATIVO"] },
      { label: "Organizaciones estudiantiles", href: "/administracion/organizaciones", roles: ["ADMINISTRATIVO"] },
    ],
  },
];

export default async function SgaLayout({ children }: LayoutProps<"/">) {
  const sesion = await getSesion();
  if (!sesion) redirect("/login");

  const nombre = sesion.persona
    ? `${sesion.persona.apellido}, ${sesion.persona.nombre}`
    : sesion.email;
  const permitido = (roles?: Rol[]) => !roles || roles.some((r) => sesion.roles.includes(r));
  const visibles = menus
    .filter((m) => permitido(m.roles))
    .map((m) => ({ ...m, items: m.items.filter((i) => permitido(i.roles)) }));

  return (
    <div className="sga-shell">
      <header className="sga-header">
        <Link className="sga-header-brand" href="/">
          <LogoSga size={58} />
          <span className="sga-header-divider" aria-hidden="true" />
          <span className="sga-header-title">Sistema de<br />Gestión Académica</span>
        </Link>
        <div className="sga-header-user">
          <strong>{nombre}</strong>
          <form action={logout}>
            <button type="submit">[Salir]</button>
          </form>
        </div>
      </header>

      <nav className="sga-nav" aria-label="Menú principal">
        <Link href="/">Inicio</Link>
        {visibles.map((menu) => (
          <div className="sga-nav-menu" key={menu.label}>
            <button type="button">{menu.label}<span aria-hidden="true">▾</span></button>
            <ul>
              {menu.items.map((item) => (
                <li key={item.label}>
                  {item.href ? (
                    <Link href={item.href}>{item.label}</Link>
                  ) : (
                    <span title="Próximamente">{item.label}</span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
        <div className="sga-nav-menu">
          <button type="button">Usuario<span aria-hidden="true">▾</span></button>
          <ul>
            <li><Link href="/usuario/clave">Cambio de clave</Link></li>
            <li><Link href="/usuario/mensajes">Mensajes</Link></li>
            <li>
              <form action={logout}>
                <button type="submit">Cerrar sesión</button>
              </form>
            </li>
          </ul>
        </div>
      </nav>

      <main className="sga-main">{children}</main>
    </div>
  );
}
