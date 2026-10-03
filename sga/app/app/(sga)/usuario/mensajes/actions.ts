"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Las funciones de la base deciden a quién puede escribirle cada uno; acá
// se arma el pedido y se traduce el resultado.

const conError = (url: string, mensaje: string): never => redirect(`${url}?error=${encodeURIComponent(mensaje)}`);

export type EstadoEnvio = { error: string | null; valores: Record<string, string> };

// Con useActionState: ante un error devuelve el mensaje y lo escrito, para
// que el formulario no se vacíe.
export async function enviarMensaje(_previo: EstadoEnvio, formData: FormData): Promise<EstadoEnvio> {
  const valores = Object.fromEntries(["para", "mail", "asunto", "cuerpo"].map((k) => [k, String(formData.get(k) ?? "")]));
  const asunto = valores.asunto.trim();
  const cuerpo = valores.cuerpo.trim();
  const [tipo, id] = valores.para.split(":");
  const mail = valores.mail.trim();
  const fallo = (error: string): EstadoEnvio => ({ error, valores });

  if (!asunto || !cuerpo) return fallo("Completá el asunto y el mensaje.");
  if (asunto.length > 150) return fallo("El asunto puede tener hasta 150 caracteres.");
  if (cuerpo.length > 5000) return fallo("El mensaje puede tener hasta 5000 caracteres.");
  if (!tipo) return fallo("Elegí a quién va el mensaje.");
  if (tipo === "PERSONA" && !mail) return fallo("Escribí el mail de la persona.");

  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("enviar_mensaje", {
    p_asunto: asunto,
    p_cuerpo: cuerpo,
    p_destino_tipo: tipo,
    p_destino_id: id ? Number(id) : null,
    p_mail: tipo === "PERSONA" ? mail : null,
  });
  if (error || typeof data !== "number") return fallo(error?.message ?? "No se pudo enviar el mensaje.");

  redirect(`/usuario/mensajes/${data}?ok=${encodeURIComponent("Mensaje enviado.")}`);
}

export async function responderMensaje(formData: FormData) {
  const mensajeId = Number(formData.get("mensaje_id"));
  const cuerpo = String(formData.get("cuerpo") ?? "").trim();
  const pagina = `/usuario/mensajes/${mensajeId}`;
  if (!cuerpo) conError(pagina, "Escribí la respuesta.");
  if (cuerpo.length > 5000) conError(pagina, "La respuesta puede tener hasta 5000 caracteres.");

  const supabase = await createClient();
  const { data, error } = await supabase.schema("sga").rpc("responder_mensaje", { p_mensaje_id: mensajeId, p_cuerpo: cuerpo });
  if (error || typeof data !== "number") conError(pagina, error?.message ?? "No se pudo enviar la respuesta.");

  redirect(`/usuario/mensajes/${data}?ok=${encodeURIComponent("Respuesta enviada.")}`);
}
