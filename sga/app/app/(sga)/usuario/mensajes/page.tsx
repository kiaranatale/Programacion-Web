import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { puedeEnviar, type Recibido } from "@/lib/mensajes";
import { getSesion } from "@/lib/sesion";
import Bandeja from "./bandeja";

export default async function Recibidos({ searchParams }: PageProps<"/usuario/mensajes">) {
  const sesion = await getSesion();
  if (!sesion) return null;
  const { ok } = await searchParams;

  const supabase = await createClient();
  const { data: mensajes } = await supabase
    .schema("sga")
    .from("mensaje_recibido")
    .select("id, asunto, fecha, remitente_apellido, remitente_nombre, leido_en, destino_descripcion")
    .order("fecha", { ascending: false })
    .limit(100)
    .returns<Recibido[]>();
  const sinLeer = (mensajes ?? []).filter((m) => !m.leido_en).length;

  return (
    <Bandeja nuevo={puedeEnviar(sesion)} ok={typeof ok === "string" ? ok : undefined}>
      <p className="sga-texto">{sinLeer === 0 ? "No tenés mensajes sin leer." : sinLeer === 1 ? "Tenés 1 mensaje sin leer." : `Tenés ${sinLeer} mensajes sin leer.`}</p>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>De</th><th>Asunto</th><th>Enviado a</th><th>Fecha</th></tr></thead>
          <tbody>
            {mensajes && mensajes.length > 0 ? mensajes.map((m) => (
              <tr className={m.leido_en ? undefined : "sga-no-leido"} key={m.id}>
                <td>{m.remitente_apellido}, {m.remitente_nombre}</td>
                <td><Link href={`/usuario/mensajes/${m.id}`}>{m.asunto}</Link></td>
                <td className="sga-ayuda">{m.destino_descripcion}</td>
                <td className="sga-col-cupo">{fechaHora(m.fecha)}</td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={4}>No recibiste mensajes.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </Bandeja>
  );
}
