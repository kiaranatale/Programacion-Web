import { expect, test } from "@playwright/test";
import { entrar } from "./sesion";

// Detalle de planes como en el SGA: bloques, huecos de electivas y títulos.
test.beforeEach(async ({ page }) => entrar(page, "alumno"));

const titulo = (page: import("@playwright/test").Page, texto: string) =>
  page.locator(".sga-bloque-plan-titulo", { hasText: texto });

test("A22: grilla del bloque básico con los huecos de electivas", async ({ page }) => {
  await page.goto("/carreras/LAES/planes/A22");
  await expect(titulo(page, "Básico - Requisito: Aprobar todos los ítems (suma 192 créditos)")).toBeVisible();
  await expect(page.locator(".sga-fila-hueco", { hasText: "Electivas Orientación" })).toBeVisible();
});

test("S10-Rev23: el ciclo básico muestra su título intermedio", async ({ page }) => {
  await page.goto("/carreras/S/planes/S10-Rev23");
  await expect(titulo(page, "Ciclo Básico")).toContainText("( Título otorgado: Analista en Tecnología Informática )");
});

test("I22: bloque de elegir un ítem y huecos sin año bajo Contenido", async ({ page }) => {
  await page.goto("/carreras/I/planes/I22");
  await expect(titulo(page, "Gestión de datos (obligatoria) - Requisito: Aprobar 1 item(s) (suma 6 créditos)")).toBeVisible();
  const plan = page.locator(".sga-bloque-plan", { has: titulo(page, "PLAN I22") });
  const contenido = plan.locator(".sga-bloque-plan-grupo", { has: page.getByRole("heading", { name: "Contenido:" }) });
  await expect(contenido.locator(".sga-fila-hueco")).toHaveCount(7);
});

test("M22: Materias electivas contiene las dos áreas", async ({ page }) => {
  await page.goto("/carreras/M/planes/M22");
  const electivas = page.locator(".sga-bloque-plan", { has: titulo(page, "Materias electivas - Requisito: Juntar 42 créditos") });
  await expect(electivas.locator(".sga-fila-hueco")).toHaveText([/Área Complementaria\s*3/, /Área Tecnológica\s*36/]);
});
