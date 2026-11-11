import { expect, test } from "@playwright/test";
import { entrar } from "./sesion";

test("Inicio muestra la semana de la alumna con su materia en curso", async ({ page }) => {
  await entrar(page, "alumno");
  const enCurso = page.locator(".sga-panel").filter({ has: page.getByRole("heading", { name: "Cursos en progreso" }) });
  await expect(enCurso.locator(".sga-semana-bloque").filter({ hasText: "71.38" }).first()).toBeVisible();
  await expect(enCurso.getByText("71.38 - Programación web")).toBeVisible();
  // Sin calendarios académicos cargados, esa sección no aparece
  await expect(page.getByRole("heading", { name: "Cronogramas Académicos" })).toHaveCount(0);
});

test("el calendario semanal muestra un cuatrimestre por vez", async ({ page }) => {
  await entrar(page, "alumno");
  await page.goto("/legajo/alumno/calendario");
  await expect(page.getByText(/Calendario actual: .*Cuat\. \d{4}/)).toBeVisible();
  await expect(page.locator(".sga-calendario td").filter({ hasText: "71.38 - Programación web" }).first()).toBeVisible();
});
