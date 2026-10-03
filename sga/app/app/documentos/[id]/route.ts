import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { BUCKET_DOCUMENTACION } from "@/lib/documentacion";

// Abre un documento cargado con un link firmado de un minuto. RLS decide
// quién puede leer la fila (el alumno, la suya; Administración, todas) y
// las políticas de Storage, quién puede firmar el archivo.
export async function GET(_request: NextRequest, { params }: RouteContext<"/documentos/[id]">) {
  const id = Number((await params).id);
  if (!Number.isInteger(id)) return new NextResponse("Documento inválido", { status: 400 });

  const supabase = await createClient();
  const { data: doc } = await supabase
    .schema("sga")
    .from("documento_legajo")
    .select("ruta_archivo")
    .eq("id", id)
    .maybeSingle<{ ruta_archivo: string | null }>();

  if (!doc?.ruta_archivo) return new NextResponse("Documento no encontrado", { status: 404 });

  const { data, error } = await supabase.storage.from(BUCKET_DOCUMENTACION).createSignedUrl(doc.ruta_archivo, 60);
  if (error || !data) return new NextResponse("No se pudo abrir el documento", { status: 403 });

  return NextResponse.redirect(data.signedUrl);
}
