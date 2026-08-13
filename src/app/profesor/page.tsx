import { EtapaPendiente } from "@/components/etapa-pendiente";
import { requireRole } from "@/lib/auth";

export default async function ProfesorPage() {
  await requireRole("profesor");

  return (
    <EtapaPendiente
      titulo="Panel del profesor"
      descripcion="Cursadas asignadas y carga de notas. Se implementa junto con Auth y el modelo de datos."
    />
  );
}
