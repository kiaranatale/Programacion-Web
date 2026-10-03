import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { puedeEnviar, type Enviado } from "@/lib/mensajes";
import { getSesion } from "@/lib/sesion";
import Bandeja from "../bandeja";

export default async function Enviados() {
  const sesion = await getSesion();
  if (!sesion) return null;

  const supabase = await createClient();
  const { data: mensajes } = await supabase
    .schema("sga")
    .from("mensaje_enviado")
    .select("id, asunto, fecha, destino_descripcion, destinatarios, leidos")
    .order("fecha", { ascending: false })
    .limit(100)
    .returns<Enviado[]>();

  return (
    <Bandeja nuevo={puedeEnviar(sesion)}>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Para</th><th>Asunto</th><th>Leído por</th><th>Fecha</th></tr></thead>
          <tbody>
            {mensajes && mensajes.length > 0 ? mensajes.map((m) => (
              <tr key={m.id}>
                <td>{m.destino_descripcion}</td>
                <td><Link href={`/usuario/mensajes/${m.id}`}>{m.asunto}</Link></td>
                <td className="sga-col-cupo">{m.leidos}/{m.destinatarios}</td>
                <td className="sga-col-cupo">{fechaHora(m.fecha)}</td>
              </tr>
            )) : (
              <tr><td className="sga-vacio" colSpan={4}>No enviaste mensajes.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </Bandeja>
  );
}
