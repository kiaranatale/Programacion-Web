import Link from "next/link";
import { redirect } from "next/navigation";
import LogoSga from "@/components/logo-sga";
import { logout } from "@/app/auth/actions";
import { getSesion, type Rol } from "@/lib/sesion";

type ItemMenu = { label: string; href?: string };
type Menu = { label: string; items: ItemMenu[]; roles?: Rol[] };

// Los ítems sin href son módulos todavía no implementados.
const menus: Menu[] = [
  {
    label: "Académica",
    items: [{ label: "Aulas", href: "/aulas" }, { label: "Cursos" }, { label: "Exámenes finales" }],
  },
  {
    label: "Legajos",
    roles: ["ALUMNO"],
    items: [{ label: "Mi legajo" }, { label: "Facturación" }],
  },
  {
    label: "Docencia",
    roles: ["DOCENTE", "AYUDANTE"],
    items: [{ label: "Mis comisiones" }, { label: "Carga de notas" }],
  },
  {
    label: "Administración",
    roles: ["ADMINISTRATIVO"],
    items: [{ label: "Legajos" }, { label: "Docentes" }, { label: "Facturación" }],
  },
];

export default async function SgaLayout({ children }: LayoutProps<"/">) {
  const sesion = await getSesion();
  if (!sesion) redirect("/login");

  const nombre = sesion.persona
    ? `${sesion.persona.apellido}, ${sesion.persona.nombre}`
    : sesion.email;
  const visibles = menus.filter(
    (m) => !m.roles || m.roles.some((r) => sesion.roles.includes(r)),
  );

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
            <li><span title="Próximamente">Mis datos</span></li>
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
