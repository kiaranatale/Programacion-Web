import Link from "next/link";
import type { Publicacion } from "@/lib/hoy";

type Props = {
  action: (formData: FormData) => Promise<void>;
  cancelar: string;
  organizaciones?: { id: number; nombre: string }[];
  organizacionInicial?: number;
  publicacion?: Publicacion;
};

// Formulario de alta y edición de publicaciones. Fecha, hora y lugar solo
// se guardan para eventos.
export default function FormularioPublicacion({ action, cancelar, organizaciones, organizacionInicial, publicacion }: Props) {
  return (
    <form action={action} className="sga-form-publicacion">
      {publicacion && <input name="id" type="hidden" value={publicacion.id} />}
      <label>
        <span>Organización</span>
        {publicacion ? (
          <strong>{publicacion.organizacion}</strong>
        ) : organizaciones?.length === 1 ? (
          <>
            <input name="organizacion_id" type="hidden" value={organizaciones[0].id} />
            <strong>{organizaciones[0].nombre}</strong>
          </>
        ) : (
          // Con más de una organización no se preselecciona ninguna: hay
          // que elegir en nombre de cuál se publica.
          <select defaultValue={organizacionInicial ?? ""} name="organizacion_id" required>
            <option disabled value="">Elegí en nombre de qué organización publicás</option>
            {(organizaciones ?? []).map((o) => <option key={o.id} value={o.id}>{o.nombre}</option>)}
          </select>
        )}
      </label>
      <label>
        <span>Tipo</span>
        <select defaultValue={publicacion?.tipo ?? "NOVEDAD"} name="tipo">
          <option value="NOVEDAD">Novedad</option>
          <option value="EVENTO">Evento</option>
        </select>
      </label>
      <label>
        <span>Título</span>
        <input defaultValue={publicacion?.titulo} maxLength={150} name="titulo" required />
      </label>
      <fieldset>
        <legend>Solo para eventos</legend>
        <label>
          <span>Fecha</span>
          <input defaultValue={publicacion?.fecha_evento ?? ""} name="fecha_evento" type="date" />
        </label>
        <label>
          <span>Hora</span>
          <input defaultValue={publicacion?.hora_evento?.slice(0, 5) ?? ""} name="hora_evento" type="time" />
        </label>
        <label>
          <span>Lugar</span>
          <input defaultValue={publicacion?.lugar ?? ""} maxLength={150} name="lugar" placeholder="Aula, sede o link" />
        </label>
      </fieldset>
      <label>
        <span>Texto</span>
        <textarea defaultValue={publicacion?.cuerpo} maxLength={5000} name="cuerpo" required rows={10} />
      </label>
      <div className="sga-acciones-form">
        <button type="submit">{publicacion ? "Guardar cambios" : "Publicar"}</button>
        <Link href={cancelar}>Cancelar</Link>
      </div>
    </form>
  );
}
