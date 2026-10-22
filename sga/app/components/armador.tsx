"use client";

import Link from "next/link";
import { useMemo, useState, type CSSProperties } from "react";
import {
  armar, DIAS, hora, llena, preferenciasVacias,
  type Bloque, type MateriaArmador, type Opcion, type Preferencias,
} from "@/lib/armador";
import { interpretar } from "@/lib/armador-texto";

const EJEMPLOS = [
  "Quiero los viernes libres y no entrar antes de las 10",
  "Solo puedo de lunes a jueves, sin huecos entre clases",
  "Hacer 4 materias en 3 días, nada después de las 18",
];
const HORAS = Array.from({ length: 17 }, (_, i) => (i + 7) * 60); // 07:00 a 23:00
const ESTADOS: Record<MateriaArmador["estado"], string> = {
  DISPONIBLE: "", CORRELATIVAS: "Faltan correlativas", CURSANDO: "Cursando", CURSADA: "Cursada aprobada", APROBADA: "Aprobada",
};
const MAX_SIN_ELEGIR = 6;

const cursable = (m: MateriaArmador) => m.estado === "DISPONIBLE" && m.comisiones.length > 0;
const textoBloque = (b: Bloque) =>
  `${DIAS[b.dia]} ${hora(b.desde)} a ${hora(b.hasta)}${b.modalidad === "VIRTUAL_ASINCRONICO" ? " (virtual asincrónica)" : b.modalidad === "VIRTUAL_SINCRONICO" ? " (virtual)" : b.lugar ? ` · ${b.lugar}` : ""}`;

// Grilla semanal de una opción: un color por materia
function Grilla({ opcion }: { opcion: Opcion }) {
  const bloques = opcion.elecciones.flatMap((e, color) =>
    e.comision.bloques.map((b) => ({ ...b, color, codigo: e.materia.codigo, materia: e.materia.nombre, comision: e.comision.nombre })));
  const enGrilla = bloques.filter((b) => b.modalidad !== "VIRTUAL_ASINCRONICO");
  const asincronicos = bloques.filter((b) => b.modalidad === "VIRTUAL_ASINCRONICO");
  const dias = [0, 1, 2, 3, 4, ...(enGrilla.some((b) => b.dia === 5) ? [5] : []), ...(enGrilla.some((b) => b.dia === 6) ? [6] : [])];
  const inicio = Math.min(8 * 60, ...enGrilla.map((b) => Math.floor(b.desde / 60) * 60));
  const fin = Math.max(inicio + 6 * 60, ...enGrilla.map((b) => Math.ceil(b.hasta / 60) * 60));
  const escala = 0.9; // px por minuto
  const horas = Array.from({ length: (fin - inicio) / 60 + 1 }, (_, i) => inicio + i * 60);

  return (
    <>
      <div className="sga-semana-scroll">
        <div className="sga-semana" style={{ "--dias": dias.length, "--alto": `${(fin - inicio) * escala}px`, "--hora": `${60 * escala}px` } as CSSProperties}>
          <div className="sga-semana-horas" aria-hidden="true">
            {horas.map((h) => <span key={h} style={{ top: (h - inicio) * escala }}>{hora(h)}</span>)}
          </div>
          {dias.map((d) => (
            <div className="sga-semana-dia" key={d}>
              <div className="sga-semana-nombre">{DIAS[d]}</div>
              <div className="sga-semana-cuerpo">
                {enGrilla.filter((b) => b.dia === d).map((b, i) => (
                  <div
                    className={`sga-semana-bloque sga-color-${b.color % 8}`}
                    key={i}
                    style={{ top: (b.desde - inicio) * escala, height: (b.hasta - b.desde) * escala }}
                    title={`${b.codigo} ${b.materia} · Comisión ${b.comision} · ${textoBloque(b)}`}
                  >
                    <strong>{b.codigo}</strong>
                    <span>{b.materia}</span>
                    <small>{hora(b.desde)}–{hora(b.hasta)} · {b.comision}{b.modalidad === "VIRTUAL_SINCRONICO" ? " · virtual" : ""}</small>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
      {asincronicos.length > 0 && (
        <p className="sga-ayuda">
          Virtual asincrónica (sin horario fijo): {asincronicos.map((b) => `${b.codigo} ${DIAS[b.dia].toLowerCase()} ${hora(b.desde)}`).join(" · ")}
        </p>
      )}
    </>
  );
}

// Armador de horarios: el pedido en castellano se traduce a preferencias
// (que después se pueden ajustar a mano) y se muestran las mejores
// combinaciones de comisiones, una por vez, en una grilla semanal.
export default function Armador({ materias, conLegajo, inscripcionAbierta }: {
  materias: MateriaArmador[];
  conLegajo: boolean;
  inscripcionAbierta: boolean;
}) {
  const [pedido, setPedido] = useState("");
  const [entendido, setEntendido] = useState<string[] | null>(null);
  const [pref, setPref] = useState<Preferencias>(preferenciasVacias);
  const [seleccion, setSeleccion] = useState<Set<string>>(() => new Set());
  const [todas, setTodas] = useState(false);
  const [filtro, setFiltro] = useState("");
  const [nav, setNav] = useState({ clave: "", indice: 0 });

  const ofrecidas = materias.filter((m) => m.comisiones.length > 0);
  // Sin materias elegidas se prueba con todas las que puede cursar
  const sinElegir = seleccion.size === 0;
  const { aArmar, prefFinal, resultado } = useMemo(() => {
    const conComisiones = materias.filter((m) => m.comisiones.length > 0);
    const aArmar = seleccion.size === 0 ? conComisiones.filter(cursable) : conComisiones.filter((m) => seleccion.has(m.codigo));
    const prefFinal = seleccion.size === 0 && pref.maxMaterias === null ? { ...pref, maxMaterias: MAX_SIN_ELEGIR } : pref;
    return { aArmar, prefFinal, resultado: aArmar.length ? armar(aArmar, prefFinal) : null };
  }, [materias, seleccion, pref]);
  const clave = JSON.stringify([aArmar.map((m) => m.codigo), prefFinal]);
  const indice = nav.clave === clave ? nav.indice : 0;
  const opcion = resultado?.opciones[indice];

  const cambiar = (cambios: Partial<Preferencias>) => setPref((p) => ({ ...p, ...cambios }));
  const alternar = (codigo: string) => setSeleccion((s) => {
    const nueva = new Set(s);
    if (!nueva.delete(codigo)) nueva.add(codigo);
    return nueva;
  });
  const alternarDia = (d: number) => cambiar({ diasLibres: pref.diasLibres.includes(d) ? pref.diasLibres.filter((x) => x !== d) : [...pref.diasLibres, d] });

  const entender = (texto: string) => {
    const r = interpretar(texto, ofrecidas);
    setEntendido(r.entendido);
    setPref((p) => ({ ...p, ...r.preferencias }));
    if (r.preferencias.incluir?.length || r.preferencias.excluir?.length) {
      setSeleccion((s) => {
        const nueva = new Set(s);
        r.preferencias.incluir?.forEach((c) => nueva.add(c));
        r.preferencias.excluir?.forEach((c) => nueva.delete(c));
        return nueva;
      });
    }
  };

  const grupos = new Map<string, MateriaArmador[]>();
  const f = filtro.trim().toLowerCase();
  for (const m of materias) {
    if (!todas && (m.estado !== "DISPONIBLE" || m.comisiones.length === 0) && !seleccion.has(m.codigo)) continue;
    if (f && !`${m.codigo} ${m.nombre}`.toLowerCase().includes(f)) continue;
    const g = m.anio ? `${m.anio}.º año` : "Electivas y otras";
    grupos.set(g, [...(grupos.get(g) ?? []), m]);
  }

  return (
    <div className="sga-armador">
      <div className="sga-armador-panel">
        <form className="sga-armador-pedido" onSubmit={(e) => { e.preventDefault(); entender(pedido); }}>
          <label htmlFor="pedido">Contale al armador qué querés</label>
          <textarea
            id="pedido"
            onChange={(e) => setPedido(e.target.value)}
            placeholder="Ej.: quiero los viernes libres, no entrar antes de las 10 y cursar Álgebra Lineal"
            rows={3}
            value={pedido}
          />
          <div className="sga-armador-ejemplos">
            {EJEMPLOS.map((e) => (
              <button key={e} onClick={() => { setPedido(e); entender(e); }} type="button">{e}</button>
            ))}
          </div>
          <button className="sga-boton" type="submit">Armar horarios</button>
          {entendido && (
            entendido.length ? (
              <ul className="sga-armador-entendido" aria-label="Lo que entendí">
                {entendido.map((t) => <li key={t}>{t}</li>)}
              </ul>
            ) : <p className="sga-ayuda">No encontré preferencias en el pedido. Probá con días, horarios o nombres de materias, o usá los ajustes de abajo.</p>
          )}
        </form>

        <details className="sga-armador-ajustes" open>
          <summary>Ajustes</summary>
          <fieldset>
            <legend>Días libres</legend>
            <div className="sga-armador-dias">
              {DIAS.slice(0, 6).map((d, i) => (
                <button aria-pressed={pref.diasLibres.includes(i)} key={d} onClick={() => alternarDia(i)} type="button">{d.slice(0, 2)}</button>
              ))}
            </div>
          </fieldset>
          <div className="sga-armador-horas">
            <label>
              <span>Entrar desde</span>
              <select onChange={(e) => cambiar({ desde: e.target.value ? Number(e.target.value) : null })} value={pref.desde ?? ""}>
                <option value="">Cualquier hora</option>
                {HORAS.map((h) => <option key={h} value={h}>{hora(h)}</option>)}
              </select>
            </label>
            <label>
              <span>Salir hasta</span>
              <select onChange={(e) => cambiar({ hasta: e.target.value ? Number(e.target.value) : null })} value={pref.hasta ?? ""}>
                <option value="">Cualquier hora</option>
                {HORAS.map((h) => <option key={h} value={h}>{hora(h)}</option>)}
              </select>
            </label>
            <label>
              <span>Máx. materias</span>
              <select onChange={(e) => cambiar({ maxMaterias: e.target.value ? Number(e.target.value) : null })} value={pref.maxMaterias ?? ""}>
                <option value="">Todas</option>
                {[1, 2, 3, 4, 5, 6, 7, 8].map((n) => <option key={n} value={n}>{n}</option>)}
              </select>
            </label>
            <label>
              <span>Máx. días</span>
              <select onChange={(e) => cambiar({ maxDias: e.target.value ? Number(e.target.value) : null })} value={pref.maxDias ?? ""}>
                <option value="">Sin límite</option>
                {[1, 2, 3, 4, 5].map((n) => <option key={n} value={n}>{n}</option>)}
              </select>
            </label>
          </div>
          <div className="sga-armador-casillas">
            <label><input checked={pref.sinHuecos} onChange={(e) => cambiar({ sinHuecos: e.target.checked })} type="checkbox" /> Sin huecos entre clases</label>
            <label><input checked={pref.pocosDias} onChange={(e) => cambiar({ pocosDias: e.target.checked })} type="checkbox" /> La menor cantidad de días</label>
            <label><input checked={pref.soloPresencial} onChange={(e) => cambiar({ soloPresencial: e.target.checked })} type="checkbox" /> Sin clases virtuales</label>
            <label><input checked={pref.evitarLlenas} onChange={(e) => cambiar({ evitarLlenas: e.target.checked })} type="checkbox" /> Evitar comisiones llenas</label>
          </div>
          <button className="sga-armador-limpiar" onClick={() => { setPref(preferenciasVacias); setEntendido(null); }} type="button">Borrar preferencias</button>
        </details>

        <div className="sga-armador-materias">
          <div className="sga-armador-materias-encabezado">
            <h3>Materias {seleccion.size > 0 && <span className="sga-ayuda">({seleccion.size} elegidas)</span>}</h3>
            {seleccion.size > 0 && <button onClick={() => setSeleccion(new Set())} type="button">Ninguna</button>}
          </div>
          <input aria-label="Buscar materia" onChange={(e) => setFiltro(e.target.value)} placeholder="Buscar por código o nombre" value={filtro} />
          <label className="sga-armador-todas">
            <input checked={todas} onChange={(e) => setTodas(e.target.checked)} type="checkbox" />
            {conLegajo ? " Mostrar también las que no se dictan, ya cursé o no puedo cursar" : " Mostrar también las que no se dictan"}
          </label>
          {[...grupos.entries()].map(([grupo, lista]) => (
            <div key={grupo}>
              <h4>{grupo}</h4>
              <ul>
                {lista.map((m) => {
                  const deshabilitada = m.comisiones.length === 0 || (!todas && m.estado !== "DISPONIBLE");
                  return (
                    <li className={deshabilitada ? "is-deshabilitada" : undefined} key={m.codigo}>
                      <label>
                        <input checked={seleccion.has(m.codigo)} disabled={deshabilitada && !seleccion.has(m.codigo)} onChange={() => alternar(m.codigo)} type="checkbox" />
                        <span><strong>{m.codigo}</strong> {m.nombre}</span>
                      </label>
                      <small>
                        {m.comisiones.length === 0 ? "No se dicta" : `${m.comisiones.length} ${m.comisiones.length === 1 ? "comisión" : "comisiones"}`}
                        {m.estado !== "DISPONIBLE" && ` · ${ESTADOS[m.estado]}${m.faltan ? `: ${m.faltan}` : ""}`}
                      </small>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
          {ofrecidas.length === 0 && <p className="sga-vacio">Ninguna materia de este plan tiene comisiones cargadas en este cuatrimestre.</p>}
        </div>
      </div>

      <div className="sga-armador-resultado">
        {sinElegir && aArmar.length > 0 && (
          <p className="sga-banner">
            No elegiste materias: pruebo con las {aArmar.length} que podés cursar{pref.maxMaterias === null ? `, hasta ${MAX_SIN_ELEGIR} a la vez` : ""}. Elegí las que quieras en la lista o nombralas en el pedido.
          </p>
        )}
        {!resultado && <p className="sga-vacio-grande">Elegí materias para armar el horario.</p>}
        {resultado && !opcion && (
          <p className="sga-vacio-grande">No hay ninguna combinación posible con estas preferencias. Probá aflojando alguna.</p>
        )}
        {resultado && opcion && (
          <>
            <div className="sga-armador-navegacion">
              <button aria-label="Opción anterior" disabled={indice === 0} onClick={() => setNav({ clave, indice: indice - 1 })} type="button">‹</button>
              <strong>Opción {indice + 1} de {resultado.opciones.length}</strong>
              <button aria-label="Opción siguiente" disabled={indice >= resultado.opciones.length - 1} onClick={() => setNav({ clave, indice: indice + 1 })} type="button">›</button>
              <ul className="sga-armador-resumen">
                <li>{opcion.elecciones.length} {opcion.elecciones.length === 1 ? "materia" : "materias"}</li>
                <li>{opcion.dias} {opcion.dias === 1 ? "día" : "días"}</li>
                <li>{opcion.huecos ? `${Math.round((opcion.huecos / 60) * 10) / 10} h de huecos` : "Sin huecos"}</li>
                {opcion.creditos > 0 && <li>{opcion.creditos} créditos</li>}
                {opcion.llenas > 0 && <li className="is-alerta">{opcion.llenas} {opcion.llenas === 1 ? "comisión llena" : "comisiones llenas"}</li>}
              </ul>
            </div>
            <Grilla opcion={opcion} />
            <div className="sga-tabla-scroll">
              <table className="sga-tabla">
                <thead><tr><th>Materia</th><th>Comisión</th><th>Horarios</th><th>Inscriptos</th></tr></thead>
                <tbody>
                  {opcion.elecciones.map((e, i) => (
                    <tr key={e.comision.id}>
                      <td><span className={`sga-armador-color sga-color-${i % 8}`} aria-hidden="true" /><strong>{e.materia.codigo}</strong> {e.materia.nombre}</td>
                      <td className="sga-col-cupo"><strong>{e.comision.nombre}</strong></td>
                      <td className="sga-horarios">{e.comision.bloques.map((b, j) => <div key={j}>{textoBloque(b)}</div>)}</td>
                      <td className="sga-col-cupo">
                        {e.comision.inscriptos === null ? "—" : `${e.comision.inscriptos} / ${e.comision.cupo ?? "∞"}`}
                        {llena(e.comision) && <div><span className="sga-estado-encuesta sga-estado-rechazado-chip">Llena</span></div>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {opcion.afuera.length > 0 && (
              <p className="sga-ayuda">
                No entraron en esta opción: {opcion.afuera.map((m) => `${m.codigo} ${m.nombre}`).join(", ")}
                {prefFinal.maxMaterias !== null && opcion.elecciones.length >= prefFinal.maxMaterias ? " (llegaste al máximo de materias)." : " (se superponen con lo elegido)."}
              </p>
            )}
          </>
        )}
        {resultado && resultado.descartadas.length > 0 && (
          <details className="sga-detalles">
            <summary>Materias que no pude meter ({resultado.descartadas.length})</summary>
            <ul className="sga-armador-descartadas">
              {resultado.descartadas.map((d) => <li key={d.materia.codigo}><strong>{d.materia.codigo}</strong> {d.materia.nombre}: {d.motivo}.</li>)}
            </ul>
          </details>
        )}
        {resultado?.incompleto && <p className="sga-ayuda">Hay muchísimas combinaciones: muestro las mejores que encontré. Elegí menos materias para revisarlas todas.</p>}
        {opcion && (
          <p className="sga-texto">
            {inscripcionAbierta
              ? <>¿Te sirve? Anotate en <Link href="/inscripciones/cursadas">Inscripción a cursadas</Link> con estas comisiones.</>
              : "Los cupos son los del SGA al momento de bajar las comisiones: pueden haber cambiado."}
          </p>
        )}
      </div>
    </div>
  );
}
