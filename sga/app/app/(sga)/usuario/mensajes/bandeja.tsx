import Link from "next/link";
import Tabs from "@/components/tabs";

// Encabezado común de Recibidos y Enviados.
export default function Bandeja({ children, nuevo, ok }: { children: React.ReactNode; nuevo: boolean; ok?: string }) {
  return (
    <section className="sga-panel">
      <div className="sga-hoy-encabezado">
        <h2 className="sga-titulo sga-titulo-grande">Mensajes</h2>
        {nuevo && <Link className="sga-boton" href="/usuario/mensajes/nuevo">+ Nuevo mensaje</Link>}
      </div>
      {ok && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      <div className="sga-tab-box">
        <Tabs tabs={[
          { label: "Recibidos", href: "/usuario/mensajes", exact: true },
          { label: "Enviados", href: "/usuario/mensajes/enviados" },
        ]} />
        <div className="sga-tab-content">{children}</div>
      </div>
    </section>
  );
}
