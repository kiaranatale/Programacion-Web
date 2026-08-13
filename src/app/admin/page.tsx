import { EtapaPendiente } from "@/components/etapa-pendiente";

export default function AdminPage() {
  return (
    <EtapaPendiente
      titulo="Panel de administración"
      descripcion="Carreras, materias, correlatividades y usuarios. Se implementa junto con Auth y el modelo de datos."
    />
  );
}
