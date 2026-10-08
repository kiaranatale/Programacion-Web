import { createClient } from "@/lib/supabase/server";
import { fechaHora } from "@/lib/hoy";
import { pesos } from "@/lib/legajo";
import { estadosPlan, type Plan } from "@/lib/planes";
import { getSesion } from "@/lib/sesion";
import { resolverPlan } from "./actions";

// Pedidos de planes de pago: aprobar (crea las cuotas) o rechazar.
export default async function PlanesDePagoAdmin({ searchParams }: PageProps<"/administracion/planes-de-pago">) {
  const { ok, error } = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Planes de pago</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").rpc("planes_de_pago", { p_solo_mios: false });
  const planes = (data ?? []) as Plan[];
  const pendientes = planes.filter((p) => p.estado === "SOLICITADO");
  const resto = planes.filter((p) => p.estado !== "SOLICITADO").slice(0, 50);

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Planes de pago</h2>
      <p className="sga-texto">
        Pedidos de alumnos para pagar sus facturas vencidas en cuotas. Al aprobar, las facturas se anulan y se crean las cuotas
        (vencen el 10 de los meses siguientes).
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <h3 className="sga-subtitulo">Pedidos ({pendientes.length})</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Alumno</th><th>Facturas</th><th>Deuda</th><th>Cuotas</th><th>Motivo</th><th>Acciones</th></tr></thead>
          <tbody>
            {pendientes.length > 0 ? pendientes.map((p) => (
              <tr key={p.id}>
                <td>{p.apellido}, {p.nombre}<div className="sga-ayuda">{p.numero_legajo} · {fechaHora(p.fecha_solicitud)}</div></td>
                <td>{p.facturas}</td>
                <td className="sga-importe">{pesos(p.monto_total)}</td>
                <td>{p.cuotas} de {pesos(Number(p.monto_total) / p.cuotas)}</td>
                <td>{p.motivo ?? "—"}</td>
                <td className="sga-acciones-doc">
                  <form action={resolverPlan}>
                    <input name="id" type="hidden" value={p.id} />
                    <button name="decision" type="submit" value="aprobar">Aprobar</button>
                  </form>
                  <form action={resolverPlan}>
                    <input name="id" type="hidden" value={p.id} />
                    <input aria-label="Motivo del rechazo" name="observaciones" placeholder="Motivo del rechazo" required />
                    <button className="sga-boton-peligro" name="decision" type="submit" value="rechazar">Rechazar</button>
                  </form>
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={6}>No hay pedidos esperando respuesta.</td></tr>}
          </tbody>
        </table>
      </div>

      <h3 className="sga-subtitulo">Resueltos</h3>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>N.º</th><th>Alumno</th><th>Deuda</th><th>Cuotas</th><th>Estado</th></tr></thead>
          <tbody>
            {resto.length > 0 ? resto.map((p) => (
              <tr key={p.id}>
                <td>{p.id}</td>
                <td>{p.apellido}, {p.nombre}<div className="sga-ayuda">{p.numero_legajo}</div></td>
                <td className="sga-importe">{pesos(p.monto_total)}</td>
                <td>{p.cuotas}{p.estado === "APROBADO" && <div className="sga-ayuda">{p.cuotas_pagas} pagas</div>}</td>
                <td>
                  <span className={`sga-estado-encuesta ${estadosPlan[p.estado]?.clase ?? ""}`}>{estadosPlan[p.estado]?.texto ?? p.estado}</span>
                  {p.observaciones && <div className="sga-ayuda">{p.observaciones}</div>}
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={5}>Todavía no hay.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
