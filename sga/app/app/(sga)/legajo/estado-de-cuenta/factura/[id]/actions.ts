"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { crearPreferencia, pagoOnlineConfigurado } from "@/lib/mercadopago";
import { getSesion } from "@/lib/sesion";
import { createClient } from "@/lib/supabase/server";

// Crea la orden de pago (la base verifica que la factura sea del alumno y
// esté impaga), la preferencia en Mercado Pago, y redirige a pagar.
export async function pagarFactura(formData: FormData) {
  const facturaId = Number(formData.get("factura_id"));
  const pagina = `/legajo/estado-de-cuenta/factura/${facturaId}`;
  const conError = (mensaje: string): never => redirect(`${pagina}?error=${encodeURIComponent(mensaje)}`);
  if (!pagoOnlineConfigurado()) return conError("El pago online todavía no está configurado.");

  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data, error } = await sga.rpc("iniciar_pago_factura", { p_factura_id: facturaId });
  const orden = (data as { orden_pago_id: number; monto: number; periodo: string }[] | null)?.[0];
  if (error || !orden) return conError(error?.message ?? "No se pudo iniciar el pago.");

  const h = await headers();
  const origen = `${h.get("x-forwarded-proto") ?? "http"}://${h.get("x-forwarded-host") ?? h.get("host")}`;
  const sesion = await getSesion();
  let url: string;
  try {
    const preferencia = await crearPreferencia({
      ordenId: orden.orden_pago_id,
      titulo: `ITBA - Factura ${orden.periodo}`,
      monto: Number(orden.monto),
      origen,
      email: sesion?.email,
    });
    const { error: errorGuardar } = await sga.rpc("guardar_preferencia_mp", {
      p_orden_pago_id: orden.orden_pago_id,
      p_preference_id: preferencia.id,
      p_checkout_url: preferencia.url,
    });
    if (errorGuardar) throw new Error(errorGuardar.message);
    url = preferencia.url;
  } catch (e) {
    console.error("Mercado Pago:", e);
    return conError("No se pudo conectar con Mercado Pago. Probá de nuevo en unos minutos.");
  }
  redirect(url!);
}
