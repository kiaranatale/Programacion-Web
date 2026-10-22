// Pegar en la consola del navegador (F12 → Consola) estando en
// Académica → Cursos del SGA, con los filtros del cuatrimestre que se
// quiere (por ejemplo Período 2C, Año 2026). Recorre todas las páginas
// del listado, entra a cada curso y a su solapa "Comisiones", y descarga
// comisiones_sga.csv con el texto de cada fila (comisión, cupo, horarios).
// Los horarios se interpretan después con scripts/csv_a_seed_comisiones.py.
// No usa la estructura HTML del SGA: busca las tablas por sus encabezados.
(async () => {
  const limpio = (s) => (s || "").replace(/\s+/g, " ").trim();
  const texto = (el) => limpio(el.textContent);
  const pedir = async (url) => {
    const resp = await fetch(url, { credentials: "include" });
    return { url: resp.url, doc: new DOMParser().parseFromString(await resp.text(), "text/html") };
  };

  // 1. Cursos del listado (todas las páginas), con el link a su detalle
  const filasCursos = (doc, base) => {
    const tabla = [...doc.querySelectorAll("table")].filter((t) => /Cód\./.test(t.textContent)).pop();
    return [...(tabla?.querySelectorAll("tr") ?? [])]
      .map((tr) => {
        const celdas = [...tr.querySelectorAll("td")].map(texto);
        const link = [...tr.querySelectorAll("a[href]")].find((a) => !/^javascript/i.test(a.getAttribute("href")));
        return { celdas, url: link ? new URL(link.getAttribute("href"), base).href : null };
      })
      .filter((f) => f.celdas.length >= 8 && /^\d+\.\d+/.test(f.celdas[0]));
  };
  const siguienteDe = (doc) => [...doc.querySelectorAll("a")].find((a) => texto(a) === ">");
  const cursos = new Map();
  let doc = document, base = location.href, link = siguienteDe(doc);
  filasCursos(doc, base).forEach((f) => cursos.set(f.celdas.slice(0, 8).join("|"), f));
  for (let pagina = 2; link && pagina <= 200; pagina++) {
    const antes = cursos.size;
    ({ url: base, doc } = await pedir(new URL(link.getAttribute("href"), base)));
    filasCursos(doc, base).forEach((f) => cursos.set(f.celdas.slice(0, 8).join("|"), f));
    console.warn(`Listado, página ${pagina}: ${cursos.size} cursos`);
    if (cursos.size === antes) break;
    link = siguienteDe(doc);
  }

  // 2. Comisiones de cada curso: la solapa "Comisiones" del detalle
  const tablasComisiones = (d) => [...d.querySelectorAll("table")].filter((t) => {
    const enc = t.rows[0] ? [...t.rows[0].cells].map(texto).join(" | ") : "";
    return /Comisi[oó]n/i.test(enc) && !t.querySelector("table");
  });
  const filas = [["codigo", "materia", "periodo", "anio", "encabezado", "celdas"]];
  const sinComisiones = [];
  const lista = [...cursos.values()];
  let hechos = 0;
  const trabajar = async (curso) => {
    const [codigo, materia, , , periodo, anio] = curso.celdas;
    try {
      if (!curso.url) throw new Error("sin link al detalle");
      let { url, doc: det } = await pedir(curso.url);
      const solapa = [...det.querySelectorAll("a[href]")].find((a) => /^Comisiones$/i.test(texto(a)));
      if (solapa && !/^javascript/i.test(solapa.getAttribute("href"))) ({ doc: det } = await pedir(new URL(solapa.getAttribute("href"), url)));
      const tablas = tablasComisiones(det);
      if (tablas.length === 0) sinComisiones.push(codigo);
      for (const t of tablas) {
        const encabezado = [...t.rows[0].cells].map(texto).join(" | ");
        for (const tr of [...t.rows].slice(1)) {
          const celdas = [...tr.cells].map(texto);
          if (celdas.some(Boolean)) filas.push([codigo, materia, periodo, anio, encabezado, celdas.join(" | ")]);
        }
      }
    } catch (e) {
      sinComisiones.push(`${codigo} (${e.message})`);
    }
    if (++hechos % 20 === 0) console.warn(`Comisiones: ${hechos}/${lista.length} cursos`);
  };
  // De a 4 cursos a la vez, para no cargar al SGA
  for (let i = 0; i < lista.length; i += 4) await Promise.all(lista.slice(i, i + 4).map(trabajar));

  const csv = filas.map((f) => f.map((v) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }));
  a.download = "comisiones_sga.csv";
  a.click();
  if (sinComisiones.length) console.warn(`Sin comisiones (${sinComisiones.length}): ${sinComisiones.slice(0, 30).join(", ")}`);
  return `Listo: ${cursos.size} cursos, ${filas.length - 1} filas de comisiones`;
})().then((r) => console.log(r), (e) => console.error(e));
