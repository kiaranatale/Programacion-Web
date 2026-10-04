import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual, pesos } from "@/lib/legajo";

type Factura = { id: number; periodo: string; monto_total: number; fecha_emision: string; fecha_vencimiento: string; estado: string };
type Pago = { id: number; monto_total: number; fecha_pago: string | null; estado: string };
type Movimiento = { key: string; tipo: "Factura" | "Pago"; importe: number; fecha: string; detalle: string; facturaId?: number; aPagar?: boolean };

const estadosFactura: Record<string, string> = { PENDIENTE: "Pendiente", PAGADA: "Pagada", VENCIDA: "Vencida", ANULADA: "Anulada" };

export default async function EstadoDeCuenta() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: facturas }, { data: pagos }] = await Promise.all([
    sga.from("factura").select("id, periodo, monto_total, fecha_emision, fecha_vencimiento, estado")
      .eq("legajo_id", legajo?.id ?? 0).neq("estado", "ANULADA").returns<Factura[]>(),
    sga.from("orden_pago").select("id, monto_total, fecha_pago, estado")
      .eq("legajo_id", legajo?.id ?? 0).eq("estado", "PAGADO").returns<Pago[]>(),
  ]);

  // Factura suma deuda, pago la descuenta (se muestra en negativo)
  const movimientos: Movimiento[] = [
    ...(facturas ?? []).map((f) => ({
      key: `f${f.id}`, tipo: "Factura" as const, importe: Number(f.monto_total), fecha: f.fecha_emision,
      detalle: `Período ${f.periodo} · Vence ${fecha(f.fecha_vencimiento)} · ${estadosFactura[f.estado] ?? f.estado}`,
      facturaId: f.id, aPagar: f.estado === "PENDIENTE" || f.estado === "VENCIDA",
    })),
    ...(pagos ?? []).map((p) => ({
      key: `p${p.id}`, tipo: "Pago" as const, importe: -Number(p.monto_total), fecha: p.fecha_pago ?? "",
      detalle: "Mercado Pago",
    })),
  ].sort((a, b) => b.fecha.localeCompare(a.fecha));

  const saldo = movimientos.reduce((s, m) => s + m.importe, 0);

  return (
    <>
      <h3 className="sga-subtitulo">Estado de cuenta</h3>
      <div className="sga-saldo">
        <span>Saldo actual</span>
        <strong className={saldo > 0 ? "sga-deuda" : "sga-al-dia"}>{pesos(saldo)}</strong>
      </div>
      {movimientos.length === 0 && <p className="sga-vacio">No hay movimientos.</p>}
      <div className="sga-movimientos">
        {movimientos.map((m) => (
          <article className="sga-movimiento" key={m.key}>
            <h4 className={m.tipo === "Pago" ? "sga-al-dia" : "sga-deuda"}>{m.tipo}</h4>
            <dl>
              <div><dt>Importe:</dt><dd>{pesos(m.importe)}</dd></div>
              <div><dt>{m.tipo === "Pago" ? "Fecha de pago:" : "Fecha de emisión:"}</dt><dd>{fecha(m.fecha)}</dd></div>
              <div><dt>Detalle:</dt><dd>{m.detalle}</dd></div>
            </dl>
            {m.facturaId && (
              <p className="sga-movimiento-acciones">
                <Link href={`/legajo/estado-de-cuenta/factura/${m.facturaId}`}>{m.aPagar ? "Ver detalle y pagar" : "Ver detalle"}</Link>
              </p>
            )}
          </article>
        ))}
      </div>
    </>
  );
}
