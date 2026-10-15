import { expect, test } from "@playwright/test";
import { entrar } from "./sesion";

test.beforeEach(async ({ page }) => entrar(page, "alumno"));

test("Mi legajo muestra los datos de la alumna", async ({ page }) => {
  await page.goto("/legajo");
  await expect(page.getByText("Detalles del legajo de Alumna, Ana")).toBeVisible();
  await expect(page.locator("main")).toContainText(/DNI:\s*40000001/);
});

test("el analítico muestra el plan y los créditos", async ({ page }) => {
  await page.goto("/legajo/alumno/analitico");
  await expect(page.getByText("Plan de estudios: A22 (Licenciatura en Analítica Empresarial y Social)")).toBeVisible();
  await expect(page.getByText("Créditos totales del plan:")).toContainText("192");
});
