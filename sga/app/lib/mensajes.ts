import type { Sesion } from "@/lib/sesion";

export type Recibido = {
  id: number;
  asunto: string;
  cuerpo: string;
  fecha: string;
  destino_descripcion: string;
  respuesta_a_id: number | null;
  remitente_apellido: string;
  remitente_nombre: string;
  leido_en: string | null;
};

export type Enviado = {
  id: number;
  asunto: string;
  cuerpo: string;
  fecha: string;
  destino_descripcion: string;
  respuesta_a_id: number | null;
  destinatarios: number;
  leidos: number;
};

// Docentes y Administración inician mensajes; el resto solo responde.
export function puedeEnviar(sesion: Sesion): boolean {
  return sesion.roles.some((r) => r === "DOCENTE" || r === "AYUDANTE" || r === "ADMINISTRATIVO");
}
