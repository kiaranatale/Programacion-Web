import { expect, test } from "@playwright/test";
import { CLAVE, entrar, USUARIOS } from "./sesion";

test("sin sesión, cualquier pantalla lleva al login", async ({ page }) => {
  await page.goto("/legajo");
  await expect(page).toHaveURL(/\/login/);
});

test("con la clave equivocada no entra y lo avisa", async ({ page }) => {
  await page.goto("/login");
  await page.fill('input[name="email"]', USUARIOS.alumno);
  await page.fill('input[name="password"]', `${CLAVE}x`);
  await page.click('.login-form button[type="submit"]');
  await expect(page.getByText("Mail o contraseña incorrectos.")).toBeVisible();
  await expect(page).toHaveURL(/\/login/);
});

// Cada rol ve su menú: los ítems de otros roles no aparecen.
const menus = {
  alumno: { ve: ["Legajos"], noVe: ["Docencia"], admin: false },
  docente: { ve: ["Docencia"], noVe: ["Legajos"], admin: false },
  admin: { ve: [], noVe: ["Legajos", "Docencia"], admin: true },
} as const;

for (const [rol, menu] of Object.entries(menus) as [keyof typeof menus, (typeof menus)[keyof typeof menus]][]) {
  test(`menú del ${rol}`, async ({ page }) => {
    await entrar(page, rol);
    const nav = page.locator(".sga-nav");
    for (const m of menu.ve) await expect(nav.getByRole("button", { name: m })).toBeVisible();
    for (const m of menu.noVe) await expect(nav.getByRole("button", { name: m })).toHaveCount(0);
    const personas = page.locator('.sga-nav-menu a[href="/administracion/personas"]');
    await expect(personas).toHaveCount(menu.admin ? 1 : 0);
  });
}

test("salir cierra la sesión", async ({ page }) => {
  await entrar(page, "alumno");
  await page.getByRole("button", { name: "Salir" }).click();
  await expect(page).toHaveURL(/\/login/);
  await page.goto("/legajo");
  await expect(page).toHaveURL(/\/login/);
});

test("el menú lateral se pliega, se recuerda al recargar y se despliega desde un grupo", async ({ page }) => {
  await entrar(page, "alumno");
  const menu = page.locator(".sga-sidebar");
  await page.getByRole("button", { name: "Plegar el menú lateral" }).click();
  await expect(menu).toHaveClass(/is-plegado/);
  await page.reload();
  await expect(menu).toHaveClass(/is-plegado/);
  // Tocar un grupo plegado despliega el menú con ese grupo abierto
  await page.locator(".sga-nav").getByRole("button", { name: "Legajos" }).click();
  await expect(menu).not.toHaveClass(/is-plegado/);
  await expect(page.locator('.sga-nav-menu a[href="/legajo"]')).toBeVisible();
});
