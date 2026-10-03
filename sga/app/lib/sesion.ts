import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

export type Rol = "ALUMNO" | "DOCENTE" | "AYUDANTE" | "ADMINISTRATIVO";

export type Sesion = {
  email: string;
  persona: { id: number; nombre: string; apellido: string } | null;
  roles: Rol[];
};

type PersonaRow = {
  id: number;
  nombre: string;
  apellido: string;
  persona_rol: { rol: Rol; activo: boolean }[];
};

// Usuario logueado + su persona y roles activos. `cache` evita repetir la
// consulta cuando el layout y la página la piden en el mismo request.
export const getSesion = cache(async (): Promise<Sesion | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  // RLS solo deja ver la persona propia (o todas, si es administrativo),
  // por eso se filtra explícitamente por el usuario logueado.
  const { data: persona } = await supabase
    .schema("sga")
    .from("persona")
    .select("id, nombre, apellido, persona_rol(rol, activo)")
    .eq("auth_user_id", user.id)
    .maybeSingle<PersonaRow>();

  return {
    email: user.email ?? "",
    persona: persona
      ? { id: persona.id, nombre: persona.nombre, apellido: persona.apellido }
      : null,
    roles: persona?.persona_rol.filter((r) => r.activo).map((r) => r.rol) ?? [],
  };
});
