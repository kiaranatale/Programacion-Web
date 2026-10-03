import { SiNo } from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { getLegajoActual } from "@/lib/legajo";
import { estadosDocumento, TIPOS_PERMITIDOS } from "@/lib/documentacion";
import { eliminarDocumento, subirDocumento } from "./actions";

type Requerido = { id: number; nombre: string; categoria: string; obligatoria: boolean; carrera_id: number | null; nivel: string | null };
type Entregado = {
  id: number;
  documento_requerido_id: number;
  nombre_archivo: string | null;
  ruta_archivo: string | null;
  estado: string;
  observaciones: string | null;
};

const aceptados = Object.keys(TIPOS_PERMITIDOS).join(",");

export default async function Documentacion({ searchParams }: PageProps<"/legajo/alumno/documentacion">) {
  const { ok, error } = await searchParams;
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: requeridos }, { data: entregados }, { data: carrera }] = await Promise.all([
    sga.from("documento_requerido").select("id, nombre, categoria, obligatoria, carrera_id, nivel")
      .order("obligatoria", { ascending: false }).order("nombre").returns<Requerido[]>(),
    sga.from("documento_legajo").select("id, documento_requerido_id, nombre_archivo, ruta_archivo, estado, observaciones")
      .eq("legajo_id", legajo?.id ?? 0).returns<Entregado[]>(),
    sga.from("plan_estudio").select("carrera_id").eq("id", legajo?.plan_estudio?.id ?? 0)
      .maybeSingle<{ carrera_id: number }>(),
  ]);

  // Aplica si es para todas las carreras/niveles o para la del alumno
  const nivel = legajo?.plan_estudio?.carrera?.nivel;
  const aplicables = (requeridos ?? []).filter(
    (r) => (r.carrera_id === null || r.carrera_id === carrera?.carrera_id) && (r.nivel === null || r.nivel === nivel),
  );

  return (
    <>
      <h3 className="sga-subtitulo">Documentación</h3>
      <p className="sga-texto">
        Archivos PDF, PNG o JPG de hasta 4 MB. Al subirlos quedan <strong>pendientes de validación</strong> por
        Administración; mientras tanto podés reemplazarlos o eliminarlos.
      </p>
      {typeof ok === "string" && <p className="sga-mensaje-ok" role="status">{ok}</p>}
      {typeof error === "string" && <p className="sga-mensaje-error" role="alert">{error}</p>}

      <div className="sga-tabla-scroll">
        <table className="sga-tabla">
          <thead>
            <tr>
              <th>Documento</th><th>Categoría</th><th>Obligatoria</th><th>Entregada</th>
              <th>Nombre del archivo</th><th>Estado del archivo</th><th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {aplicables.length === 0 && (
              <tr><td className="sga-vacio" colSpan={7}>No hay documentación requerida.</td></tr>
            )}
            {aplicables.map((r) => {
              const e = (entregados ?? []).find((x) => x.documento_requerido_id === r.id);
              const estado = e?.estado ?? "NO_CARGADO";
              const puedeSubir = estado !== "VALIDADO";
              const puedeEliminar = estado === "CARGADO" || estado === "RECHAZADO";
              return (
                <tr key={r.id}>
                  <td>{r.nombre}</td>
                  <td>{r.categoria}</td>
                  <td><SiNo valor={r.obligatoria} /></td>
                  <td><SiNo valor={estado !== "NO_CARGADO"} /></td>
                  <td>
                    {e?.ruta_archivo
                      ? <a href={`/documentos/${e.id}`} rel="noreferrer" target="_blank">{e.nombre_archivo}</a>
                      : e?.nombre_archivo}
                  </td>
                  <td>
                    <span className={`sga-estado-doc sga-estado-${estado.toLowerCase()}`}>{estadosDocumento[estado] ?? estado}</span>
                    {estado === "RECHAZADO" && e?.observaciones && <div className="sga-observacion">Motivo: {e.observaciones}</div>}
                  </td>
                  <td className="sga-acciones-doc">
                    {puedeSubir && (
                      <form action={subirDocumento}>
                        <input name="documento_id" type="hidden" value={r.id} />
                        <input accept={aceptados} aria-label={`Archivo para ${r.nombre}`} name="archivo" required type="file" />
                        <button type="submit">{estado === "NO_CARGADO" ? "Subir" : "Reemplazar"}</button>
                      </form>
                    )}
                    {puedeEliminar && (
                      <form action={eliminarDocumento}>
                        <input name="documento_id" type="hidden" value={r.id} />
                        <button className="sga-boton-peligro" type="submit">Eliminar</button>
                      </form>
                    )}
                    {!puedeSubir && <span className="sga-vacio">Sin acciones</span>}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
