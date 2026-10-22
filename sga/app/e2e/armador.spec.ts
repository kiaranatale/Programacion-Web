import { expect, test } from "@playwright/test";
import { entrar } from "./sesion";

test("armador: entiende el pedido y arma una opción sin clases el viernes", async ({ page }) => {
  await entrar(page, "alumno");
  await page.goto("/armador");
  await page.fill("#pedido", "Quiero los viernes libres y no entrar antes de las 10");
  await page.getByRole("button", { name: "Armar horarios" }).click();
  const entendido = page.getByRole("list", { name: "Lo que entendí" });
  await expect(entendido).toContainText("Día libre: viernes");
  await expect(entendido).toContainText("Entrar a partir de las 10:00");
  await expect(page.getByText(/Opción 1 de \d+/)).toBeVisible();
  await expect(page.locator(".sga-semana-bloque").first()).toBeVisible();
  // Ningún bloque cae el viernes ni empieza antes de las 10
  const viernes = page.locator(".sga-semana-dia").filter({ hasText: "Viernes" });
  await expect(viernes.locator(".sga-semana-bloque")).toHaveCount(0);
  for (const titulo of await page.locator(".sga-semana-bloque").evaluateAll((bs) => bs.map((b) => b.getAttribute("title") ?? ""))) {
    const desde = titulo.match(/(\d{2}):(\d{2}) a/);
    expect(desde && Number(desde[1]) * 60 + Number(desde[2])).toBeGreaterThanOrEqual(600);
  }
});

test("armador: la lista arranca con lo que falta cursar, en el orden del plan", async ({ page }) => {
  await entrar(page, "alumno");
  await page.goto("/armador");
  const lista = page.locator(".sga-armador-materias");
  await expect(lista.locator("h4").first()).toHaveText(/1\.º año · 1\.º cuatrimestre/i);
  const antes = await lista.locator("li").count();
  await page.getByLabel("Mostrar también las que ya aprobé o estoy cursando").check();
  await expect.poll(() => lista.locator("li").count()).toBeGreaterThan(antes);
});
