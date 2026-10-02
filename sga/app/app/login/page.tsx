import { login } from "./actions";

const mensajes: Record<string, string> = {
  "faltan-datos": "Completá el mail y la contraseña.",
  credenciales: "Mail o contraseña incorrectos.",
};

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const { error } = await searchParams;
  const mensaje = typeof error === "string" ? mensajes[error] : undefined;

  return (
    <main className="login-shell">
      <section className="login-card">
        <div className="brand login-brand">
          <span className="brand-mark">S</span>
          <span className="brand-copy"><strong>SGA</strong><small>ITBA · ACADÉMICO</small></span>
        </div>

        <p className="eyebrow">ACCESO</p>
        <h1>Iniciar sesión</h1>
        <p className="login-intro">Ingresá con tu mail institucional.</p>

        {mensaje && <p className="login-error" role="alert">{mensaje}</p>}

        <form action={login} className="login-form">
          <label>
            <span>Mail institucional</span>
            <input autoComplete="email" name="email" placeholder="nombre@itba.edu.ar" required type="email" />
          </label>
          <label>
            <span>Contraseña</span>
            <input autoComplete="current-password" name="password" required type="password" />
          </label>
          <button type="submit">Ingresar</button>
        </form>
      </section>
    </main>
  );
}
