import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type Role = "alumno" | "profesor" | "admin";

export async function requireRole(role: Role) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?next=/${role}`);
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profile?.role !== role) {
    redirect(`/${profile?.role ?? "login"}`);
  }

  return { user, role };
}