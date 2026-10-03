import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual, periodoDeFecha } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";

type Hito = { id: number; tipo: string; descripcion: string | null; fecha_evento: string; fecha_registro: string };

const rolesLegibles: Record<string, string> = {
  ALUMNO: "Alumno", DOCENTE: "Docente", AYUDANTE: "Ayudante", ADMINISTRATIVO: "Administrativo",
};

export default async function Roles() {
  const [{ legajo, nombre }, sesion] = await Promise.all([getLegajoActual(), getSesion()]);
  if (!legajo) return null;

  const supabase = await createClient();
  const { data: hitos } = await supabase
    .schema("sga")
    .from("hito_academico")
    .select("id, tipo, descripcion, fecha_evento, fecha_registro")
    .eq("legajo_id", legajo.id)
    .order("fecha_evento", { ascending: false })
    .returns<Hito[]>();

  const carrera = legajo.plan_estudio?.carrera;

  return (
    <>
      <h3 className="sga-subtitulo">Roles de {nombre}</h3>
      <p className="sga-texto">{sesion?.roles.map((r) => rolesLegibles[r] ?? r).join(", ")}</p>
      <p className="sga-texto">Fecha de registración como alumno: {fecha(legajo.fecha_registracion)}</p>

      <table className="sga-tabla sga-tabla-compacta">
        <thead><tr><th>Nivel</th><th>Legajo</th></tr></thead>
        <tbody>
          <tr><td>{carrera?.nivel === "POSGRADO" ? "Posgrado" : "Grado"}</td><td>{legajo.numero_legajo}</td></tr>
        </tbody>
      </table>

      <h4 className="sga-subtitulo-chico">Carreras en curso</h4>
      <table className="sga-tabla sga-tabla-compacta">
        <thead><tr><th>Plan de carrera</th><th>Orientación</th><th>Período de inicio</th></tr></thead>
        <tbody>
          <tr>
            <td>{legajo.plan_estudio?.codigo} — {carrera?.nombre_oficial}</td>
            <td></td>
            <td>{periodoDeFecha(legajo.fecha_registracion)}</td>
          </tr>
        </tbody>
      </table>

      <h3 className="sga-subtitulo">Historial de actividades</h3>
      {hitos && hitos.length > 0 ? (
        <ul className="sga-historial">
          {hitos.map((h) => (
            <li key={h.id}>
              <strong>{h.tipo}:</strong> {h.descripcion} — Registrado el {fecha(h.fecha_evento)}
            </li>
          ))}
        </ul>
      ) : (
        <p className="sga-vacio">No hay actividades registradas.</p>
      )}
    </>
  );
}
