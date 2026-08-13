import Link from "next/link";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

const roles = [
  {
    title: "Alumno",
    description:
      "Inscribite a materias, consultá tus notas y tu estado de pagos.",
    href: "/alumno",
  },
  {
    title: "Profesor",
    description: "Gestioná tus cursadas y cargá notas de tus alumnos.",
    href: "/profesor",
  },
  {
    title: "Administración",
    description:
      "Administrá carreras, materias, correlatividades y usuarios.",
    href: "/admin",
  },
];

export default function Home() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-10 px-6 py-16">
      <div className="max-w-2xl text-center">
        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Sistema de Gestión Académica
        </h1>
        <p className="mt-4 text-muted-foreground">
          Inscripciones, notas y pagos en un solo lugar.
        </p>
        <div className="mt-6 flex justify-center gap-3">
          <Button asChild>
            <Link href="/login">Iniciar sesión</Link>
          </Button>
          <Button asChild variant="outline">
            <Link href="/registro">Crear cuenta</Link>
          </Button>
        </div>
      </div>

      <div className="grid w-full max-w-4xl gap-4 sm:grid-cols-3">
        {roles.map((role) => (
          <Card key={role.href}>
            <CardHeader>
              <CardTitle>{role.title}</CardTitle>
              <CardDescription>{role.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <Button asChild variant="link" className="px-0">
                <Link href="/login">Ingresar con mi cuenta →</Link>
              </Button>
            </CardContent>
          </Card>
        ))}
      </div>
    </main>
  );
}
