import Tabla from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual } from "@/lib/legajo";

type Inhibicion = { id: number; tipo: string; fecha_inicio: string; fecha_fin: string | null; observaciones: string | null };

const tipos: Record<string, string> = {
  ARANCEL: "Inhibición por arancel", ENCUESTA: "Inhibición por encuesta",
  DOCUMENTACION: "Inhibición por documentación", OTRO: "Otra inhibición",
};

export default async function Inhibiciones() {
  const { legajo, nombre } = await getLegajoActual();
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga").from("inhibicion")
    .select("id, tipo, fecha_inicio, fecha_fin, observaciones")
    .eq("legajo_id", legajo?.id ?? 0)
    .order("fecha_inicio", { ascending: false })
    .returns<Inhibicion[]>();

  return (
    <>
      <h3 className="sga-subtitulo">Historial de inhibiciones de {nombre} - {legajo?.numero_legajo}</h3>
      <Tabla
        columnas={["Tipo de inhibición", "Fecha de inicio", "Fecha de finalización", "Observaciones"]}
        filas={(data ?? []).map((i) => ({
          key: i.id,
          celdas: [tipos[i.tipo] ?? i.tipo, fecha(i.fecha_inicio), i.fecha_fin ? fecha(i.fecha_fin) : "Vigente", i.observaciones],
        }))}
      />
    </>
  );
}
