"use client";

import { useMemo, useState } from "react";

import type {
  DashboardProvinceInventory,
} from "@/lib/dashboard/get-dashboard-data";

import PAKISTAN from "@/maps/pakistan";

interface PakistanBloodMapProps {
  provinceInventory: DashboardProvinceInventory[];
}

interface MapProvince {
  name: string;
  code: string;
  path: string;
}

interface MapLabel {
  code: string;
  x: string;
  y: string;
  name: string;
}

interface PakistanMapData {
  states: MapProvince[];
  labels: MapLabel[];
}

const pakistanMap =
  PAKISTAN as PakistanMapData;

const provinceCodeAliases: Record<
  string,
  string
> = {
  "PK-PB": "PKPB",
  "PK-SD": "PKSD",
  "PK-KP": "PKKP",
  "PK-BA": "PKBA",
  "PK-JK": "PKJK",
  "PK-IS": "PKIS",
  "PK-GB": "PKGB",

  PKPB: "PKPB",
  PKSD: "PKSD",
  PKKP: "PKKP",
  PKBA: "PKBA",
  PKJK: "PKJK",
  PKIS: "PKIS",
  PKGB: "PKGB",
};

function normalizeCode(
  code: string,
): string {
  const normalized =
    code.trim().toUpperCase();

  return (
    provinceCodeAliases[normalized] ??
    normalized
  );
}

function getInventoryLevel(
  availableUnits: number,
  maxUnits: number,
): "empty" | "low" | "medium" | "high" {
  if (availableUnits <= 0) {
    return "empty";
  }

  if (maxUnits <= 0) {
    return "empty";
  }

  const percentage =
    availableUnits / maxUnits;

  if (percentage <= 0.25) {
    return "low";
  }

  if (percentage <= 0.6) {
    return "medium";
  }

  return "high";
}

export default function PakistanBloodMap({
  provinceInventory,
}: PakistanBloodMapProps) {
  const [selectedCode, setSelectedCode] =
    useState<string | null>(null);

  const inventoryMap = useMemo(() => {
    const map = new Map<
      string,
      DashboardProvinceInventory
    >();

    for (const province of provinceInventory) {
      map.set(
        normalizeCode(province.code),
        province,
      );
    }

    return map;
  }, [provinceInventory]);

  const maxAvailableUnits = Math.max(
    ...provinceInventory.map(
      (province) =>
        province.availableUnits,
    ),
    1,
  );

  const selectedProvince =
    selectedCode
      ? inventoryMap.get(
          normalizeCode(selectedCode),
        ) ?? null
      : null;

  const totalAvailable =
    provinceInventory.reduce(
      (sum, province) =>
        sum + province.availableUnits,
      0,
    );

  const totalReserved =
    provinceInventory.reduce(
      (sum, province) =>
        sum + province.reservedUnits,
      0,
    );

  const activeProvinceCount =
    provinceInventory.filter(
      (province) =>
        province.availableUnits > 0,
    ).length;

  return (
    <div className="pakistan-blood-map">
      <div className="pakistan-blood-map__content">
        {/* MAP */}

        <div className="pakistan-blood-map__visual">
          <div className="pakistan-blood-map__legend">
            <span>
              Blood availability
            </span>

            <div>
              <i className="map-level map-level--high" />
              <small>High</small>
            </div>

            <div>
              <i className="map-level map-level--medium" />
              <small>Medium</small>
            </div>

            <div>
              <i className="map-level map-level--low" />
              <small>Low</small>
            </div>

            <div>
              <i className="map-level map-level--empty" />
              <small>No data</small>
            </div>
          </div>

          <div className="pakistan-blood-map__svg-wrapper">
            <svg
              className="pakistan-blood-map__svg"
              viewBox="0 0 1000 900"
              role="img"
              aria-label="Pakistan blood inventory map"
              preserveAspectRatio="xMidYMid meet"
            >
              <g className="pakistan-blood-map__paths">
                {pakistanMap.states.map(
                  (province) => {
                    const code =
                      normalizeCode(
                        province.code,
                      );

                    const inventory =
                      inventoryMap.get(code);

                    const availableUnits =
                      inventory?.availableUnits ??
                      0;

                    const level =
                      getInventoryLevel(
                        availableUnits,
                        maxAvailableUnits,
                      );

                    const isSelected =
                      selectedCode === code;

                    return (
                      <path
                        key={code}
                        d={province.path}
                        className={[
                          "pakistan-blood-map__province",
                          `pakistan-blood-map__province--${level}`,
                          isSelected
                            ? "pakistan-blood-map__province--selected"
                            : "",
                        ]
                          .filter(Boolean)
                          .join(" ")}
                        tabIndex={0}
                        role="button"
                        aria-label={`${province.name}: ${availableUnits} available units`}
                        onClick={() =>
                          setSelectedCode(code)
                        }
                        onKeyDown={(event) => {
                          if (
                            event.key === "Enter" ||
                            event.key === " "
                          ) {
                            event.preventDefault();

                            setSelectedCode(code);
                          }
                        }}
                      />
                    );
                  },
                )}
              </g>

              <g className="pakistan-blood-map__labels">
                {pakistanMap.labels.map(
                  (label) => {
                    const code =
                      normalizeCode(
                        label.code,
                      );

                    const inventory =
                      inventoryMap.get(code);

                    const availableUnits =
                      inventory?.availableUnits ??
                      0;

                    return (
                      <g
                        key={label.code}
                        className={[
                          "pakistan-blood-map__label",
                          selectedCode === code
                            ? "pakistan-blood-map__label--selected"
                            : "",
                        ]
                          .filter(Boolean)
                          .join(" ")}
                        onClick={() =>
                          setSelectedCode(code)
                        }
                      >
                        <text
                          x={label.x}
                          y={label.y}
                        >
                          {label.name}
                        </text>

                        {inventory && (
                          <text
                            x={label.x}
                            y={
                              Number(label.y) + 15
                            }
                            className="pakistan-blood-map__label-value"
                          >
                            {availableUnits}
                          </text>
                        )}
                      </g>
                    );
                  },
                )}
              </g>
            </svg>
          </div>
        </div>

        {/* DETAILS */}

        <aside className="pakistan-blood-map__details">
          {selectedProvince ? (
            <>
              <div className="pakistan-blood-map__selected-header">
                <div>
                  <span>
                    SELECTED REGION
                  </span>

                  <h4>
                    {selectedProvince.name}
                  </h4>
                </div>

                <button
                  type="button"
                  aria-label="Close selected province"
                  onClick={() =>
                    setSelectedCode(null)
                  }
                >
                  ×
                </button>
              </div>

              <div className="pakistan-blood-map__selected-code">
                {selectedProvince.code}
              </div>

              <div className="pakistan-blood-map__numbers">
                <div>
                  <span>Available</span>

                  <strong>
                    {
                      selectedProvince.availableUnits
                    }
                  </strong>

                  <small>units</small>
                </div>

                <div>
                  <span>Reserved</span>

                  <strong>
                    {
                      selectedProvince.reservedUnits
                    }
                  </strong>

                  <small>units</small>
                </div>

                <div>
                  <span>Total</span>

                  <strong>
                    {
                      selectedProvince.totalUnits
                    }
                  </strong>

                  <small>units</small>
                </div>
              </div>

              <div className="pakistan-blood-map__progress">
                <div>
                  <span>
                    Share of network availability
                  </span>

                  <b>
                    {totalAvailable > 0
                      ? Math.round(
                          (selectedProvince.availableUnits /
                            totalAvailable) *
                            100,
                        )
                      : 0}
                    %
                  </b>
                </div>

                <span>
                  <i
                    style={{
                      width: `${
                        totalAvailable > 0
                          ? Math.max(
                              (selectedProvince.availableUnits /
                                totalAvailable) *
                                100,
                              2,
                            )
                          : 0
                      }%`,
                    }}
                  />
                </span>
              </div>
            </>
          ) : (
            <>
              <div className="pakistan-blood-map__details-heading">
                <span>
                  NATIONAL NETWORK
                </span>

                <h4>
                  Blood availability
                </h4>

                <p>
                  Select a province on the map
                  to inspect its current
                  inventory.
                </p>
              </div>

              <div className="pakistan-blood-map__network-total">
                <span>
                  Available nationwide
                </span>

                <strong>
                  {totalAvailable}
                </strong>

                <small>
                  blood units
                </small>
              </div>

              <div className="pakistan-blood-map__network-stats">
                <div>
                  <span>
                    Active regions
                  </span>

                  <strong>
                    {activeProvinceCount}
                  </strong>
                </div>

                <div>
                  <span>
                    Reserved
                  </span>

                  <strong>
                    {totalReserved}
                  </strong>
                </div>

                <div>
                  <span>
                    Regions tracked
                  </span>

                  <strong>
                    {provinceInventory.length}
                  </strong>
                </div>
              </div>
            </>
          )}
        </aside>
      </div>
    </div>
  );
}

