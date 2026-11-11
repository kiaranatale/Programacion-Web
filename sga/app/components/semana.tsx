import type { CSSProperties } from "react";
import { DIAS, hora, type Modalidad } from "@/lib/armador";

// Un bloque de clase: dia 0 = lunes; desde/hasta en minutos; color = índice
// de la paleta (una por materia).
export type BloqueSemana = {
  dia: number;
  desde: number;
  hasta: number;
  modalidad: Modalidad;
  codigo: string;
  materia: string;
  comision: string;
  detalle: string; // para el título (aula, modalidad)
  color: number;
};

// Grilla semanal (lunes a viernes, y sábado/domingo si hay clases). Los
// bloques virtuales asincrónicos no tienen horario fijo: van abajo.
export default function Semana({ bloques }: { bloques: BloqueSemana[] }) {
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
                    title={`${b.codigo} ${b.materia} · Comisión ${b.comision} · ${DIAS[b.dia]} ${hora(b.desde)} a ${hora(b.hasta)}${b.detalle ? ` · ${b.detalle}` : ""}`}
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
