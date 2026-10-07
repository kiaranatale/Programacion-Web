import { createClient } from "@/lib/supabase/server";
import { hoy } from "@/lib/hoy";
import { fecha, pesos } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";
import { cambiarValorCredito } from "./actions";

type Valor = { id: number; vigente_desde: string; monto: number };
type Factura = {
  id: number;
  periodo: string;
  apellido: string;
  nombre: string;
  numero_legajo: string;
  creditos_cursados: number;
  valor_credito_aplicado: number;
  monto_total: number;
  fecha_vencimiento: string;
  estado: string;
  fecha_pago: string | null;
};

const estados: Record<string, { texto: string; clase: string }> = {
  PENDIENTE: { texto: "Pendiente", clase: "sga-estado-programada" },
  PAGADA: { texto: "Pagada", clase: "sga-estado-activa" },
  VENCIDA: { texto: "Vencida", clase: "sga-estado-rechazado-chip" },
  ANULADA: { texto: "Anulada", clase: "sga-estado-finalizada" },
};

const nombreMes = (periodo: string) => {
  const [a, m] = periodo.split("-").map(Number);
  const texto = new Date(Date.UTC(a, m - 1, 15)).toLocaleDateString("es-AR", { timeZone: "UTC", month: "long", year: "numeric" });
  return texto[0].toUpperCase() + texto.slice(1);
};

// Facturación: Administración solo fija el valor del crédito. Las
// facturas se generan solas cada mes (créditos que cursa cada alumno ×
// valor vigente + adicionales − becas); acá se consultan.
export default async function Facturacion({ searchParams }: PageProps<"/administracion/facturacion">) {
  const params = await searchParams;
  const sesion = await getSesion();
  if (!sesion?.roles.includes("ADMINISTRATIVO")) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Facturación</h2>
        <p className="sga-error">Esta sección es solo para Administración.</p>
      </section>
    );
  }
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  // Por si la pasada diaria todavía no corrió: factura el mes y marca vencidas
  await sga.rpc("actualizar_facturacion");

  const hoyStr = hoy();
  const mesActual = hoyStr.slice(0, 7);
  const periodo = typeof params.periodo === "string" && /^\d{4}-\d{2}$/.test(params.periodo) ? params.periodo : mesActual;
  const estado = typeof params.estado === "string" && params.estado in estados ? params.estado : "";
  const q = typeof params.q === "string" ? params.q.trim() : "";
  const [{ data: valoresData }, { data }, { data: todoElMes }] = await Promise.all([
    sga.from("valor_credito").select("id, vigente_desde, monto").order("vigente_desde", { ascending: false }).returns<Valor[]>(),
    sga.rpc("facturas_para_gestionar", { p_periodo: periodo, p_estado: estado || null, p_texto: q }),
    sga.rpc("facturas_para_gestionar", { p_periodo: periodo, p_estado: null, p_texto: "" }),
  ]);
  const valores = valoresData ?? [];
  const vigente = valores.find((v) => v.vigente_desde <= hoyStr);
  const proximo = valores.find((v) => v.vigente_desde > hoyStr);
  const facturas = (data ?? []) as Factura[];
  const delMes = ((todoElMes ?? []) as Factura[]).filter((f) => f.estado !== "ANULADA");
  const suma = (lista: Factura[]) => lista.reduce((t, f) => t + Number(f.monto_total), 0);
  const cobrado = suma(delMes.filter((f) => f.estado === "PAGADA"));
  const vencido = suma(delMes.filter((f) => f.estado === "VENCIDA"));
  const [a, m] = mesActual.split("-").map(Number);
  const primeroProximoMes = new Date(Date.UTC(a, m, 1)).toISOString().slice(0, 10);
  const meses = Array.from({ length: 12 }, (_, i) => new Date(Date.UTC(a, m - 1 - i, 1)).toISOString().slice(0, 7));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Facturación</h2>
      <p className="sga-texto">
        Las facturas se generan solas cada mes: a cada alumno se le facturan los créditos de las materias que está cursando ×
        el valor del crédito, más sus adicionales y menos sus becas o descuentos. Vencen el día 10. Acá solo se fija el valor
        del crédito.
      </p>
      {typeof params.ok === "string" && <p className="sga-mensaje-ok" role="status">{params.ok}</p>}
      {typeof params.error === "string" && <p className="sga-mensaje-error" role="alert">{params.error}</p>}

      <h3 className="sga-subtitulo">Valor del crédito</h3>
      <p className="sga-texto">
        Vigente: <strong>{vigente ? pesos(vigente.monto) : "sin valor cargado"}</strong>
        {vigente && <> desde el {fecha(vigente.vigente_desde)}</>}
        {proximo && <> · Desde el {fecha(proximo.vigente_desde)}: <strong>{pesos(proximo.monto)}</strong></>}
      </p>
      <form action={cambiarValorCredito} className="sga-form-fecha-final">
        <span className="sga-ayuda">Nuevo valor</span>
        <input aria-label="Nuevo valor del crédito" min={1} name="monto" required step="0.01" type="number" />
        <span className="sga-ayuda">desde el</span>
        <input aria-label="Vigente desde" defaultValue={primeroProximoMes} name="desde" required type="date" />
        <button type="submit">Guardar</button>
      </form>
      <p className="sga-ayuda">Rige desde el primer día de un mes. Las facturas ya emitidas no cambian.</p>
      {valores.length > 1 && (
        <details className="sga-historial-valores">
          <summary>Historial de valores</summary>
          <ul>{valores.map((v) => <li key={v.id}>Desde el {fecha(v.vigente_desde)}: {pesos(v.monto)}</li>)}</ul>
        </details>
      )}

      <h3 className="sga-subtitulo">Facturas de {nombreMes(periodo)}</h3>
      <p className="sga-texto">
        {delMes.length} facturas · {pesos(suma(delMes))} facturado · {pesos(cobrado)} cobrado · {pesos(vencido)} vencido
      </p>
      <form className="sga-hoy-filtros">
        <select aria-label="Mes" defaultValue={periodo} name="periodo">
          {meses.map((p) => <option key={p} value={p}>{nombreMes(p)}</option>)}
        </select>
        <select aria-label="Estado" defaultValue={estado} name="estado">
          <option value="">Todos los estados</option>
          {Object.entries(estados).map(([v, e]) => <option key={v} value={v}>{e.texto}</option>)}
        </select>
        <input aria-label="Buscar alumno" defaultValue={q} name="q" placeholder="Apellido, nombre o legajo" />
        <button type="submit">Ver</button>
      </form>
      <div className="sga-tabla-scroll">
        <table className="sga-tabla sga-tabla-mensajes">
          <thead><tr><th>Alumno</th><th>Legajo</th><th>Créditos</th><th>Total</th><th>Vence</th><th>Estado</th></tr></thead>
          <tbody>
            {facturas.length > 0 ? facturas.map((f) => (
              <tr key={f.id}>
                <td>{f.apellido}, {f.nombre}</td>
                <td>{f.numero_legajo}</td>
                <td>{f.creditos_cursados} × {pesos(f.valor_credito_aplicado)}</td>
                <td className="sga-importe">{pesos(f.monto_total)}</td>
                <td>{fecha(f.fecha_vencimiento)}</td>
                <td>
                  <span className={`sga-estado-encuesta ${estados[f.estado]?.clase ?? ""}`}>{estados[f.estado]?.texto ?? f.estado}</span>
                  {f.fecha_pago && <div className="sga-ayuda">el {fecha(f.fecha_pago.slice(0, 10))}</div>}
                </td>
              </tr>
            )) : <tr><td className="sga-vacio" colSpan={6}>No hay facturas para mostrar.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
