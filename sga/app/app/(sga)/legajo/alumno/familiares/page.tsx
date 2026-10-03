import Tabla, { SiNo } from "@/components/tabla";
import { createClient } from "@/lib/supabase/server";
import { getLegajoActual } from "@/lib/legajo";

type Familiar = {
  id: number; nombre: string; parentesco: string | null; vive: boolean | null;
  graduado_itba: boolean; email: string | null; profesion: string | null;
};

export default async function DatosFamiliares() {
  const { legajo } = await getLegajoActual();
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga").from("dato_familiar")
    .select("id, nombre, parentesco, vive, graduado_itba, email, profesion")
    .eq("legajo_id", legajo?.id ?? 0)
    .returns<Familiar[]>();

  return (
    <>
      <h3 className="sga-subtitulo">Datos familiares</h3>
      <Tabla
        columnas={["Nombre", "Parentesco", "Vive", "Graduado ITBA", "Email", "Profesión"]}
        filas={(data ?? []).map((f) => ({
          key: f.id,
          celdas: [f.nombre, f.parentesco, <SiNo key="v" valor={f.vive} />, <SiNo key="g" valor={f.graduado_itba} />, f.email, f.profesion],
        }))}
      />
    </>
  );
}
