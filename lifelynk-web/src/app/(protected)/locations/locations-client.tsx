"use client";

import {
  useState,
  useMemo,
  useCallback,
  useEffect,
} from "react";

import {
  MapPin,
  Map as MapIcon,
  Building,
  Building2,
  Droplets,
  Phone,
  Navigation,
  Mail,
  AlertCircle,
  Search,
  X,
} from "lucide-react";

import type { LocationsData } from "@/lib/dashboard/get-locations-data";
import type { CurrentUser } from "@/lib/auth/get-current-user";

/* =========================================================
   TYPES
   ========================================================= */

interface LocationsClientProps {
  data: LocationsData;
  currentUser: CurrentUser;
}

type MapOrganization = {
  id: string;
  name: string;
  organization_type: string;
  phone: string;
  email: string | null;
  address: string;
  verification_status: string;
  city_id: string;
  cityName: string;
  latitude: number;
  longitude: number;
  x: number;
  y: number;
};

type GeoJSONPosition = [number, number];

type GeoJSONGeometry = {
  type:
    | "Polygon"
    | "MultiPolygon"
    | "LineString"
    | "MultiLineString"
    | "Point"
    | "MultiPoint";
  coordinates: unknown;
};

type GeoJSONFeature = {
  type: "Feature";
  properties: {
    NAME_1?: string;
    [key: string]: unknown;
  };
  geometry: GeoJSONGeometry;
};

type PakistanGeoJSON = {
  type: "FeatureCollection";
  features: GeoJSONFeature[];
};

type ProvinceGeoShape = {
  id: string;
  name: string;
  path: string;
  labelX: number;
  labelY: number;
};

/* =========================================================
   MAP PROJECTION
   ========================================================= */

const MAP_MIN_LNG = 60;
const MAP_MAX_LNG = 78;
const MAP_MIN_LAT = 23;
const MAP_MAX_LAT = 37.5;

const VIEW_W = 500;
const VIEW_H = 480;

function projectX(lng: number): number {
  return (
    ((lng - MAP_MIN_LNG) /
      (MAP_MAX_LNG - MAP_MIN_LNG)) *
    VIEW_W
  );
}

function projectY(lat: number): number {
  return (
    ((MAP_MAX_LAT - lat) /
      (MAP_MAX_LAT - MAP_MIN_LAT)) *
    VIEW_H
  );
}

/* =========================================================
   GEOJSON HELPERS
   ========================================================= */

function coordinatesToPath(
  coordinates: GeoJSONPosition[],
): string {
  if (!coordinates.length) {
    return "";
  }

  return (
    coordinates
      .map(([lng, lat], index) => {
        const x = projectX(lng);
        const y = projectY(lat);

        return `${index === 0 ? "M" : "L"}${x.toFixed(
          2,
        )},${y.toFixed(2)}`;
      })
      .join(" ") + " Z"
  );
}

function geometryToPath(
  geometry: GeoJSONGeometry,
): string {
  if (geometry.type === "Polygon") {
    const polygons =
      geometry.coordinates as GeoJSONPosition[][];

    return polygons
      .map((ring) => coordinatesToPath(ring))
      .join(" ");
  }

  if (geometry.type === "MultiPolygon") {
    const polygons =
      geometry.coordinates as GeoJSONPosition[][][];

    return polygons
      .map((polygon) =>
        polygon
          .map((ring) =>
            coordinatesToPath(ring),
          )
          .join(" "),
      )
      .join(" ");
  }

  return "";
}

function geometryCenter(
  geometry: GeoJSONGeometry,
): {
  lng: number;
  lat: number;
} {
  const points: GeoJSONPosition[] = [];

  if (geometry.type === "Polygon") {
    const polygons =
      geometry.coordinates as GeoJSONPosition[][];

    for (const ring of polygons) {
      for (const point of ring) {
        points.push(point);
      }
    }
  }

  if (geometry.type === "MultiPolygon") {
    const polygons =
      geometry.coordinates as GeoJSONPosition[][][];

    for (const polygon of polygons) {
      for (const ring of polygon) {
        for (const point of ring) {
          points.push(point);
        }
      }
    }
  }

  if (!points.length) {
    return {
      lng: 69,
      lat: 30,
    };
  }

  let lngTotal = 0;
  let latTotal = 0;

  for (const [lng, lat] of points) {
    lngTotal += lng;
    latTotal += lat;
  }

  return {
    lng: lngTotal / points.length,
    lat: latTotal / points.length,
  };
}

/* =========================================================
   PROVINCE NORMALIZATION / ALIASES
   ========================================================= */

function normalizeProvinceName(
  value: string,
): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[._-]+/g, " ")
    .replace(/\s+/g, " ");
}

const PROVINCE_ALIASES: Record<
  string,
  string[]
> = {
  punjab: [
    "punjab",
  ],

  sindh: [
    "sindh",
    "sind",
  ],

  balochistan: [
    "balochistan",
    "baluchistan",
    "baloch",
  ],

  "khyber pakhtunkhwa": [
    "khyber pakhtunkhwa",
    "khyber-pakhtunkhwa",
    "kpk",
    "kp",
    "khyber",
    "north west frontier province",
    "north-west frontier province",
    "nwfp",
    "n.w.f.p.",
  ],

  "gilgit baltistan": [
    "gilgit baltistan",
    "gilgit-baltistan",
    "gilgit",
    "gb",
    "northern areas",
    "northern area",
  ],

  "azad kashmir": [
    "azad kashmir",
    "azad jammu and kashmir",
    "azad jammu & kashmir",
    "ajk",
    "kashmir",
  ],

  islamabad: [
    "islamabad",
    "islamabad capital territory",
    "ict",
    "capital territory",
    "federal capital",
    "f.c.t.",
  ],
};

function getCanonicalProvinceName(
  provinceName: string,
): string {
  const normalized =
    normalizeProvinceName(provinceName);

  for (const [
    canonical,
    aliases,
  ] of Object.entries(
    PROVINCE_ALIASES,
  )) {
    if (
      aliases.some(
        (alias) =>
          normalizeProvinceName(alias) ===
          normalized,
      )
    ) {
      return canonical;
    }
  }

  return normalized;
}

function provinceNamesMatch(
  first: string,
  second: string,
): boolean {
  return (
    getCanonicalProvinceName(first) ===
    getCanonicalProvinceName(second)
  );
}

function findProvinceByName(
  provinces: LocationsData["provinces"],
  provinceName: string,
) {
  return provinces.find((province) =>
    provinceNamesMatch(
      province.name,
      provinceName,
    ),
  );
}

/* =========================================================
   ORGANIZATION HELPERS
   ========================================================= */

function organizationIsHospital(
  organizationType: string,
): boolean {
  return (
    organizationType.toUpperCase() ===
    "HOSPITAL"
  );
}

function organizationIsBloodBank(
  organizationType: string,
): boolean {
  return (
    organizationType.toUpperCase() ===
    "BLOOD_BANK"
  );
}

/* =========================================================
   CLIENT COMPONENT
   ========================================================= */

export default function LocationsClient({
  data,
}: LocationsClientProps) {
  const [selectedProvinceId, setSelectedProvinceId] =
    useState<string | null>(null);

  const [selectedCityId, setSelectedCityId] =
    useState<string | null>(null);

  const [hoveredCity, setHoveredCity] =
    useState<string | null>(null);

  const [
    hoveredOrganizationId,
    setHoveredOrganizationId,
  ] = useState<string | null>(null);

  const [
    geoJson,
    setGeoJson,
  ] = useState<PakistanGeoJSON | null>(null);

  const {
    provinces,
    cities,
    organizations,
    summary,
  } = data;

  /* =======================================================
     LOAD REAL PAKISTAN GEOJSON
     ======================================================= */

  useEffect(() => {
    let cancelled = false;

    async function loadPakistanMap() {
      try {
        const response = await fetch(
          "/data/pakistan-provinces.json",
        );

        if (!response.ok) {
          throw new Error(
            `Failed to load Pakistan map: ${response.status}`,
          );
        }

        const json =
          (await response.json()) as PakistanGeoJSON;

        if (!cancelled) {
          setGeoJson(json);
        }
      } catch (error) {
        console.error(
          "[Locations] Failed to load Pakistan GeoJSON:",
          error,
        );
      }
    }

    loadPakistanMap();

    return () => {
      cancelled = true;
    };
  }, []);

  /* =======================================================
     CONVERT GEOJSON INTO SVG PROVINCE SHAPES
     ======================================================= */

  const provinceShapes = useMemo<
    ProvinceGeoShape[]
  >(() => {
    if (!geoJson) {
      return [];
    }

    return geoJson.features
      .map((feature, index) => {
        const name =
          feature.properties.NAME_1 ??
          `Province ${index + 1}`;

        const path = geometryToPath(
          feature.geometry,
        );

        const center = geometryCenter(
          feature.geometry,
        );

        return {
          id: `${name}-${index}`,
          name,
          path,
          labelX: projectX(center.lng),
          labelY: projectY(center.lat),
        };
      })
      .filter(
        (shape) => shape.path.length > 0,
      );
  }, [geoJson]);

  /* =======================================================
     LOOKUP MAPS
     ======================================================= */

  const cityMap = useMemo(() => {
    const map = new Map<string, string>();

    for (const city of cities) {
      map.set(city.id, city.name);
    }

    return map;
  }, [cities]);

  const cityDataMap = useMemo(() => {
    const map = new Map<
      string,
      (typeof cities)[number]
    >();

    for (const city of cities) {
      map.set(city.id, city);
    }

    return map;
  }, [cities]);

  const provinceMap = useMemo(() => {
    const map = new Map<string, string>();

    for (const province of provinces) {
      map.set(province.id, province.name);
    }

    return map;
  }, [provinces]);

  /* =======================================================
     FILTERED CITIES
     ======================================================= */

  const filteredCities = useMemo(() => {
    if (!selectedProvinceId) {
      return [];
    }

    return cities.filter(
      (city) =>
        city.province_id ===
        selectedProvinceId,
    );
  }, [
    cities,
    selectedProvinceId,
  ]);

  /* =======================================================
     FILTERED ORGANIZATIONS
     ======================================================= */

  const filteredOrgs = useMemo(() => {
    if (selectedCityId) {
      return organizations.filter(
        (organization) =>
          organization.city_id ===
          selectedCityId,
      );
    }

    if (selectedProvinceId) {
      const provinceCityIds = new Set(
        filteredCities.map(
          (city) => city.id,
        ),
      );

      return organizations.filter(
        (organization) =>
          provinceCityIds.has(
            organization.city_id,
          ),
      );
    }

    return organizations;
  }, [
    organizations,
    selectedProvinceId,
    selectedCityId,
    filteredCities,
  ]);

  /* =======================================================
     SELECTED NAMES
     ======================================================= */

  const selectedProvinceName =
    selectedProvinceId
      ? provinceMap.get(
          selectedProvinceId,
        ) ?? "Province"
      : "All Provinces";

  const selectedCityName = selectedCityId
    ? cityMap.get(selectedCityId) ??
      "City"
    : null;

  /* =======================================================
     HANDLERS
     ======================================================= */

  const handleProvinceSelect =
    useCallback(
      (provinceId: string | null) => {
        setSelectedProvinceId(
          provinceId,
        );
        setSelectedCityId(null);
        setHoveredCity(null);
        setHoveredOrganizationId(null);
      },
      [],
    );

  const handleCitySelect =
    useCallback(
      (cityId: string | null) => {
        setSelectedCityId(cityId);
        setHoveredOrganizationId(null);
      },
      [],
    );

  const handleMapProvinceClick =
    useCallback(
      (provinceName: string) => {
        const found =
          findProvinceByName(
            provinces,
            provinceName,
          );

        if (!found) {
          console.warn(
            `[Locations] Province not found for map name: "${provinceName}"`,
          );
          return;
        }

        handleProvinceSelect(
          found.id,
        );
      },
      [
        provinces,
        handleProvinceSelect,
      ],
    );

  const handleOrganizationClick =
    useCallback(
      (
        organization: MapOrganization,
      ) => {
        setSelectedCityId(
          organization.city_id,
        );

        const city =
          cityDataMap.get(
            organization.city_id,
          );

        if (city) {
          setSelectedProvinceId(
            city.province_id,
          );
        }

        setHoveredOrganizationId(null);
      },
      [cityDataMap],
    );

  /* =======================================================
     CITY ORGANIZATION COUNTS
     ======================================================= */

  const cityOrgCounts = useMemo(() => {
    const counts = new Map<
      string,
      number
    >();

    for (const organization of organizations) {
      counts.set(
        organization.city_id,
        (counts.get(
          organization.city_id,
        ) ?? 0) + 1,
      );
    }

    return counts;
  }, [organizations]);

  /* =======================================================
     MAP CITIES
     ======================================================= */

  const mapCities = useMemo(() => {
    const source = selectedProvinceId
      ? filteredCities
      : cities;

    return source
      .filter(
        (city) =>
          city.latitude != null &&
          city.longitude != null,
      )
      .map((city) => ({
        ...city,
        x: projectX(
          city.longitude!,
        ),
        y: projectY(
          city.latitude!,
        ),
        orgCount:
          cityOrgCounts.get(
            city.id,
          ) ?? 0,
      }));
  }, [
    cities,
    filteredCities,
    selectedProvinceId,
    cityOrgCounts,
  ]);

  /* =======================================================
     MAP ORGANIZATIONS
     ======================================================= */

  const mapOrganizations =
    useMemo(() => {
      const source = selectedProvinceId
        ? filteredOrgs
        : organizations;

      const sameCityCounters =
        new Map<string, number>();

      const result: MapOrganization[] =
        [];

      for (const organization of source) {
        const city =
          cityDataMap.get(
            organization.city_id,
          );

        if (
          !city ||
          city.latitude == null ||
          city.longitude == null
        ) {
          continue;
        }

        const existingCount =
          sameCityCounters.get(
            organization.city_id,
          ) ?? 0;

        sameCityCounters.set(
          organization.city_id,
          existingCount + 1,
        );

        const offsets = [
          [0, 0],
          [0.22, -0.16],
          [-0.22, -0.16],
          [0.22, 0.16],
          [-0.22, 0.16],
          [0, -0.26],
          [0, 0.26],
        ];

        const offset =
          offsets[
            existingCount %
              offsets.length
          ];

        const longitude =
          city.longitude! +
          offset[0];

        const latitude =
          city.latitude! +
          offset[1];

        result.push({
          ...organization,
          cityName: city.name,
          latitude,
          longitude,
          x: projectX(longitude),
          y: projectY(latitude),
        });
      }

      return result;
    }, [
      organizations,
      filteredOrgs,
      selectedProvinceId,
      cityDataMap,
    ]);

  /* =======================================================
     EMPTY STATE
     ======================================================= */

  if (provinces.length === 0) {
    return (
      <div className="locations-page">
        <div className="locations-error">
          <div className="locations-error__icon">
            <AlertCircle />
          </div>

          <p className="locations-error__title">
            No locations available
          </p>

          <p className="locations-error__desc">
            Location data has not been
            configured yet. Please contact
            your system administrator.
          </p>
        </div>
      </div>
    );
  }

  /* =======================================================
     RENDER
     ======================================================= */

  return (
    <div className="locations-page">
      {/* =================================================
          HEADER
          ================================================= */}

      <section className="locations-header locations-fade-in locations-fade-in--1">
        <div className="locations-header__content">
          <p className="locations-header__eyebrow">
            <MapPin />
            GEOGRAPHIC OVERVIEW
          </p>

          <h2>Locations</h2>

          <p className="locations-header__desc">
            Geographic overview of LifeLynk
            healthcare resources across
            provinces and cities.
          </p>
        </div>
      </section>

      {/* =================================================
          SUMMARY STATS
          ================================================= */}

      <section className="locations-stats locations-fade-in locations-fade-in--2">
        <article className="locations-stat">
          <div className="locations-stat__icon">
            <MapIcon />
          </div>

          <div className="locations-stat__content">
            <p className="locations-stat__label">
              Provinces
            </p>

            <strong className="locations-stat__value">
              {summary.totalProvinces}
            </strong>
          </div>

          <span className="locations-stat__badge">
            Active
          </span>
        </article>

        <article className="locations-stat">
          <div className="locations-stat__icon">
            <Building />
          </div>

          <div className="locations-stat__content">
            <p className="locations-stat__label">
              Cities
            </p>

            <strong className="locations-stat__value">
              {summary.totalCities}
            </strong>
          </div>

          <span className="locations-stat__badge">
            Mapped
          </span>
        </article>

        <article className="locations-stat">
          <div className="locations-stat__icon">
            <Building2 />
          </div>

          <div className="locations-stat__content">
            <p className="locations-stat__label">
              Hospitals
            </p>

            <strong className="locations-stat__value">
              {summary.totalHospitals}
            </strong>
          </div>

          <span className="locations-stat__badge">
            Verified
          </span>
        </article>

        <article className="locations-stat">
          <div className="locations-stat__icon">
            <Droplets />
          </div>

          <div className="locations-stat__content">
            <p className="locations-stat__label">
              Blood Banks
            </p>

            <strong className="locations-stat__value">
              {summary.totalBloodBanks}
            </strong>
          </div>

          <span className="locations-stat__badge">
            Verified
          </span>
        </article>
      </section>

      {/* =================================================
          MAP + EXPLORER
          ================================================= */}

      <section className="locations-map-section locations-fade-in locations-fade-in--3">
        {/* =================================================
            MAP
            ================================================= */}

        <div className="locations-map">
          <div className="locations-map__header">
            <div>
              <p className="locations-map__eyebrow">
                INTERACTIVE MAP
              </p>

              <h3 className="locations-map__title">
                Pakistan Healthcare
                Network
              </h3>
            </div>
          </div>

          <div className="locations-map__canvas">
            {!geoJson ? (
              <div
                style={{
                  width: "100%",
                  height: "100%",
                  minHeight: 480,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#8a96a7",
                  fontSize: 13,
                }}
              >
                Loading Pakistan map…
              </div>
            ) : (
              <svg
                className="locations-map__svg"
                viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
                preserveAspectRatio="xMidYMid meet"
              >
                {/* =========================================
                    REAL PAKISTAN GEOJSON PROVINCES
                    ========================================= */}

                {provinceShapes.map(
                  (shape) => {
                    const matchedProvince =
                      findProvinceByName(
                        provinces,
                        shape.name,
                      );

                    const isActive =
                      matchedProvince &&
                      selectedProvinceId ===
                        matchedProvince.id;

                    return (
                      <g
                        key={shape.id}
                        className="locations-map__province"
                      >
                        <path
                          d={shape.path}
                          className={`locations-map__province-path${
                            isActive
                              ? " locations-map__province-path--active"
                              : ""
                          }`}
                          onClick={() => {
                            if (
                              matchedProvince
                            ) {
                              handleMapProvinceClick(
                                matchedProvince.name,
                              );
                            }
                          }}
                          role="button"
                          tabIndex={0}
                          aria-label={`Select ${shape.name}`}
                          onKeyDown={(
                            event,
                          ) => {
                            if (
                              event.key ===
                                "Enter" ||
                              event.key ===
                                " "
                            ) {
                              event.preventDefault();

                              if (
                                matchedProvince
                              ) {
                                handleMapProvinceClick(
                                  matchedProvince.name,
                                );
                              }
                            }
                          }}
                        />

                        {/* Province label */}

                        <text
                          x={shape.labelX}
                          y={shape.labelY}
                          className="locations-map__province-label"
                        >
                          {shape.name ===
                          "Baluchistan"
                            ? "Balochistan"
                            : shape.name ===
                                "N.W.F.P."
                              ? "KPK"
                              : shape.name ===
                                  "Northern Areas"
                                ? "Gilgit-Baltistan"
                                : shape.name ===
                                    "F.A.T.A."
                                  ? "FATA"
                                  : shape.name ===
                                      "F.C.T."
                                    ? "Islamabad"
                                    : shape.name}
                        </text>
                      </g>
                    );
                  },
                )}

                {/* =========================================
                    CITY MARKERS
                    ========================================= */}

                {mapCities.map((city) => {
                  const isActive =
                    selectedCityId ===
                    city.id;

                  const isHovered =
                    hoveredCity ===
                    city.id;

                  const radius =
                    city.orgCount > 0
                      ? Math.min(
                          4 +
                            city.orgCount *
                              1.5,
                          12,
                        )
                      : 3;

                  return (
                    <g key={city.id}>
                      <circle
                        cx={city.x}
                        cy={city.y}
                        r={
                          isActive ||
                          isHovered
                            ? radius + 3
                            : radius
                        }
                        className={`locations-map__city-marker${
                          isActive
                            ? " locations-map__city-marker--active"
                            : ""
                        }`}
                        onClick={() =>
                          handleCitySelect(
                            city.id,
                          )
                        }
                        onMouseEnter={() =>
                          setHoveredCity(
                            city.id,
                          )
                        }
                        onMouseLeave={() =>
                          setHoveredCity(
                            null,
                          )
                        }
                      />

                      {(isActive ||
                        isHovered) && (
                        <text
                          x={city.x}
                          y={
                            city.y -
                            radius -
                            8
                          }
                          className="locations-map__city-label"
                          style={{
                            fontSize:
                              "10px",
                            fontWeight: 700,
                            fill: "#172033",
                          }}
                        >
                          {city.name}

                          {city.orgCount >
                            0 &&
                            ` (${city.orgCount})`}
                        </text>
                      )}
                    </g>
                  );
                })}

                {/* =========================================
                    HEALTHCARE ORGANIZATION MARKERS
                    ========================================= */}

                {mapOrganizations.map(
                  (organization) => {
                    const isHospital =
                      organizationIsHospital(
                        organization.organization_type,
                      );

                    const isBloodBank =
                      organizationIsBloodBank(
                        organization.organization_type,
                      );

                    const isHovered =
                      hoveredOrganizationId ===
                      organization.id;

                    const isSelected =
                      selectedCityId ===
                      organization.city_id;

                    const markerClass =
                      isHospital
                        ? "locations-map__organization-marker locations-map__organization-marker--hospital"
                        : "locations-map__organization-marker locations-map__organization-marker--bloodbank";

                    return (
                      <g
                        key={
                          organization.id
                        }
                        className="locations-map__organization"
                        onClick={() =>
                          handleOrganizationClick(
                            organization,
                          )
                        }
                        onMouseEnter={() =>
                          setHoveredOrganizationId(
                            organization.id,
                          )
                        }
                        onMouseLeave={() =>
                          setHoveredOrganizationId(
                            null,
                          )
                        }
                      >
                        {(isHovered ||
                          isSelected) && (
                          <circle
                            cx={
                              organization.x
                            }
                            cy={
                              organization.y
                            }
                            r="9"
                            className="locations-map__organization-ring"
                          />
                        )}

                        <circle
                          cx={
                            organization.x
                          }
                          cy={
                            organization.y
                          }
                          r={
                            isHovered
                              ? 6
                              : 5
                          }
                          className={
                            markerClass
                          }
                        />

                        <circle
                          cx={
                            organization.x
                          }
                          cy={
                            organization.y
                          }
                          r="2"
                          className="locations-map__organization-marker-inner"
                        />

                        {isHovered && (
                          <g className="locations-map__organization-tooltip">
                            <rect
                              x={
                                organization.x -
                                72
                              }
                              y={
                                organization.y -
                                48
                              }
                              width="144"
                              height="32"
                              rx="6"
                              className="locations-map__organization-tooltip-bg"
                            />

                            <text
                              x={
                                organization.x
                              }
                              y={
                                organization.y -
                                33
                              }
                              className="locations-map__organization-tooltip-title"
                            >
                              {organization
                                .name
                                .length >
                              22
                                ? `${organization.name.slice(
                                    0,
                                    22,
                                  )}…`
                                : organization.name}
                            </text>

                            <text
                              x={
                                organization.x
                              }
                              y={
                                organization.y -
                                20
                              }
                              className="locations-map__organization-tooltip-type"
                            >
                              {isHospital
                                ? "Hospital"
                                : isBloodBank
                                  ? "Blood Bank"
                                  : "Healthcare Resource"}
                            </text>
                          </g>
                        )}
                      </g>
                    );
                  },
                )}
              </svg>
            )}
          </div>

          {/* =============================================
              LEGEND
              ============================================= */}

          <div className="locations-map__legend">
            <span className="locations-map__legend-item">
              <span className="locations-map__legend-dot locations-map__legend-dot--province" />
              Province
            </span>

            <span className="locations-map__legend-item">
              <span className="locations-map__legend-dot locations-map__legend-dot--city" />
              City
            </span>

            <span className="locations-map__legend-item">
              <span className="locations-map__legend-dot locations-map__legend-dot--hospital" />
              Hospital
            </span>

            <span className="locations-map__legend-item">
              <span className="locations-map__legend-dot locations-map__legend-dot--bloodbank" />
              Blood Bank
            </span>
          </div>
        </div>

        {/* =================================================
            LOCATION EXPLORER
            ================================================= */}

        <div className="locations-explorer">
          <div className="locations-explorer__header">
            <p className="locations-explorer__eyebrow">
              LOCATION EXPLORER
            </p>

            <h3 className="locations-explorer__title">
              {selectedCityName
                ? selectedCityName
                : selectedProvinceId
                  ? selectedProvinceName
                  : "All Locations"}
            </h3>
          </div>

          {/* =============================================
              FILTERS
              ============================================= */}

          <div className="locations-explorer__filters">
            <div className="locations-explorer__select-wrap">
              <label className="locations-explorer__select-label">
                Province
              </label>

              <select
                value={
                  selectedProvinceId ??
                  ""
                }
                onChange={(event) =>
                  handleProvinceSelect(
                    event.target.value ||
                      null,
                  )
                }
              >
                <option value="">
                  All Provinces
                </option>

                {provinces.map(
                  (province) => (
                    <option
                      key={
                        province.id
                      }
                      value={
                        province.id
                      }
                    >
                      {province.name}
                    </option>
                  ),
                )}
              </select>
            </div>

            <div className="locations-explorer__select-wrap">
              <label className="locations-explorer__select-label">
                City
              </label>

              <select
                value={
                  selectedCityId ??
                  ""
                }
                onChange={(event) =>
                  handleCitySelect(
                    event.target.value ||
                      null,
                  )
                }
                disabled={
                  !selectedProvinceId
                }
              >
                <option value="">
                  {selectedProvinceId
                    ? "All Cities"
                    : "Select province first"}
                </option>

                {filteredCities.map(
                  (city) => (
                    <option
                      key={city.id}
                      value={city.id}
                    >
                      {city.name}
                    </option>
                  ),
                )}
              </select>
            </div>
          </div>

          {/* =============================================
              ORGANIZATION LIST
              ============================================= */}

          <div className="locations-explorer__list">
            {filteredOrgs.length ===
            0 ? (
              <div className="locations-empty">
                <div className="locations-empty__icon">
                  <Search />
                </div>

                <p className="locations-empty__title">
                  {selectedCityId
                    ? "No healthcare resources in this city"
                    : selectedProvinceId
                      ? "No cities with resources in this province"
                      : "No healthcare resources registered"}
                </p>

                <p className="locations-empty__desc">
                  {selectedCityId
                    ? "No healthcare resources have been registered in this city yet."
                    : selectedProvinceId
                      ? "Healthcare resources will appear here once organizations are verified."
                      : "Verified hospitals and blood banks will appear here."}
                </p>

                {(selectedProvinceId ||
                  selectedCityId) && (
                  <button
                    type="button"
                    className="lifelynk-button lifelynk-button--primary"
                    style={{
                      marginTop:
                        "16px",
                      minHeight:
                        "38px",
                      fontSize:
                        "13px",
                    }}
                    onClick={() =>
                      handleProvinceSelect(
                        null,
                      )
                    }
                  >
                    <X
                      style={{
                        width: 14,
                        height: 14,
                      }}
                    />
                    Clear filters
                  </button>
                )}
              </div>
            ) : (
              filteredOrgs.map(
                (organization) => {
                  const isHospital =
                    organizationIsHospital(
                      organization.organization_type,
                    );

                  const isBloodBank =
                    organizationIsBloodBank(
                      organization.organization_type,
                    );

                  const cityName =
                    cityMap.get(
                      organization.city_id,
                    ) ??
                    "Unknown";

                  return (
                    <article
                      key={
                        organization.id
                      }
                      className="locations-org-card"
                    >
                      <div
                        className={`locations-org-card__icon ${
                          isHospital
                            ? "locations-org-card__icon--hospital"
                            : "locations-org-card__icon--bloodbank"
                        }`}
                      >
                        {isHospital ? (
                          <Building2 />
                        ) : (
                          <Droplets />
                        )}
                      </div>

                      <div className="locations-org-card__body">
                        <h4 className="locations-org-card__name">
                          {
                            organization.name
                          }
                        </h4>

                        <span
                          className={`locations-org-card__type ${
                            isHospital
                              ? "locations-org-card__type--hospital"
                              : "locations-org-card__type--bloodbank"
                          }`}
                        >
                          {isHospital
                            ? "Hospital"
                            : isBloodBank
                              ? "Blood Bank"
                              : organization.organization_type}
                        </span>

                        <div className="locations-org-card__details">
                          <span className="locations-org-card__detail">
                            <Phone />
                            {
                              organization.phone
                            }
                          </span>

                          {organization.email && (
                            <span className="locations-org-card__detail">
                              <Mail />
                              {
                                organization.email
                              }
                            </span>
                          )}

                          <span className="locations-org-card__detail">
                            <Navigation />
                            {
                              organization.address
                            }
                            ,{" "}
                            {
                              cityName
                            }
                          </span>
                        </div>
                      </div>
                    </article>
                  );
                },
              )
            )}
          </div>
        </div>
      </section>
    </div>
  );
}