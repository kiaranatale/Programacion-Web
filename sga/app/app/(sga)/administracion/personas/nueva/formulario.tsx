"use client";

import Link from "next/link";
import { useActionState } from "react";
import { ROLES, TIPOS_DOCUMENTO, etiquetaRol } from "@/lib/personas";
import { crearPersona, type EstadoAlta } from "../actions";

type Plan = { id: number; codigo: string; carrera: string };

const inicial: EstadoAlta = { error: null, valores: { tipo_documento: "DNI", cuenta: "on" } };

export default function FormularioAlta({ planes }: { planes: Plan[] }) {
  const [estado, accion, enviando] = useActionState(crearPersona, inicial);
  const v = estado.valores;

  return (
    <form action={accion} className="sga-form-publicacion" key={JSON.stringify(v)}>
      {estado.error && <p className="sga-mensaje-error" role="alert">{estado.error}</p>}
      <fieldset>
        <legend>Datos personales</legend>
        <label><span>Apellido</span><input defaultValue={v.apellido} maxLength={100} name="apellido" required /></label>
        <label><span>Nombre</span><input defaultValue={v.nombre} maxLength={100} name="nombre" required /></label>
        <label>
          <span>Género (opcional)</span>
          <select defaultValue={v.genero ?? ""} name="genero">
            <option value="">Sin indicar</option>
            <option value="MUJER">Femenino</option>
            <option value="HOMBRE">Masculino</option>
            <option value="OTRO">Otro</option>
          </select>
        </label>
      </fieldset>
      <fieldset>
        <legend>Documento</legend>
        <label>
          <span>Tipo</span>
          <select defaultValue={v.tipo_documento ?? "DNI"} name="tipo_documento">
            {Object.entries(TIPOS_DOCUMENTO).map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
          </select>
        </label>
        <label><span>Número</span><input defaultValue={v.nro_documento} maxLength={32} name="nro_documento" required /></label>
        <label><span>Fecha de nacimiento (opcional)</span><input defaultValue={v.fecha_nacimiento} name="fecha_nacimiento" type="date" /></label>
      </fieldset>
      <label>
        <span>Mail institucional</span>
        <input defaultValue={v.mail} name="mail" placeholder="nombre@itba.edu.ar" required type="email" />
        <span className="sga-ayuda">Con este mail entra al SGA.</span>
      </label>
      <label><span>Nacionalidad (opcional)</span><input defaultValue={v.nacionalidad} maxLength={60} name="nacionalidad" /></label>
      <fieldset className="sga-roles">
        <legend>Roles</legend>
        {ROLES.map((r) => (
          <label key={r}><input defaultChecked={v[`rol_${r}`] === "on"} name={`rol_${r}`} type="checkbox" /> {etiquetaRol(r)}</label>
        ))}
      </fieldset>
      <fieldset>
        <legend>Legajo (solo para alumnos)</legend>
        <label>
          <span>Plan de estudio</span>
          <select defaultValue={v.plan_id ?? ""} name="plan_id">
            <option value="">Elegí el plan…</option>
            {planes.map((p) => <option key={p.id} value={p.id}>{p.codigo} · {p.carrera}</option>)}
          </select>
        </label>
        <label><span>Número de legajo</span><input defaultValue={v.numero_legajo} maxLength={20} name="numero_legajo" /></label>
      </fieldset>
      <label className="sga-casilla">
        <input defaultChecked={v.cuenta === "on"} name="cuenta" type="checkbox" />
        <span>Crear la cuenta y mandarle el mail para que elija su contraseña</span>
      </label>
      <div className="sga-acciones-form">
        <button disabled={enviando} type="submit">{enviando ? "Creando…" : "Crear persona"}</button>
        <Link href="/administracion/personas">Cancelar</Link>
      </div>
    </form>
  );
}
