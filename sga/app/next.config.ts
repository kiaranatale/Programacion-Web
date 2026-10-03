import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // La carga de documentación admite archivos de hasta 5 MB (más el
    // resto del formulario). El bucket de Storage tiene el mismo límite.
    serverActions: { bodySizeLimit: "6mb" },
  },
};

export default nextConfig;
