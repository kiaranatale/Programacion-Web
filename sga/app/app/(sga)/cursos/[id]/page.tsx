import { createClient } from "@/lib/supabase/server";

type Docente = {
  docente_id: number;
  apellido: string;
  nombre: string;
  mail_institucional: string;
  cargo: string | null;
  responsable: boolean;
};

function SinFoto() {
  return (
    <div className="sga-foto sga-foto-docente" aria-label="Imagen no disponible">
      <svg viewBox="0 0 64 48" aria-hidden="true">
        <rect height="26" rx="3" width="40" x="12" y="14" />
        <rect height="6" width="12" x="18" y="9" />
        <circle cx="32" cy="27" fill="#f1f3f6" r="8" />
      </svg>
      <span>Imagen no disponible</span>
    </div>
  );
}

// Plantel docente: responsable y docentes de las comisiones con su cargo.
export default async function PlantelDocente({ params }: PageProps<"/cursos/[id]">) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase
    .schema("sga")
    .from("curso_plantel")
    .select("docente_id, apellido, nombre, mail_institucional, cargo, responsable")
    .eq("curso_id", Number(id))
    .order("apellido")
    .returns<Docente[]>();

  const plantel = data ?? [];
  const responsables = plantel.filter((d) => d.responsable);
  const docentes = plantel.filter((d) => d.cargo !== null);

  if (plantel.length === 0) return <p className="sga-vacio">Este curso todavía no tiene plantel docente cargado.</p>;

  return (
    <>
      <p className="sga-texto"><strong>Responsable:</strong></p>
      <p className="sga-texto">
        {responsables.length > 0 ? responsables.map((d) => `${d.apellido}, ${d.nombre}`).join(" / ") : "Sin responsable asignado"}
      </p>
      <ul className="sga-plantel">
        {docentes.map((d) => (
          <li key={d.docente_id}>
            <SinFoto />
            <span>
              {d.apellido}, {d.nombre} ( {d.cargo} ) -{" "}
              <a href={`mailto:${d.mail_institucional}`}>{d.mail_institucional}</a>
            </span>
          </li>
        ))}
      </ul>
    </>
  );
}
