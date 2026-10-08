"use client";

import { useEffect } from "react";

// En pantallas angostas, las tablas (.sga-tabla) se muestran como
// tarjetas: cada celda lleva el nombre de su columna (data-label) y el CSS
// hace el resto. Las tablas con celdas combinadas (rowspan) quedan como
// están, con su scroll horizontal. Se vuelve a aplicar cuando cambia el
// contenido (navegación, formularios).
function etiquetar() {
  document.querySelectorAll<HTMLTableElement>("table.sga-tabla:not([data-tarjetas])").forEach((tabla) => {
    tabla.dataset.tarjetas = "";
    if (tabla.querySelector("td[rowspan]:not([rowspan='1'])")) return;
    const encabezado = tabla.tHead?.querySelector("tr:not(.sga-fila-filtros)");
    if (!encabezado) return;
    const nombres: string[] = [];
    for (const th of Array.from(encabezado.children) as HTMLTableCellElement[]) {
      for (let i = 0; i < (th.colSpan || 1); i++) nombres.push(th.textContent?.trim() ?? "");
    }
    const filas = [...Array.from(tabla.tBodies).flatMap((b) => Array.from(b.rows)), ...Array.from(tabla.tHead?.querySelectorAll<HTMLTableRowElement>("tr.sga-fila-filtros") ?? [])];
    for (const fila of filas) {
      let col = 0;
      for (const celda of Array.from(fila.cells)) {
        celda.dataset.label = celda.colSpan > 1 ? "" : nombres[col] ?? "";
        col += celda.colSpan || 1;
      }
    }
    tabla.classList.add("sga-tarjetas");
  });
}

export default function TablasResponsivas() {
  useEffect(() => {
    etiquetar();
    let pendiente = 0;
    const observador = new MutationObserver(() => {
      cancelAnimationFrame(pendiente);
      pendiente = requestAnimationFrame(etiquetar);
    });
    observador.observe(document.body, { childList: true, subtree: true });
    return () => observador.disconnect();
  }, []);
  return null;
}
