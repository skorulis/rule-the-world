import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { decode } from "geobuf";
import { latLngToCell } from "h3-js";
import Pbf from "pbf";
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
    this.minLongitude = points.reduce((min, p) => Math.min(min, p.longitude), Infinity);
    this.maxLongitude = points.reduce((max, p) => Math.max(max, p.longitude), -Infinity);
    this.minLatitude = points.reduce((min, p) => Math.min(min, p.latitude), Infinity);
    this.maxLatitude = points.reduce((max, p) => Math.max(max, p.latitude), -Infinity);
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

type Region = { id: bigint; kind: string; parent?: bigint; polygons: Polygon[] };

type FeatureCollection = {
  type: string;
  features: {
    type: string;
    properties: { id: string; name: string; kind: string; parent?: string };
    geometry: { type: string; coordinates: number[][][] | number[][][][] };
  }[];
};

function parsePoint(value: unknown): Point {
  if (!Array.isArray(value) || value.length !== 2) throw new Error("Invalid region point");
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
    if (feature.type !== "Feature" || typeof feature.properties.id !== "string" || !/^\d+$/.test(feature.properties.id)
      || typeof feature.properties.name !== "string" || !["country", "state", "suburb"].includes(feature.properties.kind)
      || (parent !== undefined && (typeof parent !== "string" || !/^\d+$/.test(parent))) || !rawPolygons?.length) {
      throw new Error("Invalid region collection");
    }
    const polygons = rawPolygons.map((rings) => {
      const [exterior, ...holes] = rings.map((ring) => new Ring(ring.map(parsePoint)));
      if (!exterior) throw new Error("Invalid region ring");
      return new Polygon(exterior, holes);
    });
    return {
      id: BigInt(feature.properties.id),
      kind: feature.properties.kind,
      parent: parent === undefined ? undefined : BigInt(parent),
      polygons,
    };
  });
  if (new Set(regions.map((region) => region.id)).size !== regions.length) {
    throw new Error("Invalid region collection");
  }
  return regions.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function boundaryPath(fileName: string): string {
  const candidates = [
    ...(import.meta.url ? [path.resolve(path.dirname(fileURLToPath(import.meta.url)), `../../data/regions/${fileName}`)] : []),
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

function decodeCollection(data: Uint8Array): FeatureCollection {
  const header = new Pbf(data);
  const metadata = header.readFields((tag, metadata, pbf) => {
    if (tag === 2) metadata.dimensions = pbf.readVarint();
    if (tag === 3) metadata.precision = pbf.readVarint();
  }, { dimensions: 2, precision: 6 });
  if (header.pos !== data.length || metadata.dimensions !== 2 || metadata.precision > 6) {
    throw new Error("Invalid region encoding");
  }
  const reader = new Pbf(data);
  const collection = decode(reader) as FeatureCollection;
  if (reader.pos !== data.length) throw new Error("Invalid region encoding");
  return collection;
}

const catalogs = new Map<string, Region[]>();

function catalog(fileName: string): Region[] {
  let regions = catalogs.get(fileName);
  if (!regions) {
    regions = parseRegions(decodeCollection(readFileSync(boundaryPath(fileName))));
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

function states(parent: bigint): Region[] {
  statesByParent ??= childrenByParent("states-medium.pbf");
  return statesByParent.get(parent) ?? [];
}

type SuburbIndex = {
  shardResolution: number;
  shards: Record<string, { features: number; bytes: number; sha256: string }>;
  homes: Record<string, string>;
  coverage: Record<string, string[]>;
};

let suburbsIndex: SuburbIndex | null | undefined;

function suburbIndex(): SuburbIndex | undefined {
  if (suburbsIndex === undefined) {
    let parsed: SuburbIndex;
    try {
      parsed = JSON.parse(new TextDecoder().decode(readFileSync(boundaryPath("suburbs-index.json"))));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") {
        suburbsIndex = null;
        return undefined;
      }
      throw error;
    }
    if (typeof parsed?.shardResolution !== "number" || !parsed.shards || !parsed.homes || !parsed.coverage) {
      throw new Error("Invalid suburb shard index");
    }
    suburbsIndex = parsed;
  }
  return suburbsIndex ?? undefined;
}

const suburbShardRegions = new Map<string, Region[]>();

function suburbShard(cell: string): Region[] {
  let regions = suburbShardRegions.get(cell);
  if (!regions) {
    regions = parseRegions(decodeCollection(readFileSync(boundaryPath(`suburbs/${cell}.pbf`))));
    suburbShardRegions.set(cell, regions);
  }
  return regions;
}

function suburbCandidates(latitude: number, longitude: number): Region[] {
  const index = suburbIndex();
  const wrapped = (((longitude + 180) % 360) + 360) % 360 - 180;
  if (!index || !Number.isFinite(latitude) || !Number.isFinite(wrapped) || Math.abs(latitude) > 90) {
    return [];
  }
  const covered = index.coverage[latLngToCell(latitude, wrapped, index.shardResolution)];
  if (!covered?.length) return [];
  const wanted = new Set(covered);
  const candidates: Region[] = [];
  const homes = new Set(covered.map((id) => index.homes[id]).filter((home): home is string => home !== undefined));
  for (const home of homes) {
    for (const region of suburbShard(home)) {
      if (wanted.has(region.id.toString())) candidates.push(region);
    }
  }
  return candidates.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
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
  return catalog("countries-medium.pbf")
    .find((region) => regionContains(region, latitude, longitude))?.id ?? noRegion;
}

export function stateIdForPoint(parent: bigint, latitude: number, longitude: number): bigint {
  if (parent === noRegion) return noRegion;
  return states(parent).find((region) => regionContains(region, latitude, longitude))?.id ?? noRegion;
}

export function suburbIdForPoint(parent: bigint, latitude: number, longitude: number): bigint {
  if (parent === noRegion) return noRegion;
  return suburbCandidates(latitude, longitude)
    .find((region) => region.parent === parent && regionContains(region, latitude, longitude))?.id ?? noRegion;
}

export type RegionHierarchy = { country: bigint; state: bigint; suburb: bigint };

let statesById: Map<bigint, Region> | undefined;
let countriesById: Map<bigint, Region> | undefined;

function statesByIdMap(): Map<bigint, Region> {
  statesById ??= new Map(catalog("states-medium.pbf").map((region) => [region.id, region]));
  return statesById;
}

function countriesByIdMap(): Map<bigint, Region> {
  countriesById ??= new Map(catalog("countries-medium.pbf").map((region) => [region.id, region]));
  return countriesById;
}

export function hierarchyForPoint(latitude: number, longitude: number): RegionHierarchy {
  const region = suburbCandidates(latitude, longitude)
    .find((candidate) => regionContains(candidate, latitude, longitude));
  if (region) {
    const state = region.parent === undefined ? undefined : statesByIdMap().get(region.parent);
    const country = state?.parent === undefined ? undefined : countriesByIdMap().get(state.parent);
    if (region.kind !== "suburb" || state?.kind !== "state" || country?.kind !== "country") {
      throw new Error("Invalid suburb parent hierarchy");
    }
    return { country: country.id, state: state.id, suburb: region.id };
  }
  const country = regionIdForPoint(latitude, longitude);
  const state = stateIdForPoint(country, latitude, longitude);
  return { country, state, suburb: noRegion };
}
