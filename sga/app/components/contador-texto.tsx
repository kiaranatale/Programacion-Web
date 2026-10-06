"use client";

import { useState } from "react";

type Props = { id: string; name: string; maximo: number; rows?: number; required?: boolean };

// Textarea con "Quedan: N caracteres", como en el SGA.
export default function ContadorTexto({ id, name, maximo, rows, required }: Props) {
  const [largo, setLargo] = useState(0);
  return (
    <div>
      <textarea id={id} maxLength={maximo} name={name} onChange={(e) => setLargo(e.target.value.length)} required={required} rows={rows} />
      <div className="sga-ayuda" aria-live="polite">Quedan: {maximo - largo} caracteres</div>
    </div>
  );
}
