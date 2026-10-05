export default function SinAcceso({ titulo }: { titulo: string }) {
  return (
    <section className="sga-panel">
      <h2 className="sga-titulo sga-titulo-grande">{titulo}</h2>
      <p className="sga-error">Esta sección es para docentes.</p>
    </section>
  );
}
