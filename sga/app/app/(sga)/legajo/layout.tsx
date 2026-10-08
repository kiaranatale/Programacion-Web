import Tabs from "@/components/tabs";
import { getLegajoActual } from "@/lib/legajo";

const tabs = [
  { label: "General", href: "/legajo", exact: true },
  { label: "Títulos", href: "/legajo/titulos" },
  { label: "Datos del alumno", href: "/legajo/alumno" },
  { label: "Estado de cuenta", href: "/legajo/estado-de-cuenta" },
  { label: "Planes de pago", href: "/legajo/planes-de-pago" },
  { label: "Proyectos", href: "/legajo/proyectos" },
];

export default async function LegajoLayout({ children }: LayoutProps<"/legajo">) {
  const { legajo, nombre } = await getLegajoActual();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Detalles del legajo de {nombre}</h2>
      {legajo ? (
        <div className="sga-tab-box">
          <Tabs tabs={tabs} />
          <div className="sga-tab-content">{children}</div>
        </div>
      ) : (
        <p className="sga-vacio">No tenés un legajo de alumno asociado a tu usuario.</p>
      )}
    </section>
  );
}
