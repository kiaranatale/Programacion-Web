import { expect, test } from "@playwright/test";
import { clienteDe, entrar } from "./sesion";

test("un alumno no entra a las pantallas de Administración", async ({ page }) => {
  await entrar(page, "alumno");
  await page.goto("/administracion/personas");
  await expect(page.getByText("Esta sección es solo para Administración.")).toBeVisible();
});

// RLS probado contra la API, como lo pediría cualquier navegador con la
// sesión del usuario: la pantalla no es la única barrera.
test("un alumno solo ve su propia persona; Administración ve a todos", async () => {
  const alumno = await clienteDe("alumno");
  const { data: propias, error } = await alumno.from("persona").select("mail_institucional");
  expect(error).toBeNull();
  expect(propias).toEqual([{ mail_institucional: "alumno.demo@itba.edu.ar" }]);

  const admin = await clienteDe("admin");
  const { data: todas } = await admin.from("persona").select("id");
  expect(todas!.length).toBeGreaterThan(1);
});

test("un docente no ve las facturas de los alumnos", async () => {
  const alumno = await clienteDe("alumno");
  const { data: delAlumno } = await alumno.from("factura").select("id");
  expect(delAlumno!.length).toBeGreaterThan(0);

  const docente = await clienteDe("docente");
  const { data: delDocente, error } = await docente.from("factura").select("id");
  expect(error).toBeNull();
  expect(delDocente).toEqual([]);
});
