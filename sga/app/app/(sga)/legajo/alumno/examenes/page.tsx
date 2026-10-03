import Tabla from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual } from "@/lib/legajo";

type Examen = { id: number; codigo: string; nombre: string; intentos_maximos: number };
type Intento = { examen_especial_id: number; aprobado: boolean | null; fecha_vencimiento: string | null };

export default async function ExamenesHabilitados() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const [{ data: examenes }, { data: intentos }] = await Promise.all([
    sga.from("examen_especial").select("id, codigo, nombre, intentos_maximos").order("codigo").returns<Examen[]>(),
    sga.from("examen_especial_intento").select("examen_especial_id, aprobado, fecha_vencimiento")
      .eq("legajo_id", legajo?.id ?? 0).returns<Intento[]>(),
  ]);

  return (
    <>
      <h3 className="sga-subtitulo">Exámenes habilitados</h3>
      <Tabla
        columnas={["Código", "Nombre", "Exámenes restantes", "Estado", "Válido hasta"]}
        filas={(examenes ?? []).map((e) => {
          const propios = (intentos ?? []).filter((i) => i.examen_especial_id === e.id);
          const aprobado = propios.find((i) => i.aprobado);
          return {
            key: e.id,
            celdas: [
              e.codigo,
              e.nombre,
              aprobado ? "—" : e.intentos_maximos - propios.length,
              aprobado ? <span className="sga-aprobado" key="e">Aprobado</span> : propios.length > 0 ? "Desaprobado" : "Pendiente",
              aprobado?.fecha_vencimiento ? fecha(aprobado.fecha_vencimiento) : "",
            ],
          };
        })}
      />
    </>
  );
}
