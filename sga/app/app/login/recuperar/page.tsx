import Link from "next/link";
import LogoSga from "@/components/logo-sga";
import { pedirRecuperacion } from "./actions";

export default async function RecuperarClave({ searchParams }: PageProps<"/login/recuperar">) {
  const { enviado } = await searchParams;

  return (
    <main className="login-shell">
      <LogoSga className="login-logo" size={190} />

      <form action={pedirRecuperacion} className="login-form">
        {enviado ? (
          <p className="login-ok" role="status">
            Si el mail corresponde a un usuario del SGA, te llegará un link para elegir una contraseña nueva. Revisá
            también la carpeta de spam.
          </p>
        ) : (
          <p className="login-texto">Ingresá tu mail institucional y te mandamos un link para elegir una contraseña nueva.</p>
        )}
        <label>
          <span>Mail institucional:</span>
          <input autoComplete="email" name="email" required type="email" />
        </label>
        <button type="submit">{enviado ? "Volver a enviar" : "Enviar link"}</button>
        <Link className="login-link" href="/login">← Volver al ingreso</Link>
      </form>
    </main>
  );
}
