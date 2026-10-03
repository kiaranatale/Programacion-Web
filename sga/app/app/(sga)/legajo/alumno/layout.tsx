import Tabs from "@/components/tabs";

const base = "/legajo/alumno";
const tabs = [
  { label: "Roles", href: base, exact: true },
  { label: "Datos familiares", href: `${base}/familiares` },
  { label: "Analítico de notas", href: `${base}/analitico` },
  { label: "Historia académica", href: `${base}/historia` },
  { label: "Calendario semanal", href: `${base}/calendario` },
  { label: "Historial de inhibiciones", href: `${base}/inhibiciones` },
  { label: "Histórico excepciones", href: `${base}/excepciones` },
  { label: "Exámenes habilitados", href: `${base}/examenes` },
  { label: "Documentación", href: `${base}/documentacion` },
  { label: "Facturables", href: `${base}/facturables` },
];

export default function DatosAlumnoLayout({ children }: LayoutProps<"/legajo/alumno">) {
  return (
    <div className="sga-tab-box">
      <Tabs nivel={2} tabs={tabs} />
      <div className="sga-tab-content">{children}</div>
    </div>
  );
}
