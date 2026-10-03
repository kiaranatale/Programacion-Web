"use client";

import Link from "next/link";
import { useActionState } from "react";
import { enviarMensaje, type EstadoEnvio } from "../actions";

type Opcion = { valor: string; etiqueta: string };
type Props = { admin: boolean; carreras: Opcion[]; comisiones: Opcion[] };

const inicial: EstadoEnvio = { error: null, valores: {} };

export default function FormularioMensaje({ admin, carreras, comisiones }: Props) {
  const [estado, accion, enviando] = useActionState(enviarMensaje, inicial);
  const v = estado.valores;

  return (
    <form action={accion} className="sga-form-publicacion" key={JSON.stringify(v)}>
      {estado.error && <p className="sga-mensaje-error" role="alert">{estado.error}</p>}
      <label>
        <span>Para</span>
        <select defaultValue={v.para ?? ""} name="para" required>
          <option disabled value="">Elegí a quién va el mensaje</option>
          <option value="PERSONA">Una persona (por mail)</option>
          {admin && <option value="TODOS">Todos los usuarios</option>}
          {carreras.length > 0 && (
            <optgroup label="Alumnos de una carrera">
              {carreras.map((c) => <option key={c.valor} value={c.valor}>{c.etiqueta}</option>)}
            </optgroup>
          )}
          {comisiones.length > 0 && (
            <optgroup label={admin ? "Alumnos de una comisión" : "Alumnos de mis comisiones"}>
              {comisiones.map((c) => <option key={c.valor} value={c.valor}>{c.etiqueta}</option>)}
            </optgroup>
          )}
        </select>
      </label>
      <label>
        <span>Mail de la persona</span>
        <input defaultValue={v.mail} name="mail" placeholder="Solo si elegiste «Una persona»" type="email" />
        {!admin && <span className="sga-ayuda">Podés escribirle a alumnos de tus comisiones, a otros docentes y a Administración.</span>}
      </label>
      <label>
        <span>Asunto</span>
        <input defaultValue={v.asunto} maxLength={150} name="asunto" required />
      </label>
      <label>
        <span>Mensaje</span>
        <textarea defaultValue={v.cuerpo} maxLength={5000} name="cuerpo" required rows={10} />
      </label>
      <div className="sga-acciones-form">
        <button disabled={enviando} type="submit">{enviando ? "Enviando…" : "Enviar"}</button>
        <Link href="/usuario/mensajes">Cancelar</Link>
      </div>
    </form>
  );
}
