import { LARGO_MINIMO, esRecuperacionReciente } from "@/lib/clave";
import { cambiarClave } from "./actions";

export default async function CambioDeClave({ searchParams }: PageProps<"/usuario/clave">) {
  const { ok, error } = await searchParams;
  const recuperacion = await esRecuperacionReciente();

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Cambio de clave</h2>
      {ok && <p className="sga-mensaje-ok" role="status">Tu contraseña se cambió correctamente.</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}
      {recuperacion && !ok && (
        <p className="sga-texto">Ingresaste con el link de recuperación: elegí tu contraseña nueva.</p>
      )}

      <form action={cambiarClave} className="sga-form-publicacion sga-form-clave">
        {!recuperacion && (
          <label>
            <span>Contraseña actual</span>
            <input autoComplete="current-password" name="actual" required type="password" />
          </label>
        )}
        <label>
          <span>Contraseña nueva</span>
          <input autoComplete="new-password" minLength={LARGO_MINIMO} name="nueva" required type="password" />
        </label>
        <label>
          <span>Repetí la contraseña nueva</span>
          <input autoComplete="new-password" minLength={LARGO_MINIMO} name="repetida" required type="password" />
        </label>
        <p className="sga-ayuda">Al menos {LARGO_MINIMO} caracteres. Conviene combinar letras, números y símbolos.</p>
        <div className="sga-acciones-form"><button type="submit">Cambiar contraseña</button></div>
      </form>
    </section>
  );
}
