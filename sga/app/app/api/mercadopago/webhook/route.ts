import { NextResponse, type NextRequest } from "next/server";
import { confirmarPago, firmaValida, pagoOnlineConfigurado } from "@/lib/mercadopago";

// Aviso de Mercado Pago cuando cambia un pago. Solo se toma el id del
// pago: el estado y el monto se consultan a la API de Mercado Pago.
export async function POST(request: NextRequest) {
  if (!pagoOnlineConfigurado()) return NextResponse.json({ ok: false }, { status: 503 });

  const url = request.nextUrl;
  const cuerpo = await request.json().catch(() => ({}));
  const tipo = cuerpo.type ?? url.searchParams.get("type") ?? url.searchParams.get("topic");
  const id = String(cuerpo.data?.id ?? url.searchParams.get("data.id") ?? url.searchParams.get("id") ?? "");

  // Otros avisos (merchant_order, etc.) no hacen falta
  if (tipo !== "payment" || !id) return NextResponse.json({ ok: true });
  if (!firmaValida(request.headers.get("x-signature"), request.headers.get("x-request-id"), url.searchParams.get("data.id") ?? id)) {
    return NextResponse.json({ ok: false }, { status: 401 });
  }

  try {
    await confirmarPago(id);
    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Webhook de Mercado Pago:", error);
    // 500 hace que Mercado Pago reintente más tarde
    return NextResponse.json({ ok: false }, { status: 500 });
  }
}
