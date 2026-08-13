import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export function EtapaPendiente({
  titulo,
  descripcion,
}: {
  titulo: string;
  descripcion: string;
}) {
  return (
    <main className="flex flex-1 items-center justify-center px-6 py-16">
      <Card className="max-w-md">
        <CardHeader>
          <CardTitle>{titulo}</CardTitle>
          <CardDescription>{descripcion}</CardDescription>
        </CardHeader>
        <CardContent className="text-sm text-muted-foreground">
          Esta sección se implementa en una etapa posterior del proyecto.
        </CardContent>
      </Card>
    </main>
  );
}
