// Pegar en la consola del navegador (F12 → Consola) estando en
// "Detalle de Planes de estudio" del SGA. Descarga <plan>.csv con una
// fila por materia, hueco de electivas y título, y además lo copia al
// portapapeles. Lee el texto de la página, no depende del HTML del SGA.
(() => {
  const limpio = (s) => (s || "").replace(/\s+/g, " ").trim();
  const texto = (el) => limpio(el.innerText);
  // El elemento más profundo cuyo texto completo cumple el patrón (los
  // encabezados vienen partidos en varios <span>).
  const marca = (el, re) =>
    !el.querySelector("table") && re.test(texto(el)) && ![...el.children].some((c) => re.test(texto(c)));

  const RE_PLAN = /^Plan de estudio:\s*(.+)$/;
  const RE_BLOQUE = /^(.+?)\s*-\s*Requisito:\s*(.+)$/;
  const RE_ANIO = /^Año\s+(\d+)\s*-\s*Cuatrimestre\s+(\d+)$/;
  const RE_CONTENIDO = /^Contenido:?$/;
  const RE_MATERIA = /^(\d{2}\.\d{2})\s*-\s*(.+)$/;

  let plan = "", bloque = "", requisito = "", anio = "", cuatri = "";
  const filas = [["plan", "tipo", "bloque", "requisito_bloque", "anio", "cuatrimestre", "codigo", "nombre", "creditos", "creditos_requeridos", "correlativas"]];

  for (const el of document.querySelectorAll("body *")) {
    if (el.tagName === "TABLE") {
      const encabezado = el.rows[0] ? [...el.rows[0].cells].map(texto) : [];
      const col = (nombre) => encabezado.findIndex((h) => h.toLowerCase() === nombre.toLowerCase());
      if (col("Materia") >= 0 && col("Créditos") >= 0) {
        for (const tr of [...el.rows].slice(1)) {
          const c = [...tr.cells].map(texto);
          const materia = c[col("Materia")] || "";
          if (!materia) continue;
          const m = materia.match(RE_MATERIA);
          const correlativas = (c[col("Correlativas")] || "").match(/\d{2}\.\d{2}/g) || [];
          filas.push([plan, m ? "MATERIA" : "HUECO", bloque, requisito, anio, cuatri,
            m ? m[1] : "", m ? m[2] : materia, c[col("Créditos")] || "", c[col("Créditos requeridos")] || "", correlativas.join(" ")]);
        }
      } else if (col("Tipo") >= 0 && col("Título") >= 0) {
        for (const tr of [...el.rows].slice(1)) {
          const c = [...tr.cells].map(texto);
          if (c[col("Título")]) filas.push([plan, "TITULO", c[col("Tipo")], c[col("Requisitos")] || "", "", "", "", c[col("Título")], "", "", ""]);
        }
      }
      continue;
    }
    if (el.closest("table")) continue;
    if (marca(el, RE_PLAN)) plan = texto(el).match(RE_PLAN)[1];
    else if (marca(el, RE_BLOQUE)) {
      const m = texto(el).match(RE_BLOQUE);
      bloque = m[1]; requisito = m[2]; anio = ""; cuatri = "";
    } else if (marca(el, RE_ANIO)) [, anio, cuatri] = texto(el).match(RE_ANIO);
    else if (marca(el, RE_CONTENIDO)) { anio = ""; cuatri = ""; }
  }

  const csv = filas.map((f) => f.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(",")).join("\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" }));
  a.download = `${(plan || "plan").replace(/[^\w.-]+/g, "_")}.csv`;
  a.click();
  try { copy(csv); } catch { /* copy() solo existe en la consola de Chrome/Edge */ }
  console.warn(`Plan ${plan}: ${filas.filter((f) => f[1] === "MATERIA").length} materias, ${filas.filter((f) => f[1] === "HUECO").length} huecos, ${filas.filter((f) => f[1] === "TITULO").length} títulos.`);
})();
