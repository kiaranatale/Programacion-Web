import Tabla from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual } from "@/lib/legajo";

type Facturable = {
  id: number; activo: boolean; fecha_desde: string; fecha_hasta: string | null;
  item: { nombre: string } | null;
};

export default async function Facturables() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga").from("item_facturable_legajo")
    .select("id, activo, fecha_desde, fecha_hasta, item:item_facturable_id(nombre)")
    .eq("legajo_id", legajo?.id ?? 0)
    .returns<Facturable[]>();

  return (
    <>
      <h3 className="sga-subtitulo">Lista de ítems activos facturables para el alumno.</h3>
      <p className="sga-texto"><strong>(Cada ítem será facturado siempre que esté activo al momento de la facturación)</strong></p>
      <Tabla
        columnas={["Ítem", "Cant.", "Desde", "Hasta", "Activo"]}
        filas={(data ?? []).map((f) => ({
          key: f.id,
          celdas: [f.item?.nombre, 1, fecha(f.fecha_desde), fecha(f.fecha_hasta), f.activo ? "Sí" : "No"],
        }))}
      />
    </>
  );
}
