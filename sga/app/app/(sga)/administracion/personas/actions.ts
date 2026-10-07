"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const LISTA = "/administracion/personas";

function volver(id: number, error: string | null, ok: string): never {
  const pagina = `${LISTA}/${id}`;
  revalidatePath(pagina);
  redirect(`${pagina}?${error ? `error=${encodeURIComponent(error)}` : `ok=${encodeURIComponent(ok)}`}`);
}

// Crea la cuenta de acceso (si no existe) y manda el mail para elegir la
// contraseña: el mismo link de "¿Olvidaste tu contraseña?". Devuelve un
// error para mostrar, o null.
async function enviarAcceso(mail: string): Promise<string | null> {
  let admin;
  try {
    admin = createAdminClient();
  } catch {
    return "Falta configurar SUPABASE_SERVICE_ROLE_KEY en el servidor: no se pudo crear la cuenta.";
  }
  const { error: alta } = await admin.auth.admin.createUser({ email: mail, email_confirm: true });
  if (alta && alta.code !== "email_exists" && !/already/i.test(alta.message)) return `No se pudo crear la cuenta: ${alta.message}`;

  const h = await headers();
  const origen = `${h.get("x-forwarded-proto") ?? "http"}://${h.get("x-forwarded-host") ?? h.get("host")}`;
  const supabase = await createClient();
  const { error } = await supabase.auth.resetPasswordForEmail(mail, { redirectTo: `${origen}/auth/confirm?next=/usuario/clave` });
  return error ? `La cuenta existe, pero no se pudo mandar el mail: ${error.message}` : null;
}

export type EstadoAlta = { error: string | null; valores: Record<string, string> };

const CAMPOS = ["tipo_documento", "nro_documento", "nombre", "apellido", "mail", "genero", "nacionalidad", "fecha_nacimiento", "plan_id", "numero_legajo"];
const ROLES = ["ALUMNO", "DOCENTE", "AYUDANTE", "ADMINISTRATIVO"];

// Con useActionState: si falla, devuelve lo escrito para no vaciar el formulario.
export async function crearPersona(_previo: EstadoAlta, formData: FormData): Promise<EstadoAlta> {
  const valores = Object.fromEntries(CAMPOS.map((k) => [k, String(formData.get(k) ?? "").trim()]));
  const roles = ROLES.filter((r) => formData.get(`rol_${r}`) === "on");
  for (const r of roles) valores[`rol_${r}`] = "on";
  valores.cuenta = formData.get("cuenta") === "on" ? "on" : "";

  const supabase = await createClient();
  const { data: id, error } = await supabase.schema("sga").rpc("crear_persona", {
    p_tipo_documento: valores.tipo_documento || "DNI",
    p_nro_documento: valores.nro_documento,
    p_nombre: valores.nombre,
    p_apellido: valores.apellido,
    p_mail_institucional: valores.mail,
    p_genero: valores.genero || null,
    p_nacionalidad: valores.nacionalidad,
    p_fecha_nacimiento: valores.fecha_nacimiento || null,
    p_roles: roles,
    p_plan_id: Number(valores.plan_id) || null,
    p_numero_legajo: valores.numero_legajo,
  });
  if (error || typeof id !== "number") return { error: error?.message ?? "No se pudo crear la persona.", valores };

  revalidatePath(LISTA);
  if (valores.cuenta) {
    const fallo = await enviarAcceso(valores.mail.toLowerCase());
    if (fallo) volver(id, `Persona creada. ${fallo}`, "");
    volver(id, null, `Persona creada. Le mandamos a ${valores.mail.toLowerCase()} el mail para elegir su contraseña.`);
  }
  volver(id, null, "Persona creada.");
}

export async function mandarAcceso(formData: FormData) {
  const id = Number(formData.get("persona_id"));
  const supabase = await createClient();
  const { data } = await supabase.schema("sga").from("persona").select("mail_institucional").eq("id", id).maybeSingle<{ mail_institucional: string }>();
  if (!data) volver(id, "La persona no existe.", "");
  const fallo = await enviarAcceso(data.mail_institucional);
  volver(id, fallo, `Le mandamos a ${data.mail_institucional} el mail para elegir su contraseña.`);
}

export async function cambiarRol(formData: FormData) {
  const id = Number(formData.get("persona_id"));
  const rol = String(formData.get("rol"));
  const activar = formData.get("activar") === "true";
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc(activar ? "asignar_rol" : "quitar_rol", { p_persona_id: id, p_rol: rol });
  volver(id, error?.message ?? null, activar ? "Rol asignado." : "Rol quitado.");
}

export async function crearLegajo(formData: FormData) {
  const id = Number(formData.get("persona_id"));
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("crear_legajo", {
    p_persona_id: id,
    p_plan_id: Number(formData.get("plan_id")) || 0,
    p_numero_legajo: String(formData.get("numero_legajo") ?? ""),
  });
  volver(id, error?.message ?? null, "Legajo creado.");
}

// La comisión se elige por cuatrimestre, código de materia y nombre.
export async function asignarComision(formData: FormData) {
  const id = Number(formData.get("persona_id"));
  const [anio, periodo = ""] = String(formData.get("cuatrimestre") ?? "").split("|");
  const codigo = String(formData.get("codigo") ?? "").trim();
  const nombre = String(formData.get("comision") ?? "").trim().toUpperCase();
  if (!anio || !codigo || !nombre) volver(id, "Completá cuatrimestre, materia y comisión.", "");
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const { data: comision } = await sga.from("comision")
    .select("id, curso:curso_id!inner(anio, periodo, materia:materia_id!inner(codigo))")
    .eq("nombre", nombre).eq("curso.anio", Number(anio)).eq("curso.periodo", periodo).eq("curso.materia.codigo", codigo)
    .maybeSingle<{ id: number }>();
  if (!comision) volver(id, `No existe la comisión ${nombre} de ${codigo} en ese cuatrimestre.`, "");
  const { error } = await sga.rpc("asignar_docente_comision", { p_persona_id: id, p_comision_id: comision.id });
  volver(id, error?.message ?? null, `Asignado a ${codigo} comisión ${nombre}.`);
}

export async function quitarComision(formData: FormData) {
  const id = Number(formData.get("persona_id"));
  const supabase = await createClient();
  const { error } = await supabase.schema("sga").rpc("quitar_docente_comision", { p_docente_comision_id: Number(formData.get("docente_comision_id")) });
  volver(id, error?.message ?? null, "Comisión quitada.");
}
