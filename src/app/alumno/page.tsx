import { EtapaPendiente } from "@/components/etapa-pendiente";
import { requireRole } from "@/lib/auth";

export default async function AlumnoPage() {
  await requireRole("alumno");

  return (
    <EtapaPendiente
      titulo="Panel del alumno"
      descripcion="Inscripción a materias, notas y pagos. Se implementa junto con Auth y el modelo de datos."
    />
  );
}
