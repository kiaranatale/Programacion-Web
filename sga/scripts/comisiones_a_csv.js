// Pegar en la consola del navegador (F12 → Consola) estando en
// Académica → Cursos del SGA, con los filtros del cuatrimestre que se
// quiere (por ejemplo Período 2C, Año 2026). Recorre todas las páginas
// del listado, entra a cada curso y a su solapa "Comisiones", y descarga
// comisiones_sga.csv con el texto de cada fila (comisión, horarios, cupo).
// La columna de profesores no se baja (son datos de personas reales).
// Los horarios se interpretan después con scripts/csv_a_seed_comisiones.py.
// No usa la estructura HTML del SGA: busca las tablas por sus encabezados.
(async () => {
  const limpio = (s) => (s || "").replace(/\s+/g, " ").trim();
  const texto = (el) => limpio(el.textContent);
  const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
  const pedir = async (url) => {
    const resp = await fetch(url, { credentials: "include" });
    return { url: resp.url, doc: new DOMParser().parseFromString(await resp.text(), "text/html") };
  };

  // Filas del listado de cursos, con el link a su detalle
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
  const siguienteDe = (doc) => [...doc.querySelectorAll("a")].find((a) => /^(>|›|Siguiente)$/i.test(texto(a)));

  // Comisiones de un curso: la solapa "Comisiones" de su detalle
  const tablasComisiones = (d) => [...d.querySelectorAll("table")].filter((t) => {
    const enc = t.rows[0] ? [...t.rows[0].cells].map(texto).join(" | ") : "";
    return /Comisi[oó]n/i.test(enc) && !t.querySelector("table");
  });
  const filas = [["codigo", "materia", "periodo", "anio", "comienzo", "fin", "encabezado", "celdas"]];
  const sinComisiones = [];
  const vistos = new Set();
  let hechos = 0;
  const trabajar = async (curso) => {
    const [codigo, materia, , , periodo, anio] = curso.celdas;
    // Comienzo y fin: las dos primeras fechas de la fila (distinguen los
    // cursos de una misma materia en el mismo período, como los bimestrales)
    const [comienzo = "", fin = ""] = curso.celdas.filter((c) => /^\d{2}\/\d{2}\/\d{4}$/.test(c));
    try {
      if (!curso.url) throw new Error("sin link al detalle");
      let { url, doc: det } = await pedir(curso.url);
      const solapa = [...det.querySelectorAll("a[href]")].find((a) => /^Comisiones$/i.test(texto(a)));
      if (solapa && !/^javascript/i.test(solapa.getAttribute("href"))) ({ doc: det } = await pedir(new URL(solapa.getAttribute("href"), url)));
      const tablas = tablasComisiones(det);
      if (tablas.length === 0) sinComisiones.push(codigo);
      for (const t of tablas) {
        const nombres = [...t.rows[0].cells].map(texto);
        const quedan = nombres.map((n, i) => (/Profesor|Docente/i.test(n) ? -1 : i)).filter((i) => i >= 0);
        const encabezado = quedan.map((i) => nombres[i]).join(" | ");
        for (const tr of [...t.rows].slice(1)) {
          const celdas = [...tr.cells].map(texto);
          if (celdas.some(Boolean)) filas.push([codigo, materia, periodo, anio, comienzo, fin, encabezado, quedan.map((i) => celdas[i] ?? "").join(" | ")]);
        }
      }
    } catch (e) {
      sinComisiones.push(`${codigo} (${e.message})`);
    }
    hechos++;
  };
  // Los cursos nuevos de cada página se procesan enseguida, de a 4 a la
  // vez para no cargar al SGA (los links del listado pueden vencer).
  const procesar = async (doc, base) => {
    const nuevos = filasCursos(doc, base).filter((f) => {
      const clave = f.celdas.slice(0, 8).join("|");
      return !vistos.has(clave) && vistos.add(clave);
    });
    for (let i = 0; i < nuevos.length; i += 4) await Promise.all(nuevos.slice(i, i + 4).map(trabajar));
    return nuevos.length > 0;
  };

  // Recorre las páginas. Primero pide la siguiente por su link; si así no
  // aparecen cursos nuevos (el paginador actualiza la tabla sin recargar),
  // hace clic en ">" y espera a que cambie la tabla.
  const primeraFila = () => filasCursos(document, location.href)[0]?.celdas.join("|");
  await procesar(document, location.href);
  console.warn(`Página 1: ${hechos} cursos`);
  let modoClic = false, doc = document, base = location.href;
  for (let pagina = 2; pagina <= 200; pagina++) {
    let nuevos = false;
    if (!modoClic) {
      const link = siguienteDe(doc);
      if (!link) break;
      const href = link.getAttribute("href");
      if (href && !/^(javascript|#)/i.test(href)) {
        try {
          ({ url: base, doc } = await pedir(new URL(href, base)));
          nuevos = await procesar(doc, base);
        } catch { /* se prueba con clic */ }
      }
      if (!nuevos) modoClic = true;
    }
    if (modoClic) {
      const link = siguienteDe(document);
      if (!link) break;
      const antes = primeraFila();
      link.click();
      for (let i = 0; i < 100 && primeraFila() === antes; i++) await esperar(150);
      if (primeraFila() === antes) {
        console.warn("La tabla no cambió al hacer clic en \">\". Link:", link.outerHTML);
        break;
      }
      await esperar(300);
      nuevos = await procesar(document, location.href);
    }
    if (!nuevos) break;
    console.warn(`Página ${pagina}: ${hechos} cursos`);
  }

  const csv = filas.map((f) => f.map((v) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" }));
  a.download = "comisiones_sga.csv";
  a.click();
  if (sinComisiones.length) console.warn(`Sin comisiones (${sinComisiones.length}): ${sinComisiones.slice(0, 30).join(", ")}`);
  return `Listo: ${hechos} cursos, ${filas.length - 1} filas de comisiones`;
})().then((r) => console.log(r), (e) => console.error(e));
