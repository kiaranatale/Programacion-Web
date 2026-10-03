"use client";

import Link from "next/link";
import { useActionState } from "react";
import { crearEncuesta, type EstadoNueva } from "../actions";

const FILAS = 8;
const inicial: EstadoNueva = { error: null, valores: {} };

export default function FormularioEncuesta({ hoy }: { hoy: string }) {
  const [estado, accion, enviando] = useActionState(crearEncuesta, inicial);
  const v = estado.valores;

  return (
    <form action={accion} className="sga-form-publicacion" key={JSON.stringify(v)}>
      {estado.error && <p className="sga-mensaje-error" role="alert">{estado.error}</p>}
      <label><span>Nombre</span><input defaultValue={v.nombre} maxLength={150} name="nombre" required /></label>
      <label>
        <span>Descripción (opcional)</span>
        <textarea defaultValue={v.descripcion} name="descripcion" rows={3} />
      </label>
      <fieldset className="sga-fieldset-fechas">
        <legend>Período en que se puede responder</legend>
        <label><span>Desde</span><input defaultValue={v.desde ?? hoy} name="desde" required type="date" /></label>
        <label><span>Hasta</span><input defaultValue={v.hasta} name="hasta" required type="date" /></label>
      </fieldset>
      <fieldset className="sga-preguntas">
        <legend>Preguntas (las vacías se ignoran)</legend>
        {Array.from({ length: FILAS }, (_, i) => (
          <div key={i}>
            <span>{i + 1}.</span>
            <input aria-label={`Pregunta ${i + 1}`} defaultValue={v[`texto_${i}`]} maxLength={300} name={`texto_${i}`} />
            <select aria-label={`Tipo de la pregunta ${i + 1}`} defaultValue={v[`tipo_${i}`] ?? "ESCALA"} name={`tipo_${i}`}>
              <option value="ESCALA">Escala 1 a 5</option>
              <option value="TEXTO">Texto libre</option>
            </select>
          </div>
        ))}
      </fieldset>
      <p className="sga-ayuda">La responden todos los alumnos con legajo. Las respuestas son anónimas.</p>
      <div className="sga-acciones-form">
        <button disabled={enviando} type="submit">{enviando ? "Creando…" : "Crear encuesta"}</button>
        <Link href="/encuestas">Cancelar</Link>
      </div>
    </form>
  );
}
