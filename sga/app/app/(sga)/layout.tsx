import { redirect } from "next/navigation";
import Navegacion from "@/components/navegacion";
import TablasResponsivas from "@/components/tablas-responsivas";
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
      { label: "Eventos académicos", href: "/inscripciones/eventos" },
    ],
  },
  {
    label: "Legajos",
    roles: ["ALUMNO"],
    items: [
      { label: "Mi legajo", href: "/legajo" },
      { label: "Inscripción a cursadas", href: "/inscripciones/cursadas" },
      { label: "Inscripción a finales", href: "/inscripciones/finales" },
    ],
  },
  {
    label: "Docencia",
    roles: ["DOCENTE", "AYUDANTE"],
    items: [
      { label: "Mis comisiones", href: "/docencia" },
      { label: "Carga de notas", href: "/docencia/notas" },
      { label: "Ausencias", href: "/docencia/ausencias" },
    ],
  },
  {
    label: "Administración",
    items: [
      { label: "Ocupación de Aulas", href: "/aulas" },
      { label: "Personas", href: "/administracion/personas", roles: ["ADMINISTRATIVO"] },
      { label: "Oferta de cursos", href: "/administracion/oferta", roles: ["ADMINISTRATIVO"] },
      { label: "Facturación", href: "/administracion/facturacion", roles: ["ADMINISTRATIVO"] },
      { label: "Planes de pago", href: "/administracion/planes-de-pago", roles: ["ADMINISTRATIVO"] },
      { label: "Documentación pendiente", href: "/administracion/documentacion", roles: ["ADMINISTRATIVO"] },
      { label: "Organizaciones estudiantiles", href: "/administracion/organizaciones", roles: ["ADMINISTRATIVO"] },
      { label: "Inscripción a cursadas", href: "/administracion/inscripciones", roles: ["ADMINISTRATIVO"] },
      { label: "Turnos de examen", href: "/administracion/finales", roles: ["ADMINISTRATIVO"] },
      { label: "Trámites", href: "/administracion/tramites", roles: ["ADMINISTRATIVO"] },
      { label: "Ausencias docentes", href: "/administracion/ausencias", roles: ["ADMINISTRATIVO"] },
      { label: "Intercambios", href: "/administracion/intercambios", roles: ["ADMINISTRATIVO"] },
      { label: "Eventos académicos", href: "/administracion/eventos", roles: ["ADMINISTRATIVO"] },
      { label: "Proyectos de alumnos", href: "/administracion/proyectos", roles: ["ADMINISTRATIVO"] },
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
      <Navegacion grupos={visibles} nombre={nombre} roles={sesion.roles} />
      <main className="sga-main">{children}</main>
      <TablasResponsivas />
    </div>
  );
}
