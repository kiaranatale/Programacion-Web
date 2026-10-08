import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { fecha, getLegajoActual, pesos } from "@/lib/legajo";
import { estadosPlan, type Plan } from "@/lib/planes";
import { cancelarPlan, solicitarPlan } from "./actions";

type Vencida = { id: number; periodo: string; monto_total: number; fecha_vencimiento: string };

// Planes de pago: pagar las facturas vencidas en cuotas.
export default async function PlanesDePago({ searchParams }: PageProps<"/legajo/planes-de-pago">) {
  const { ok, error } = await searchParams;
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  if (legajo) await sga.rpc("asegurar_mi_factura");
  const [{ data: vencidasData }, { data: planesData }] = await Promise.all([
    sga.from("factura").select("id, periodo, monto_total, fecha_vencimiento").eq("legajo_id", legajo?.id ?? 0).eq("estado", "VENCIDA")
      .order("periodo").returns<Vencida[]>(),
    sga.rpc("planes_de_pago", { p_solo_mios: true }),
  ]);
  const vencidas = vencidasData ?? [];
  const planes = (planesData ?? []) as Plan[];
  const deuda = vencidas.reduce((t, f) => t + Number(f.monto_total), 0);
  const esperando = planes.some((p) => p.estado === "SOLICITADO");

  return (
    <>
      <h3 className="sga-subtitulo">Planes de pago</h3>
      <p className="sga-texto">
        Si tenés facturas vencidas, podés pedir pagarlas en 2 a 6 cuotas. Si Administración lo aprueba, esas facturas se
        reemplazan por las cuotas, que vencen el día 10 de los meses siguientes y se pagan desde el estado de cuenta.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      {vencidas.length === 0 ? (
        <p className="sga-vacio-grande">No tenés facturas vencidas.</p>
      ) : (
        <>
          <p className="sga-texto">
            Deuda vencida: <strong>{pesos(deuda)}</strong> ({vencidas.map((f) => `${f.periodo}, venció el ${fecha(f.fecha_vencimiento)}`).join("; ")})
          </p>
          {esperando ? (
            <p className="sga-ayuda">Ya tenés un pedido esperando respuesta.</p>
          ) : (
            <form action={solicitarPlan} className="sga-form-publicacion">
              <label>
                <span>Cantidad de cuotas</span>
                <select defaultValue="3" name="cuotas">
                  {[2, 3, 4, 5, 6].map((n) => <option key={n} value={n}>{n} cuotas de {pesos(Math.round((deuda / n) * 100) / 100)}</option>)}
                </select>
              </label>
              <label>
                <span>Motivo (opcional)</span>
                <textarea maxLength={1000} name="motivo" rows={3} />
              </label>
              <div className="sga-acciones-form"><button type="submit">Pedir plan de pago</button></div>
            </form>
          )}
        </>
      )}

      <h3 className="sga-subtitulo">Mis pedidos</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>N.º</th><th>Pedido</th><th>Facturas</th><th>Cuotas</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {planes.length > 0 ? planes.map((p) => (
              <tr key={p.id}>
                <td>{p.id}</td>
                <td>{fechaHora(p.fecha_solicitud)}</td>
                <td>{p.facturas}</td>
                <td>
                  {p.cuotas} de {pesos(Number(p.monto_total) / p.cuotas)}
                  {p.estado === "APROBADO" && <div className="sga-ayuda">{p.cuotas_pagas} de {p.cuotas} pagas</div>}
                </td>
                <td>
                  <span className={`sga-estado-encuesta ${estadosPlan[p.estado]?.clase ?? ""}`}>{estadosPlan[p.estado]?.texto ?? p.estado}</span>
                  {p.observaciones && <div className="sga-ayuda">{p.observaciones}</div>}
                </td>
                <td className="sga-acciones-doc">
                  {p.estado === "SOLICITADO" && (
                    <form action={cancelarPlan}>
                      <input name="id" type="hidden" value={p.id} />
                      <button className="sga-boton-peligro" type="submit">Cancelar</button>
                    </form>
                  )}
                  {p.estado === "APROBADO" && <Link href="/legajo/estado-de-cuenta">Pagar cuotas</Link>}
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={6}>No pediste planes de pago.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
