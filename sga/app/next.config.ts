import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // La carga de documentación admite archivos de hasta 4 MB (más el resto
    // del formulario). Vercel no acepta pedidos de más de 4,5 MB.
    serverActions: { bodySizeLimit: "4.5mb" },
  },
};

export default nextConfig;
