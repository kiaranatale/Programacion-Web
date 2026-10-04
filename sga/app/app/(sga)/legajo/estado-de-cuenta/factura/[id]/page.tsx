import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { fecha, pesos } from "@/lib/legajo";
import { fechaHora } from "@/lib/hoy";
import { pagoOnlineConfigurado } from "@/lib/mercadopago";
import { pagarFactura } from "./actions";

type Factura = {
  id: number;
  periodo: string;
  creditos_cursados: number;
  valor_credito_aplicado: number;
  monto_creditos: number;
  monto_adicionales: number;
  monto_descuentos: number;
  monto_total: number;
  fecha_emision: string;
  fecha_vencimiento: string;
  estado: string;
  factura_detalle: { id: number; tipo: string; descripcion: string | null; monto: number }[];
  orden_pago_factura: { orden_pago: { id: number; estado: string; estado_mp: string | null; fecha_creacion: string; fecha_pago: string | null; external_payment_id: string | null } | null }[];
};

const estadosFactura: Record<string, string> = { PENDIENTE: "Pendiente", PAGADA: "Pagada", VENCIDA: "Vencida", ANULADA: "Anulada" };
const estadosOrden: Record<string, string> = { PENDIENTE: "Sin completar", PAGADO: "Pagado", EXPIRADO: "Vencido", CANCELADO: "Cancelado" };
const estadosMp: Record<string, string> = { rejected: "Rechazado", in_process: "En proceso", pending: "En proceso", cancelled: "Cancelado" };

// Detalle de una factura del alumno y botón para pagarla con Mercado Pago.
export default async function DetalleFactura({ params, searchParams }: PageProps<"/legajo/estado-de-cuenta/factura/[id]">) {
  const id = Number((await params).id);
  if (!Number.isInteger(id)) notFound();
  const { error } = await searchParams;

  const supabase = await createClient();
  const { data: f } = await supabase
    .schema("sga")
    .from("factura")
    .select(`id, periodo, creditos_cursados, valor_credito_aplicado, monto_creditos, monto_adicionales, monto_descuentos,
      monto_total, fecha_emision, fecha_vencimiento, estado,
      factura_detalle(id, tipo, descripcion, monto),
      orden_pago_factura(orden_pago:orden_pago_id(id, estado, estado_mp, fecha_creacion, fecha_pago, external_payment_id))`)
    .eq("id", id)
    .maybeSingle<Factura>();
  if (!f) notFound();

  // Si no hay renglones cargados, se arma el detalle con los totales
  const renglones = f.factura_detalle.length > 0
    ? f.factura_detalle.map((d) => ({ key: String(d.id), descripcion: d.descripcion ?? d.tipo, monto: Number(d.monto) }))
    : [
        { key: "creditos", descripcion: `${f.creditos_cursados} créditos × ${pesos(Number(f.valor_credito_aplicado))}`, monto: Number(f.monto_creditos) },
        ...(Number(f.monto_adicionales) ? [{ key: "adicionales", descripcion: "Adicionales", monto: Number(f.monto_adicionales) }] : []),
        ...(Number(f.monto_descuentos) ? [{ key: "descuentos", descripcion: "Becas y descuentos", monto: -Number(f.monto_descuentos) }] : []),
      ];
  const ordenes = f.orden_pago_factura.flatMap((o) => (o.orden_pago ? [o.orden_pago] : []))
    .sort((a, b) => b.fecha_creacion.localeCompare(a.fecha_creacion));
  const aPagar = f.estado === "PENDIENTE" || f.estado === "VENCIDA";

  return (
    <>
      <h3 className="sga-subtitulo">Factura {f.periodo}</h3>
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      <dl className="sga-mensaje-datos">
        <div><dt>Estado:</dt><dd><strong className={aPagar ? "sga-deuda" : "sga-al-dia"}>{estadosFactura[f.estado] ?? f.estado}</strong></dd></div>
        <div><dt>Emisión:</dt><dd>{fecha(f.fecha_emision)}</dd></div>
        <div><dt>Vencimiento:</dt><dd>{fecha(f.fecha_vencimiento)}</dd></div>
      </dl>

      <div className="sga-tabla-scroll sga-factura">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Concepto</th><th>Importe</th></tr></thead>
          <tbody>
            {renglones.map((r) => (
              <tr key={r.key}><td>{r.descripcion}</td><td className="sga-importe">{pesos(r.monto)}</td></tr>
            ))}
            <tr className="sga-total"><td>Total</td><td className="sga-importe">{pesos(Number(f.monto_total))}</td></tr>
          </tbody>
        </table>
      </div>

      {aPagar && (
        pagoOnlineConfigurado() ? (
          <form action={pagarFactura} className="sga-pagar">
            <input name="factura_id" type="hidden" value={f.id} />
            <button type="submit">Pagar {pesos(Number(f.monto_total))} con Mercado Pago</button>
            <p className="sga-ayuda">Vas a ir a la página de Mercado Pago y, al terminar, volvés al SGA.</p>
          </form>
        ) : (
          <p className="sga-vacio">El pago online todavía no está configurado.</p>
        )
      )}

      {ordenes.length > 0 && (
        <>
          <h3 className="sga-subtitulo">Intentos de pago</h3>
          <div className="sga-tabla-scroll">
            <table className="sga-tabla sga-tabla-mensajes">
              <thead><tr><th>Iniciado</th><th>Estado</th><th>Pagado</th><th>N.º de operación</th></tr></thead>
              <tbody>
                {ordenes.map((o) => (
                  <tr key={o.id}>
                    <td>{fechaHora(o.fecha_creacion)}</td>
                    <td>{o.estado !== "PAGADO" && o.estado_mp && estadosMp[o.estado_mp] ? estadosMp[o.estado_mp] : estadosOrden[o.estado] ?? o.estado}</td>
                    <td>{o.fecha_pago ? fechaHora(o.fecha_pago) : "—"}</td>
                    <td>{o.external_payment_id ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
      <Link className="sga-volver" href="/legajo/estado-de-cuenta">← Volver al estado de cuenta</Link>
    </>
  );
}
