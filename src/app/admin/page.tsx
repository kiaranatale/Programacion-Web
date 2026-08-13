import { EtapaPendiente } from "@/components/etapa-pendiente";
import { requireRole } from "@/lib/auth";

export default async function AdminPage() {
  await requireRole("admin");

  return (
    <EtapaPendiente
      titulo="Panel de administración"
      descripcion="Carreras, materias, correlatividades y usuarios. Se implementa junto con Auth y el modelo de datos."
    />
  );
}
