// Intérprete del pedido en castellano para el armador de horarios
// ("quiero los viernes libres, no antes de las 10 y sin huecos").
// Reglas fijas, sin servicios externos: devuelve las preferencias que
// entendió y una lista legible para mostrarle a la persona qué entendió.
// La misma firma permitiría cambiarlo por un modelo de lenguaje.

import { DIAS, hora, type Preferencias } from "@/lib/armador";

export type Interpretacion = { preferencias: Partial<Preferencias>; entendido: string[] };
type MateriaNombre = { codigo: string; nombre: string };

const normalizar = (s: string) =>
  s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9:.ñ\s]/g, " ").replace(/\s+/g, " ").trim();

const DIA_NORMAL: Record<string, number> = {
  lunes: 0, martes: 1, miercoles: 2, jueves: 3, viernes: 4, sabado: 5, sabados: 5, domingo: 6, domingos: 6,
};
const NUMEROS: Record<string, number> = { un: 1, una: 1, uno: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6, siete: 7, ocho: 8 };
const numero = (s: string) => (/^\d+$/.test(s) ? Number(s) : NUMEROS[s] ?? null);
const NUM = "(\\d+|un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho)";
const PALABRA_DIA = "(lunes|martes|miercoles|jueves|viernes|sabados?|domingos?)";
// "las 10", "10hs", "10:30", "las 6 de la tarde"
const HORA = "(?:las? )?(\\d{1,2})(?:[:.](\\d{2}))?(?: ?(?:hs|h|horas))?( de la (?:tarde|noche)| pm)?";

const listaDias = (dias: number[]) => {
  const nombres = [...dias].sort((a, b) => a - b).map((d) => DIAS[d].toLowerCase());
  return nombres.length > 1 ? `${nombres.slice(0, -1).join(", ")} y ${nombres.at(-1)}` : nombres[0];
};

function aMinutos(h: string, m: string | undefined, tarde: string | undefined): number | null {
  let horas = Number(h);
  if (tarde && horas < 12) horas += 12;
  if (horas > 23) return null;
  return horas * 60 + (m ? Number(m) : 0);
}

// Días mencionados en una frase, con rangos ("de lunes a jueves")
function diasDe(frase: string): number[] {
  const dias = new Set<number>();
  for (const m of frase.matchAll(new RegExp(`${PALABRA_DIA} (?:a|al|hasta) (?:el )?${PALABRA_DIA}`, "g"))) {
    for (let d = DIA_NORMAL[m[1]]; d <= DIA_NORMAL[m[2]]; d++) dias.add(d);
  }
  for (const m of frase.matchAll(new RegExp(`\\b${PALABRA_DIA}\\b`, "g"))) dias.add(DIA_NORMAL[m[1]]);
  return [...dias];
}

const VACIAS = new Set(["de", "del", "la", "el", "los", "las", "y", "e", "en", "para", "con", "a", "al", "por", "sus", "su"]);
const ROMANOS = new Set(["i", "ii", "iii", "iv", "v", "vi"]);
const palabras = (s: string) => normalizar(s).split(" ").filter((p) => p && !VACIAS.has(p));
// Una palabra del nombre aparece en el texto: igual, o con el mismo
// comienzo si es larga ("matemat" ~ "matematica"). Los números romanos y
// los números tienen que coincidir exactos.
const aparece = (palabra: string, texto: string[]) =>
  texto.some((t) => t === palabra || (!ROMANOS.has(palabra) && palabra.length >= 5 && t.length >= 5 && (t.startsWith(palabra.slice(0, 6)) || palabra.startsWith(t.slice(0, 6)))));

// Palabras comunes a muchos nombres de materia: no alcanzan para reconocerla
const GENERICAS = new Set(["analisis", "introduccion", "taller", "seminario", "fundamentos", "sistemas", "gestion",
  "proyecto", "practica", "ingenieria", "laboratorio", "aplicada", "aplicadas", "general", "avanzada", "avanzado"]);

// Materias nombradas en una frase, por código ("93.18"), por nombre
// completo o por sus palabras distintivas ("coyuntura económica" para
// "Análisis de Coyuntura Económica"). Si coinciden "Álgebra" y "Álgebra
// Lineal", queda la más específica.
function materiasDe(frase: string, materias: MateriaNombre[]): string[] {
  const texto = frase.split(" ");
  const halladas = materias.filter((m) => {
    if (frase.includes(m.codigo)) return true;
    const nombre = palabras(m.nombre);
    if (nombre.length > 0 && nombre.every((p) => aparece(p, texto))) return true;
    const distintivas = nombre.filter((p) => p.length >= 5 && !GENERICAS.has(p));
    return distintivas.length >= 2 && nombre.every((p) => GENERICAS.has(p) || p.length < 5 || aparece(p, texto));
  });
  return halladas
    .filter((a) => !halladas.some((b) => b !== a && !frase.includes(a.codigo)
      && palabras(b.nombre).length > palabras(a.nombre).length
      && palabras(a.nombre).every((p) => palabras(b.nombre).includes(p))))
    .map((m) => m.codigo);
}

export function interpretar(pedido: string, materias: MateriaNombre[]): Interpretacion {
  const p: Partial<Preferencias> = {};
  const entendido: string[] = [];
  const libres = new Set<number>();
  const incluir = new Set<string>();
  const excluir = new Set<string>();
  const texto = normalizar(pedido);
  // Frases: se corta en puntuación y en "pero"
  const frases = pedido.split(/[\n.;,]|\bpero\b/i).map(normalizar).filter(Boolean);

  for (const frase of frases) {
    const dias = diasDe(frase);
    const niega = /\b(no|sin|nada|excepto|salvo|menos|evitar|evito)\b/.test(frase);
    if (dias.length) {
      if (/\b(solo|solamente|unicamente|nada mas que)\b/.test(frase) && !/\blibres?\b/.test(frase)) {
        for (let d = 0; d <= 5; d++) if (!dias.includes(d)) libres.add(d);
      } else if (/\blibres?\b|sin (clases?|cursar|ir)|no (quiero|puedo|me sirve)|no (curso|voy)|nada (el|los)|evitar|trabaj/.test(frase)) {
        dias.forEach((d) => libres.add(d));
      }
    }
    // "un día libre", "dos días libres" (sin decir cuáles)
    const libresN = frase.match(new RegExp(`${NUM} dias? libres?`));
    if (libresN && !dias.length) {
      const n = numero(libresN[1]);
      if (n) p.maxDias = Math.max(5 - n, 1);
    }
    // "en 3 días", "máximo 4 días", "como mucho tres días"
    const enDias = frase.match(new RegExp(`(?:en|maximo|max|como mucho|hasta|solo|solamente) ${NUM} dias\\b(?! libres?)`));
    if (enDias) p.maxDias = numero(enDias[1]) ?? p.maxDias;

    const materiasFrase = materiasDe(frase, materias);
    for (const codigo of materiasFrase) (niega && /\b(no|sin|excepto|salvo|menos)\b/.test(frase) ? excluir : incluir).add(codigo);
  }

  // Horarios. Cada "antes de" / "después de" se lee según si la frase lo
  // niega unas palabras antes ("no quiero salir después de las 19" es un
  // "hasta"; "nada antes de las 10", un "desde").
  for (const frase of frases) {
    const patron = new RegExp(`(despues de|mas tarde de|antes de|a partir de|desde|hasta|(?:entrar|empezar|arrancar|terminar|salir) a) ${HORA}`, "g");
    for (const m of frase.matchAll(patron)) {
      const minutos = aMinutos(m[2], m[3], m[4]);
      if (minutos === null) continue;
      const previas = frase.slice(0, m.index).trim().split(" ").slice(-4);
      const negada = previas.some((w) => ["no", "nada", "sin", "ni"].includes(w));
      const clave = m[1];
      const esDesde = /^(a partir de|desde|entrar a|empezar a|arrancar a)$/.test(clave)
        || (clave === "despues de" && !negada)
        || (clave === "antes de" && negada);
      if (esDesde) p.desde ??= minutos;
      else p.hasta ??= minutos;
    }
  }
  if (p.desde === undefined && /no (quiero )?madrugar|sin madrugar|nada (muy )?temprano|no (muy )?temprano/.test(texto)) p.desde = 10 * 60;
  if (/\b(solo|solamente|prefiero|quiero)\b[^.]*\b(a|por|de) la manana\b/.test(texto) && !/no[^.]*manana/.test(texto)) p.hasta ??= 13 * 60;
  if (/\b(solo|solamente|prefiero|quiero)\b[^.]*\b(a|por|de) la tarde\b/.test(texto)) p.desde ??= 13 * 60;
  if (/\b(solo|solamente|prefiero|quiero)\b[^.]*\b(a|por|de) la noche\b/.test(texto)) p.desde ??= 18 * 60;
  if (/(nada|no|sin)[^.]*\b(a|por|de) la noche\b|nada de noche/.test(texto)) p.hasta ??= 18 * 60;
  if (/(nada|no|sin)[^.]*\b(a|por|de) la manana\b/.test(texto)) p.desde ??= 12 * 60;

  const cuantas = texto.match(new RegExp(`${NUM} materias`));
  if (cuantas) p.maxMaterias = numero(cuantas[1]) ?? undefined;
  if (/sin (huecos?|ventanas?|horas (libres|muertas)|tiempos? muertos?)|seguid|corrid|pegad/.test(texto)) p.sinHuecos = true;
  if (/pocos dias|menos dias|menor cantidad de dias|concentrad|juntar/.test(texto)) p.pocosDias = true;
  if (/(solo|solamente) presencial|nada (de )?virtual|sin virtual|no (quiero )?(clases? )?virtual|presencial(es)? nomas/.test(texto)) p.soloPresencial = true;
  if (/(con|que tengan?) (lugar|cupo|vacantes?)|no (esten )?llenas?|sin llenas|evitar (las )?llenas/.test(texto)) p.evitarLlenas = true;

  for (const clave of Object.keys(p) as (keyof Preferencias)[]) if (p[clave] === undefined) delete p[clave];
  if (libres.size) p.diasLibres = [...libres].sort((a, b) => a - b);
  if (incluir.size) p.incluir = [...incluir];
  if (excluir.size) p.excluir = [...excluir];

  // Qué entendió, en palabras
  const nombre = (c: string) => `${c} ${materias.find((m) => m.codigo === c)?.nombre ?? ""}`.trim();
  if (p.diasLibres?.length) entendido.push(`${p.diasLibres.length > 1 ? "Días libres" : "Día libre"}: ${listaDias(p.diasLibres)}`);
  if (p.maxDias) entendido.push(`Cursar como máximo ${p.maxDias} ${p.maxDias === 1 ? "día" : "días"}`);
  if (p.desde !== undefined && p.desde !== null) entendido.push(`Entrar a partir de las ${hora(p.desde)}`);
  if (p.hasta !== undefined && p.hasta !== null) entendido.push(`Salir a más tardar a las ${hora(p.hasta)}`);
  if (p.maxMaterias) entendido.push(`Como máximo ${p.maxMaterias} ${p.maxMaterias === 1 ? "materia" : "materias"}`);
  if (p.sinHuecos) entendido.push("Sin huecos entre clases");
  if (p.pocosDias) entendido.push("La menor cantidad de días posible");
  if (p.soloPresencial) entendido.push("Solo comisiones sin clases virtuales");
  if (p.evitarLlenas) entendido.push("Evitar comisiones llenas");
  if (p.incluir?.length) entendido.push(`Sí o sí: ${p.incluir.map(nombre).join(", ")}`);
  if (p.excluir?.length) entendido.push(`Sin: ${p.excluir.map(nombre).join(", ")}`);
  return { preferencias: p, entendido };
}
