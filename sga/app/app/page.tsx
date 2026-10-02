import Dashboard, { type Usuario } from "./dashboard";
import { createClient } from "@/lib/supabase/server";

type PersonaRow = {
  nombre: string;
  apellido: string;
  persona_rol: { rol: string; activo: boolean }[];
};

const rolesLegibles: Record<string, string> = {
  ALUMNO: "Alumno",
  DOCENTE: "Docente",
  AYUDANTE: "Ayudante",
  ADMINISTRATIVO: "Administración",
};

// Server Component: lee la persona vinculada al usuario logueado (RLS solo
// deja ver la propia) y le pasa los datos al dashboard interactivo.
export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: persona } = await supabase
    .schema("sga")
    .from("persona")
    .select("nombre, apellido, persona_rol(rol, activo)")
    .eq("auth_user_id", user?.id ?? "")
    .maybeSingle<PersonaRow>();

  const usuario: Usuario = persona
    ? {
        nombre: `${persona.nombre} ${persona.apellido}`,
        rol:
          persona.persona_rol
            .filter((r) => r.activo)
            .map((r) => rolesLegibles[r.rol] ?? r.rol)
            .join(" · ") || "Sin rol asignado",
        iniciales: `${persona.nombre[0] ?? ""}${persona.apellido[0] ?? ""}`.toUpperCase(),
      }
    : {
        nombre: user?.email ?? "Usuario",
        rol: "Sin persona vinculada",
        iniciales: (user?.email?.[0] ?? "?").toUpperCase(),
      };

  return <Dashboard usuario={usuario} />;
}
