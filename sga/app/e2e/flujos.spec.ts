import { expect, test } from "@playwright/test";
import { entrar, unico } from "./sesion";

// Flujos entre roles: lo que hace uno lo ve el otro.

test("trámite: el alumno lo inicia y Administración lo toma", async ({ browser }) => {
  const titulo = unico("Pedido E2E");
  const alumno = await (await browser.newContext()).newPage();
  await entrar(alumno, "alumno");
  await alumno.goto("/tramites/nuevo");
  await alumno.fill('input[name="titulo"]', titulo);
  await alumno.selectOption('select[name="destino"]', "ACADEMICA");
  await alumno.fill('textarea[name="descripcion"]', "Trámite creado por los tests E2E.");
  await alumno.getByRole("button", { name: "Enviar" }).click();
  await alumno.waitForURL(/\/tramites\/\d+\?ok=/);
  const detalle = new URL(alumno.url()).pathname;

  const admin = await (await browser.newContext()).newPage();
  await entrar(admin, "admin");
  await admin.goto("/administracion/tramites?estado=PENDIENTE");
  await expect(admin.locator("tbody tr", { hasText: titulo })).toBeVisible();
  await admin.goto(detalle);
  await admin.getByRole("button", { name: "Tomar trámite" }).click();
  await expect(admin.locator(".sga-mensaje-ok")).toBeVisible();

  await alumno.goto("/tramites");
  const fila = alumno.locator("tbody tr", { hasText: titulo });
  await expect(fila).toContainText("En curso");
  await expect(fila).toContainText("Administrativa, Laura");
});

test("mensaje: Administración le escribe a la alumna y ella lo recibe", async ({ browser }) => {
  const asunto = unico("Aviso E2E");
  const admin = await (await browser.newContext()).newPage();
  await entrar(admin, "admin");
  await admin.goto("/usuario/mensajes/nuevo");
  await admin.selectOption('select[name="para"]', "PERSONA");
  await admin.fill('input[name="mail"]', "alumno.demo@itba.edu.ar");
  await admin.fill('input[name="asunto"]', asunto);
  await admin.fill('textarea[name="cuerpo"]', "Mensaje enviado por los tests E2E.");
  await admin.locator(".sga-form-publicacion button").click();
  await admin.waitForURL(/ok=/);

  const alumno = await (await browser.newContext()).newPage();
  await entrar(alumno, "alumno");
  await alumno.goto("/usuario/mensajes");
  await alumno.getByText(asunto).click();
  await expect(alumno.getByText("Mensaje enviado por los tests E2E.")).toBeVisible();
});
