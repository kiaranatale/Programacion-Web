import Tabla, { SiNo } from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { getLegajoActual } from "@/lib/legajo";

type Requerido = { id: number; nombre: string; categoria: string; obligatoria: boolean; carrera_id: number | null; nivel: string | null };
type Entregado = { documento_requerido_id: number; nombre_archivo: string | null; estado: string };

const estados: Record<string, string> = {
  NO_CARGADO: "No cargado", CARGADO: "Pendiente de validación", VALIDADO: "Validado", RECHAZADO: "Rechazado",
};

export default async function Documentacion() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: requeridos }, { data: entregados }, { data: carrera }] = await Promise.all([
    sga.from("documento_requerido").select("id, nombre, categoria, obligatoria, carrera_id, nivel")
      .order("obligatoria", { ascending: false }).order("nombre").returns<Requerido[]>(),
    sga.from("documento_legajo").select("documento_requerido_id, nombre_archivo, estado")
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
      <Tabla
        columnas={["Documento", "Categoría", "Obligatoria", "Entregada", "Nombre del archivo", "Estado del archivo"]}
        filas={aplicables.map((r) => {
          const e = (entregados ?? []).find((x) => x.documento_requerido_id === r.id);
          const estado = e?.estado ?? "NO_CARGADO";
          return {
            key: r.id,
            celdas: [
              r.nombre, r.categoria, <SiNo key="o" valor={r.obligatoria} />,
              <SiNo key="e" valor={estado !== "NO_CARGADO"} />, e?.nombre_archivo, estados[estado] ?? estado,
            ],
          };
        })}
      />
    </>
  );
}
