import path from "node:path";
import { fileURLToPath } from "node:url";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingRoot: path.resolve(path.dirname(fileURLToPath(import.meta.url)), ".."),
  outputFileTracingIncludes: {
    "/api/hex-visits/batch": [
      "./data/regions/countries-medium.pbf", "./data/regions/states-medium.pbf",
      "./data/regions/suburbs-medium.pbf", "../data/regions/suburbs-medium.pbf",
      "../data/regions/countries-medium.pbf", "../data/regions/states-medium.pbf",
    ],
    "/api/debug/hex_details": [
      "./data/regions/countries-medium.pbf", "./data/regions/states-medium.pbf",
      "./data/regions/suburbs-medium.pbf", "../data/regions/suburbs-medium.pbf",
      "../data/regions/countries-medium.pbf", "../data/regions/states-medium.pbf",
    ],
    "/api/me": ["./data/powerups.json", "../data/powerups.json"],
    "/api/powerup/consume": ["./data/powerups.json", "../data/powerups.json"],
    "/api/debug/add_powerup": ["./data/powerups.json", "../data/powerups.json"],
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            // Browsers ignore this over plain HTTP, so it is a no-op in local dev.
            // `preload` is omitted deliberately: submitting to the preload list is
            // effectively irreversible.
            key: "Strict-Transport-Security",
            value: "max-age=63072000; includeSubDomains",
          },
          {
            key: "X-Frame-Options",
            value: "SAMEORIGIN",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
        ],
      },
    ];
  },
  async rewrites() {
    return [{ source: "/health", destination: "/api/health" }];
  },
};

export default nextConfig;
