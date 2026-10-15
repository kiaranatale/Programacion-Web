import Link from "next/link";
import LogoSga from "@/components/logo-sga";
import { login } from "./actions";

const mensajes: Record<string, string> = {
  "faltan-datos": "Completá el mail y la contraseña.",
  credenciales: "Mail o contraseña incorrectos.",
  link: "El link para recuperar la contraseña venció o ya se usó. Pedí uno nuevo.",
};

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const { error } = await searchParams;
  const mensaje = typeof error === "string" ? mensajes[error] : undefined;

  return (
    <main className="login-shell">
      <LogoSga className="login-logo" size={190} />

      <form action={login} className="login-form">
        <h1>Ingresá al SGA</h1>
        <p>Sistema de Gestión Académica del ITBA</p>
        {mensaje && <p className="login-error" role="alert">{mensaje}</p>}
        <label>
          <span>Mail institucional:</span>
          <input autoComplete="email" name="email" required type="email" />
        </label>
        <label>
          <span>Contraseña:</span>
          <input autoComplete="current-password" name="password" required type="password" />
        </label>
        <button type="submit">Ingresar</button>
        <Link className="login-link" href="/login/recuperar">¿Olvidaste tu contraseña?</Link>
      </form>
    </main>
  );
}
