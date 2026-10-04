import Link from "next/link";
import { confirmarPago, pagoOnlineConfigurado } from "@/lib/mercadopago";
import { createClient } from "@/lib/supabase/server";

type Orden = { id: number; estado: string; orden_pago_factura: { factura_id: number }[] };

// Vuelta desde Mercado Pago. El resultado se confirma consultando el pago
// a Mercado Pago (no se confía en los parámetros de la URL).
export default async function VueltaDePago({ searchParams }: PageProps<"/legajo/estado-de-cuenta/pago">) {
  const params = await searchParams;
  const ordenId = Number(params.orden);
  const paymentId = typeof params.payment_id === "string" ? params.payment_id : typeof params.collection_id === "string" ? params.collection_id : null;

  let estadoMp: string | null = null;
  if (paymentId && paymentId !== "null" && pagoOnlineConfigurado()) {
    try {
      ({ estadoMp } = await confirmarPago(paymentId));
    } catch (e) {
      console.error("Confirmación de pago:", e);
    }
  }

  // La orden se lee con la sesión del alumno: solo ve las suyas
  const supabase = await createClient();
  const { data: orden } = Number.isInteger(ordenId)
    ? await supabase.schema("sga").from("orden_pago").select("id, estado, orden_pago_factura(factura_id)").eq("id", ordenId).maybeSingle<Orden>()
    : { data: null };
  const facturaId = orden?.orden_pago_factura[0]?.factura_id;

  const resultado = orden?.estado === "PAGADO"
    ? { clase: "sga-mensaje-ok", titulo: "¡Pago aprobado!", texto: "La factura quedó pagada. Ya se ve en tu estado de cuenta." }
    : estadoMp === "in_process" || estadoMp === "pending" || params.status === "pending" || params.status === "in_process"
      ? { clase: "sga-mensaje-ok", titulo: "Pago en proceso", texto: "Mercado Pago está procesando el pago. Cuando se acredite, la factura se marca como pagada sola." }
      : { clase: "sga-mensaje-error", titulo: "El pago no se completó", texto: "No se registró ningún cobro. Podés intentarlo de nuevo desde el detalle de la factura." };

  return (
    <>
      <h3 className="sga-subtitulo">Pago con Mercado Pago</h3>
      <div className={resultado.clase} role="status">
        <strong>{resultado.titulo}</strong> {resultado.texto}
      </div>
      <p className="sga-acciones-form">
        {facturaId && <Link href={`/legajo/estado-de-cuenta/factura/${facturaId}`}>Ver la factura</Link>}
        <Link href="/legajo/estado-de-cuenta">Volver al estado de cuenta</Link>
      </p>
    </>
  );
}
