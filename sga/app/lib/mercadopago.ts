import { createHmac, timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";

// Integración con Mercado Pago (Checkout Pro) por su API REST, sin SDK.
// Solo se usa desde el servidor: el Access Token nunca llega al navegador.

const API = process.env.MP_API_URL ?? "https://api.mercadopago.com";

export function pagoOnlineConfigurado(): boolean {
  return !!process.env.MP_ACCESS_TOKEN && !!process.env.SUPABASE_SERVICE_ROLE_KEY;
}

async function mp<T>(ruta: string, init?: RequestInit): Promise<T> {
  const respuesta = await fetch(`${API}${ruta}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
      ...init?.headers,
    },
    cache: "no-store",
  });
  if (!respuesta.ok) throw new Error(`Mercado Pago respondió ${respuesta.status}: ${await respuesta.text()}`);
  return respuesta.json() as Promise<T>;
}

type Preferencia = { id: string; init_point: string; sandbox_init_point?: string };

// Crea la preferencia de pago de una orden. Las URLs de vuelta y el aviso
// (webhook) solo se mandan si la app está en https, porque Mercado Pago
// no acepta localhost para eso.
export async function crearPreferencia(p: { ordenId: number; titulo: string; monto: number; origen: string; email?: string }) {
  const https = p.origen.startsWith("https://");
  const vuelta = `${p.origen}/legajo/estado-de-cuenta/pago?orden=${p.ordenId}`;
  const preferencia = await mp<Preferencia>("/checkout/preferences", {
    method: "POST",
    headers: { "X-Idempotency-Key": `orden-${p.ordenId}` },
    body: JSON.stringify({
      items: [{ id: `orden-${p.ordenId}`, title: p.titulo, quantity: 1, unit_price: p.monto, currency_id: "ARS" }],
      external_reference: String(p.ordenId),
      back_urls: { success: vuelta, pending: vuelta, failure: vuelta },
      ...(https ? { auto_return: "approved", notification_url: `${p.origen}/api/mercadopago/webhook` } : {}),
      ...(p.email ? { payer: { email: p.email } } : {}),
      statement_descriptor: "ITBA SGA",
      expires: true,
      expiration_date_to: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    }),
  });
  // Con credenciales de prueba "TEST-..." se usa el link del sandbox
  const url = process.env.MP_ACCESS_TOKEN?.startsWith("TEST-") && preferencia.sandbox_init_point
    ? preferencia.sandbox_init_point
    : preferencia.init_point;
  return { id: preferencia.id, url };
}

type Pago = { id: number; status: string; status_detail?: string; external_reference: string | null; transaction_amount: number };

// Consulta el pago en Mercado Pago y lo registra en la base. Es la única
// fuente de verdad: no se confía en lo que diga la URL de vuelta ni el
// cuerpo del webhook. Devuelve el estado de Mercado Pago y el de la orden.
export async function confirmarPago(paymentId: string) {
  if (!/^\d+$/.test(paymentId)) throw new Error("Id de pago inválido");
  const pago = await mp<Pago>(`/v1/payments/${paymentId}`);
  const ordenId = Number(pago.external_reference);
  if (!Number.isInteger(ordenId) || ordenId <= 0) return { estadoMp: pago.status, estadoOrden: "DESCONOCIDA", ordenId: null };

  const { data, error } = await createAdminClient().schema("sga").rpc("registrar_pago_mp", {
    p_orden_pago_id: ordenId,
    p_payment_id: String(pago.id),
    p_estado_mp: pago.status,
    p_monto: pago.transaction_amount,
    p_payload: { id: pago.id, status: pago.status, status_detail: pago.status_detail ?? null, transaction_amount: pago.transaction_amount },
  });
  if (error) throw new Error(error.message);
  return { estadoMp: pago.status, estadoOrden: String(data), ordenId };
}

// Valida la firma x-signature del webhook (si está configurada la clave
// secreta en MP_WEBHOOK_SECRET). Ver "Validar origen de la notificación"
// en la documentación de Mercado Pago.
export function firmaValida(firma: string | null, requestId: string | null, dataId: string): boolean {
  const secreto = process.env.MP_WEBHOOK_SECRET;
  if (!secreto) return true;
  if (!firma) return false;
  const partes = Object.fromEntries(firma.split(",").map((p) => p.trim().split("=") as [string, string]));
  if (!partes.ts || !partes.v1) return false;
  const manifiesto = `id:${dataId.toLowerCase()};${requestId ? `request-id:${requestId};` : ""}ts:${partes.ts};`;
  const esperada = createHmac("sha256", secreto).update(manifiesto).digest("hex");
  const a = Buffer.from(esperada);
  const b = Buffer.from(partes.v1);
  return a.length === b.length && timingSafeEqual(a, b);
}
