// Armador de horarios: dadas las materias que alguien quiere cursar y sus
// preferencias (días libres, horarios, cantidad de materias...), busca las
// combinaciones de comisiones sin superposiciones y las ordena de la más
// conveniente a la menos. Funciones puras: corren en el navegador.

export type Modalidad = "PRESENCIAL" | "VIRTUAL_SINCRONICO" | "VIRTUAL_ASINCRONICO";
// dia: 0 = lunes ... 6 = domingo. desde/hasta: minutos desde las 00:00.
export type Bloque = { dia: number; desde: number; hasta: number; modalidad: Modalidad; lugar: string };
export type ComisionArmador = { id: number; nombre: string; cupo: number | null; inscriptos: number | null; bloques: Bloque[] };
export type EstadoMateria = "DISPONIBLE" | "CORRELATIVAS" | "CURSANDO" | "CURSADA" | "APROBADA";
export type MateriaArmador = {
  codigo: string;
  nombre: string;
  creditos: number | null;
  anio: number | null;
  cuatrimestre: number | null;
  estado: EstadoMateria;
  faltan: string | null; // correlativas que faltan
  comisiones: ComisionArmador[];
};

export type Preferencias = {
  diasLibres: number[];
  desde: number | null; // no entrar antes de
  hasta: number | null; // no salir después de
  maxMaterias: number | null;
  maxDias: number | null;
  pocosDias: boolean;
  sinHuecos: boolean;
  soloPresencial: boolean;
  evitarLlenas: boolean;
  incluir: string[]; // códigos que sí o sí
  excluir: string[]; // códigos que no
};

export const preferenciasVacias: Preferencias = {
  diasLibres: [], desde: null, hasta: null, maxMaterias: null, maxDias: null,
  pocosDias: false, sinHuecos: false, soloPresencial: false, evitarLlenas: false, incluir: [], excluir: [],
};

export type Eleccion = { materia: MateriaArmador; comision: ComisionArmador };
export type Opcion = {
  elecciones: Eleccion[];
  obligatorias: number; // cuántas de las que pidió sí o sí entraron
  afuera: MateriaArmador[];
  dias: number;
  huecos: number; // minutos libres entre clases del mismo día
  llenas: number;
  creditos: number;
  puntaje: number;
};
export type Resultado = {
  opciones: Opcion[];
  descartadas: { materia: MateriaArmador; motivo: string }[]; // ninguna comisión cumple las preferencias
  incompleto: boolean; // se cortó la búsqueda por tamaño
};

export const DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
export const DIA_DE: Record<string, number> = {
  LUNES: 0, MARTES: 1, MIERCOLES: 2, JUEVES: 3, VIERNES: 4, SABADO: 5, DOMINGO: 6,
};

export const minutos = (hhmm: string) => {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + (m || 0);
};
export const hora = (min: number) => `${String(Math.floor(min / 60)).padStart(2, "0")}:${String(min % 60).padStart(2, "0")}`;

// Los bloques virtuales asincrónicos no ocupan un horario: no se superponen
// ni cuentan como día de cursada.
const ocupa = (b: Bloque) => b.modalidad !== "VIRTUAL_ASINCRONICO";
const seSuperponen = (a: Bloque, b: Bloque) => a.dia === b.dia && a.desde < b.hasta && b.desde < a.hasta;
export const llena = (c: ComisionArmador) => c.cupo !== null && c.inscriptos !== null && c.inscriptos >= c.cupo;

// Por qué una comisión no sirve con estas preferencias (null: sirve).
export function motivoComision(c: ComisionArmador, p: Preferencias): string | null {
  const bloques = c.bloques.filter(ocupa);
  if (c.bloques.length === 0) return "no tiene horarios cargados";
  if (bloques.some((b) => p.diasLibres.includes(b.dia))) return "cae en un día que querés libre";
  if (p.desde !== null && bloques.some((b) => b.desde < p.desde!)) return `empieza antes de las ${hora(p.desde)}`;
  if (p.hasta !== null && bloques.some((b) => b.hasta > p.hasta!)) return `termina después de las ${hora(p.hasta)}`;
  if (p.soloPresencial && c.bloques.some((b) => b.modalidad === "VIRTUAL_SINCRONICO")) return "tiene clases virtuales";
  if (p.evitarLlenas && llena(c)) return "está llena";
  return null;
}

function evaluar(elecciones: Eleccion[], p: Preferencias) {
  const porDia = new Map<number, Bloque[]>();
  for (const e of elecciones) for (const b of e.comision.bloques.filter(ocupa)) porDia.set(b.dia, [...(porDia.get(b.dia) ?? []), b]);
  let huecos = 0;
  for (const bloques of porDia.values()) {
    bloques.sort((a, b) => a.desde - b.desde);
    let fin = bloques[0].hasta;
    for (const b of bloques.slice(1)) {
      if (b.desde > fin) huecos += b.desde - fin;
      fin = Math.max(fin, b.hasta);
    }
  }
  const dias = porDia.size;
  const llenas = elecciones.filter((e) => llena(e.comision)).length;
  const puntaje = dias * (p.pocosDias ? 400 : 120) + huecos * (p.sinHuecos ? 4 : 1) + llenas * 150;
  return { dias, huecos, llenas, puntaje };
}

// "cae en un día..." → "caen en un día..." (para "Sus 3 comisiones ...")
const PLURALES: Record<string, string> = {
  cae: "caen", empieza: "empiezan", termina: "terminan", tiene: "tienen", "está llena": "están llenas", "no tiene": "no tienen",
};
const plural = (motivo: string) => {
  const inicio = Object.keys(PLURALES).sort((a, b) => b.length - a.length).find((k) => motivo.startsWith(k));
  return inicio ? PLURALES[inicio] + motivo.slice(inicio.length) : motivo;
};

const MAX_OPCIONES = 12;
const MAX_PASOS = 400_000;

// Busca combinaciones: una comisión por materia, sin superposiciones. Si no
// entran todas, prefiere las que meten las pedidas sí o sí y después las
// que meten más materias; a igualdad, menor puntaje (días, huecos,
// comisiones llenas).
const mejor = (a: Opcion, b: Opcion) =>
  b.obligatorias - a.obligatorias || b.elecciones.length - a.elecciones.length || a.puntaje - b.puntaje;

export function armar(materias: MateriaArmador[], p: Preferencias): Resultado {
  const descartadas: Resultado["descartadas"] = [];
  const candidatas: { materia: MateriaArmador; comisiones: ComisionArmador[] }[] = [];
  for (const materia of materias) {
    if (p.excluir.includes(materia.codigo)) continue;
    const motivos = materia.comisiones.map((c) => motivoComision(c, p));
    const sirven = materia.comisiones.filter((_, i) => motivos[i] === null);
    if (sirven.length) candidatas.push({ materia, comisiones: sirven });
    else {
      const distintos = [...new Set(motivos)];
      const motivo = materia.comisiones.length === 0
        ? "No tiene comisiones este cuatrimestre"
        : materia.comisiones.length === 1
          ? `Su única comisión ${motivos[0]}`
          : distintos.length === 1
            ? `Sus ${materia.comisiones.length} comisiones ${plural(distintos[0]!)}`
            : `Ninguna comisión sirve (${materia.comisiones.map((c, i) => `${c.nombre}: ${motivos[i]}`).join("; ")})`;
      descartadas.push({ materia, motivo });
    }
  }
  // Primero las obligatorias y las de menos comisiones: poda antes
  candidatas.sort((a, b) =>
    Number(p.incluir.includes(b.materia.codigo)) - Number(p.incluir.includes(a.materia.codigo))
    || a.comisiones.length - b.comisiones.length);

  const tope = Math.min(p.maxMaterias ?? candidatas.length, candidatas.length);
  const esObligatoria = (m: MateriaArmador) => p.incluir.includes(m.codigo);
  const obligatorias = candidatas.filter((c) => esObligatoria(c.materia)).length;
  const mejores: Opcion[] = [];
  const vistas = new Set<string>();
  let pasos = 0;
  const elegidas: Eleccion[] = [];
  const ocupados: Bloque[] = [];

  const peorAceptable = () => (mejores.length < MAX_OPCIONES ? null : mejores[mejores.length - 1]);
  const guardar = () => {
    const clave = elegidas.map((e) => e.comision.id).sort((a, b) => a - b).join(",");
    if (vistas.has(clave)) return;
    const ev = evaluar(elegidas, p);
    if (p.maxDias !== null && ev.dias > p.maxDias) return;
    vistas.add(clave);
    const opcion: Opcion = {
      elecciones: [...elegidas].sort((a, b) => a.materia.codigo.localeCompare(b.materia.codigo)),
      obligatorias: elegidas.filter((e) => esObligatoria(e.materia)).length,
      afuera: candidatas.map((c) => c.materia).filter((m) => !elegidas.some((e) => e.materia === m)),
      creditos: elegidas.reduce((s, e) => s + (e.materia.creditos ?? 0), 0),
      ...ev,
    };
    mejores.push(opcion);
    mejores.sort(mejor);
    if (mejores.length > MAX_OPCIONES) mejores.pop();
  };

  const buscar = (i: number) => {
    if (++pasos > MAX_PASOS) return;
    // Poda: aunque entren todas las que quedan, no supera a la peor guardada
    const peor = peorAceptable();
    if (peor) {
      const oblPosibles = elegidas.filter((e) => esObligatoria(e.materia)).length + Math.max(obligatorias - i, 0);
      const maxPosibles = Math.min(elegidas.length + candidatas.length - i, tope);
      if (oblPosibles < peor.obligatorias || (oblPosibles === peor.obligatorias && maxPosibles < peor.elecciones.length)) return;
    }
    if (elegidas.length === tope || i === candidatas.length) {
      if (elegidas.length > 0) guardar();
      return;
    }
    const { materia, comisiones } = candidatas[i];
    for (const comision of comisiones) {
      const bloques = comision.bloques.filter(ocupa);
      if (bloques.some((b) => ocupados.some((o) => seSuperponen(b, o)))) continue;
      elegidas.push({ materia, comision });
      ocupados.push(...bloques);
      buscar(i + 1);
      ocupados.splice(ocupados.length - bloques.length, bloques.length);
      elegidas.pop();
    }
    buscar(i + 1); // sin esta materia
  };
  buscar(0);

  return { opciones: mejores, descartadas, incompleto: pasos > MAX_PASOS };
}
