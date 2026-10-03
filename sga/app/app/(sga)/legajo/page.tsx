import { createClient } from "@/lib/supabase/server";
import { fecha } from "@/lib/legajo";
import { getSesion } from "@/lib/sesion";

type Persona = {
  tipo_documento: string;
  nro_documento: string;
  cuil: string | null;
  titulo_antes_nombre: string | null;
  titulo_despues_nombre: string | null;
  nombre: string;
  apellido: string;
  genero: string | null;
  nacionalidad: string | null;
  fecha_nacimiento: string | null;
  lugar_nacimiento: string | null;
  mail_institucional: string;
  codigo_credencial: string | null;
};

const generos: Record<string, string> = { HOMBRE: "Masculino", MUJER: "Femenino", OTRO: "Otro" };

export default async function LegajoGeneral() {
  const sesion = await getSesion();
  const supabase = await createClient();
  const { data: p } = await supabase
    .schema("sga")
    .from("persona")
    .select(`tipo_documento, nro_documento, cuil, titulo_antes_nombre, titulo_despues_nombre,
      nombre, apellido, genero, nacionalidad, fecha_nacimiento, lugar_nacimiento,
      mail_institucional, codigo_credencial`)
    .eq("id", sesion?.persona?.id ?? 0)
    .maybeSingle<Persona>();

  if (!p) return null;

  const filas: [string, React.ReactNode][] = [
    [p.tipo_documento === "DNI" ? "DNI" : p.tipo_documento, p.nro_documento],
    ["C.U.I.L.", p.cuil],
    ["Título antes del Nombre", p.titulo_antes_nombre],
    ["Título después del Nombre", p.titulo_despues_nombre],
    ["Nombre", `${p.nombre} ${p.apellido}`],
    ["Sexo", p.genero ? generos[p.genero] : null],
    ["Nacionalidad", p.nacionalidad],
    ["Fecha de nacimiento", fecha(p.fecha_nacimiento)],
    ["Lugar de nacimiento", p.lugar_nacimiento],
    ["E-mail del ITBA", <a href={`mailto:${p.mail_institucional}`} key="mail">{p.mail_institucional}</a>],
    ["Código de Credencial", p.codigo_credencial],
  ];

  return (
    <>
      <h3 className="sga-subtitulo">Datos personales</h3>
      <div className="sga-foto" aria-label="Sin foto">
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <circle cx="32" cy="24" r="12" />
          <path d="M10 58c2-13 11-20 22-20s20 7 22 20z" />
        </svg>
      </div>
      <dl className="sga-datos">
        {filas.map(([etiqueta, valor]) => (
          <div key={etiqueta}>
            <dt>{etiqueta}:</dt>
            <dd>{valor}</dd>
          </div>
        ))}
      </dl>
    </>
  );
}
