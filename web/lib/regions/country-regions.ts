import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { noRegion } from "@/db/schema";

type Point = { longitude: number; latitude: number };

class Ring {
  readonly minLongitude: number;
  readonly maxLongitude: number;
  readonly minLatitude: number;
  readonly maxLatitude: number;

  constructor(readonly points: Point[]) {
    if (points.length < 4
      || points[0].longitude !== points[points.length - 1].longitude
      || points[0].latitude !== points[points.length - 1].latitude
      || !points.slice(1).every((end, i) => Math.abs(end.longitude - points[i].longitude) <= 180)) {
      throw new Error("Invalid region ring");
    }
    this.minLongitude = Math.min(...points.map((p) => p.longitude));
    this.maxLongitude = Math.max(...points.map((p) => p.longitude));
    this.minLatitude = Math.min(...points.map((p) => p.latitude));
    this.maxLatitude = Math.max(...points.map((p) => p.latitude));
  }

  contains(point: Point): boolean {
    if (point.longitude < this.minLongitude || point.longitude > this.maxLongitude
      || point.latitude < this.minLatitude || point.latitude > this.maxLatitude) return false;
    let inside = false;
    for (let i = 0; i < this.points.length - 1; i++) {
      const start = this.points[i];
      const end = this.points[i + 1];
      const dx = end.longitude - start.longitude;
      const dy = end.latitude - start.latitude;
      const cross = (point.longitude - start.longitude) * dy - (point.latitude - start.latitude) * dx;
      if (Math.abs(cross) <= 1e-10
        && point.longitude >= Math.min(start.longitude, end.longitude)
        && point.longitude <= Math.max(start.longitude, end.longitude)
        && point.latitude >= Math.min(start.latitude, end.latitude)
        && point.latitude <= Math.max(start.latitude, end.latitude)) {
        return true;
      }
      if ((start.latitude > point.latitude) !== (end.latitude > point.latitude)) {
        const intersection = start.longitude + (point.latitude - start.latitude) * dx / dy;
        if (point.longitude < intersection) inside = !inside;
      }
    }
    return inside;
  }
}

class Polygon {
  constructor(readonly exterior: Ring, readonly holes: Ring[]) {}

  contains(point: Point): boolean {
    return this.exterior.contains(point) && !this.holes.some((hole) => hole.contains(point));
  }
}

type Region = { id: bigint; parent?: bigint; polygons: Polygon[] };

type FeatureCollection = {
  type: string;
  features: {
    type: string;
    properties: { id: string; name: string; kind: string; parent?: string };
    geometry: { type: string; coordinates: number[][][] | number[][][][] };
  }[];
};

function parsePoint(value: unknown): Point {
  const [longitude, latitude] = value as number[];
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)
    || longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
    throw new Error("Invalid region ring");
  }
  return { longitude, latitude };
}

function parseRegions(collection: FeatureCollection): Region[] {
  if (collection.type !== "FeatureCollection" || !collection.features.length) {
    throw new Error("Invalid region collection");
  }
  const regions = collection.features.map((feature) => {
    const rawPolygons = feature.geometry.type === "Polygon"
      ? [feature.geometry.coordinates as number[][][]]
      : feature.geometry.type === "MultiPolygon"
        ? feature.geometry.coordinates as number[][][][]
        : null;
    const parent = feature.properties.parent;
    if (feature.type !== "Feature" || !/^\d+$/.test(feature.properties.id)
      || (parent !== undefined && !/^\d+$/.test(parent)) || !rawPolygons?.length) {
      throw new Error("Invalid region collection");
    }
    const polygons = rawPolygons.map((rings) => {
      const [exterior, ...holes] = rings.map((ring) => new Ring(ring.map(parsePoint)));
      if (!exterior) throw new Error("Invalid region ring");
      return new Polygon(exterior, holes);
    });
    return {
      id: BigInt(feature.properties.id),
      parent: parent === undefined ? undefined : BigInt(parent),
      polygons,
    };
  });
  if (new Set(regions.map((region) => region.id)).size !== regions.length) {
    throw new Error("Invalid region collection");
  }
  return regions.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function geoJsonPath(fileName: string): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  const candidates = [
    path.resolve(moduleDir, `../../data/regions/${fileName}`),
    path.resolve(process.cwd(), `data/regions/${fileName}`),
  ];
  return candidates.find((candidate) => {
    try {
      readFileSync(candidate);
      return true;
    } catch {
      return false;
    }
  }) ?? candidates[0];
}

const catalogs = new Map<string, Region[]>();

function catalog(fileName: string): Region[] {
  let regions = catalogs.get(fileName);
  if (!regions) {
    regions = parseRegions(JSON.parse(readFileSync(geoJsonPath(fileName), "utf-8")));
    catalogs.set(fileName, regions);
  }
  return regions;
}

function childrenByParent(fileName: string, optional = false): Map<bigint, Region[]> {
  let children: Region[];
  try {
    children = catalog(fileName);
  } catch (error) {
    if (optional && (error as NodeJS.ErrnoException).code === "ENOENT") return new Map();
    throw error;
  }
  const grouped = new Map<bigint, Region[]>();
  for (const child of children) {
    if (child.parent === undefined) throw new Error("Invalid region collection");
    const siblings = grouped.get(child.parent) ?? [];
    siblings.push(child);
    grouped.set(child.parent, siblings);
  }
  return grouped;
}

let statesByParent: Map<bigint, Region[]> | undefined;
let suburbsByParent: Map<bigint, Region[]> | undefined;

function states(parent: bigint): Region[] {
  statesByParent ??= childrenByParent("states-medium.geojson");
  return statesByParent.get(parent) ?? [];
}

function suburbs(parent: bigint): Region[] {
  suburbsByParent ??= childrenByParent("suburbs-medium.geojson", true);
  return suburbsByParent.get(parent) ?? [];
}

function regionContains(region: Region, latitude: number, longitude: number): boolean {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < -90 || latitude > 90) {
    return false;
  }
  const wrapped = (((longitude + 180) % 360) + 360) % 360 - 180;
  const point = { longitude: wrapped, latitude };
  return region.polygons.some((polygon) => polygon.contains(point)
    || (wrapped === -180 && polygon.contains({ longitude: 180, latitude })));
}

export function regionIdForPoint(latitude: number, longitude: number): bigint {
  return catalog("countries-medium.geojson")
    .find((region) => regionContains(region, latitude, longitude))?.id ?? noRegion;
}

export function stateIdForPoint(parent: bigint, latitude: number, longitude: number): bigint {
  if (parent === noRegion) return noRegion;
  return states(parent).find((region) => regionContains(region, latitude, longitude))?.id ?? noRegion;
}

export function suburbIdForPoint(parent: bigint, latitude: number, longitude: number): bigint {
  if (parent === noRegion) return noRegion;
  return suburbs(parent).find((region) => regionContains(region, latitude, longitude))?.id ?? noRegion;
}
