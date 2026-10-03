import Tabla from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { fecha, getLegajoActual } from "@/lib/legajo";

type Excepcion = { id: number; tipo: string; descripcion: string; fecha: string };

export default async function Excepciones() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga").from("excepcion")
    .select("id, tipo, descripcion, fecha")
    .eq("legajo_id", legajo?.id ?? 0)
    .order("fecha", { ascending: false })
    .returns<Excepcion[]>();

  return (
    <>
      <h3 className="sga-subtitulo">Histórico de excepciones</h3>
      <Tabla
        columnas={["Fecha", "Tipo", "Descripción"]}
        filas={(data ?? []).map((e) => ({ key: e.id, celdas: [fecha(e.fecha), e.tipo, e.descripcion] }))}
      />
    </>
  );
}
