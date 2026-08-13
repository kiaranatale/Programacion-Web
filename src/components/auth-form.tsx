"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";

type AuthFormProps = { mode: "login" | "register" };

export function AuthForm({ mode }: AuthFormProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    setIsLoading(true);

    const supabase = createClient();
    const result = mode === "login"
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({
          email,
          password,
          options: { data: { full_name: fullName } },
        });

    if (result.error) {
      setMessage(result.error.message);
      setIsLoading(false);
      return;
    }

    if (mode === "register") {
      setMessage("Cuenta creada. Revisá tu correo para confirmar el acceso.");
      setIsLoading(false);
      return;
    }

    if (!result.data.user) {
      setMessage("No se pudo recuperar la sesión. Intentá ingresar nuevamente.");
      setIsLoading(false);
      return;
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", result.data.user.id)
      .single();

    window.location.assign(profile?.role === "profesor" ? "/profesor" : profile?.role === "admin" ? "/admin" : "/alumno");
  }

  return (
    <main className="flex flex-1 items-center justify-center px-6 py-16">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>{mode === "login" ? "Iniciar sesión" : "Crear cuenta"}</CardTitle>
          <CardDescription>
            {mode === "login"
              ? "Ingresá con tu cuenta institucional. Tus permisos se asignan según tu rol."
              : "Las cuentas nuevas se registran como alumno. Administración asigna otros roles."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form className="grid gap-4" onSubmit={handleSubmit}>
            {mode === "register" && (
              <div className="grid gap-2">
                <Label htmlFor="full-name">Nombre completo</Label>
                <Input id="full-name" value={fullName} onChange={(event) => setFullName(event.target.value)} required />
              </div>
            )}
            <div className="grid gap-2">
              <Label htmlFor="email">Correo electrónico</Label>
              <Input id="email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="password">Contraseña</Label>
              <Input id="password" type="password" minLength={6} value={password} onChange={(event) => setPassword(event.target.value)} required />
            </div>
            {message && <p className="text-sm text-destructive">{message}</p>}
            <Button type="submit" disabled={isLoading}>
              {isLoading ? "Procesando..." : mode === "login" ? "Ingresar" : "Registrarme"}
            </Button>
            <p className="text-center text-sm text-muted-foreground">
              {mode === "login" ? "¿Todavía no tenés cuenta?" : "¿Ya tenés una cuenta?"}{" "}
              <Link className="text-primary underline-offset-4 hover:underline" href={mode === "login" ? "/registro" : "/login"}>
                {mode === "login" ? "Crear cuenta" : "Iniciar sesión"}
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}