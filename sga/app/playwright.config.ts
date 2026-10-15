import { readFileSync } from "node:fs";
import { defineConfig, devices } from "@playwright/test";

// Tests E2E contra una Supabase local (ver "Paso 5 — Tests E2E" en
// ROADMAP.md). scripts/e2e_preparar.sh deja la URL y las claves en .env.e2e.
function leerEnv(ruta: string): Record<string, string> {
  try {
    return Object.fromEntries(
      readFileSync(ruta, "utf8").split("\n").filter((l) => l.includes("=")).map((l) => {
        const i = l.indexOf("=");
        return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
      }),
    );
  } catch {
    return {};
  }
}
const env = { ...leerEnv(".env.e2e"), ...process.env } as Record<string, string>;
for (const clave of ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"]) process.env[clave] ??= env[clave];

const PUERTO = 3100;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL: `http://127.0.0.1:${PUERTO}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    // Las variables NEXT_PUBLIC_* se fijan en el build, así que se arma con las
    // de la Supabase local.
    command: `npm run build && npm run start -- -p ${PUERTO}`,
    url: `http://127.0.0.1:${PUERTO}/login`,
    reuseExistingServer: !process.env.CI,
    timeout: 300_000,
    env: {
      NEXT_PUBLIC_SUPABASE_URL: env.NEXT_PUBLIC_SUPABASE_URL ?? "",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
      SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY ?? "",
    },
  },
});
