import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { puedeEnviar } from "@/lib/mensajes";
import { getSesion } from "@/lib/sesion";
import FormularioMensaje from "./formulario";

type ComisionRow = {
  id: number;
  nombre: string;
  curso: { anio: number; periodo: string; activo: boolean; materia: { codigo: string; nombre: string } | null } | null;
};

const etiquetaComision = (c: ComisionRow) =>
  `${c.curso?.materia?.codigo} - ${c.curso?.materia?.nombre} · Com. ${c.nombre} (${c.curso?.periodo} ${c.curso?.anio})`;

// Nuevo mensaje. Las opciones de destino dependen del rol; la base vuelve
// a verificar todo al enviar.
export default async function NuevoMensaje() {
  const sesion = await getSesion();
  if (!sesion) return null;

  if (!puedeEnviar(sesion)) {
    return (
      <section className="sga-panel">
        <h2 className="sga-titulo sga-titulo-grande">Nuevo mensaje</h2>
        <p className="sga-error">Los mensajes los envían docentes y Administración. Podés responder los que recibas.</p>
        <Link className="sga-volver" href="/usuario/mensajes">← Volver a Mensajes</Link>
      </section>
    );
  }

  const admin = sesion.roles.includes("ADMINISTRATIVO");
  const supabase = await createClient();
  const sga = supabase.schema("sga");
  const select = "id, nombre, curso:curso_id!inner(anio, periodo, activo, materia:materia_id(codigo, nombre))";

  let comisiones: ComisionRow[] = [];
  let carreras: { id: number; nombre: string }[] = [];
  if (admin) {
    const [{ data: c }, { data: ca }] = await Promise.all([
      sga.from("comision").select(select).eq("curso.activo", true).returns<ComisionRow[]>(),
      sga.from("carrera").select("id, nombre").eq("activo", true).order("nombre").returns<{ id: number; nombre: string }[]>(),
    ]);
    comisiones = c ?? [];
    carreras = ca ?? [];
  } else if (sesion.persona) {
    const { data: docente } = await sga.from("docente").select("id").eq("persona_id", sesion.persona.id).maybeSingle<{ id: number }>();
    if (docente) {
      const { data } = await sga
        .from("docente_comision")
        .select(`comision:comision_id(${select})`)
        .eq("docente_id", docente.id)
        .returns<{ comision: ComisionRow | null }[]>();
      comisiones = (data ?? []).flatMap((r) => (r.comision?.curso?.activo ? [r.comision] : []));
    }
  }
  comisiones.sort((a, b) => etiquetaComision(a).localeCompare(etiquetaComision(b)));

  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">Nuevo mensaje</h2>
      <FormularioMensaje
        admin={admin}
        carreras={carreras.map((c) => ({ valor: `CARRERA:${c.id}`, etiqueta: c.nombre }))}
        comisiones={comisiones.map((c) => ({ valor: `COMISION:${c.id}`, etiqueta: etiquetaComision(c) }))}
      />
    </section>
  );
}
