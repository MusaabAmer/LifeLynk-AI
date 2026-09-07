"use client";

import {
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";

import L from "leaflet";
import "leaflet/dist/leaflet.css";

import type { EmergencySosRecord } from "@/lib/dashboard/get-emergency-sos-data";

interface EmergencyMapProps {
  records: EmergencySosRecord[];
  selectedId?: string | null;
  onSelect?: (record: EmergencySosRecord) => void;
}

const defaultCenter: [number, number] = [
  31.5204,
  74.3587,
];

const sosIcon = L.divIcon({
  className: "lifelynk-sos-marker-wrapper",
  html: `
    <div class="lifelynk-sos-marker">
      SOS
    </div>
  `,
  iconSize: [42, 42],
  iconAnchor: [21, 21],
  popupAnchor: [0, -21],
});

function MapFocus({
  record,
}: {
  record: EmergencySosRecord | null;
}) {
  const map = useMap();

  if (
    record?.latitude !== null &&
    record?.latitude !== undefined &&
    record?.longitude !== null &&
    record?.longitude !== undefined
  ) {
    map.setView(
      [record.latitude, record.longitude],
      Math.max(map.getZoom(), 14),
      {
        animate: true,
      },
    );
  }

  return null;
}

function getPatientName(
  record: EmergencySosRecord,
): string {
  return (
    record.users?.[0]?.full_name ??
    "Unknown user"
  );
}

function getBloodGroup(
  record: EmergencySosRecord,
): string {
  return (
    record.blood_groups?.[0]?.code ??
    "Unknown"
  );
}

function getLocation(
  record: EmergencySosRecord,
): string {
  const city = record.cities?.[0];
  const province =
    city?.provinces?.[0];

  if (city && province) {
    return `${city.name}, ${province.name}`;
  }

  if (city) {
    return city.name;
  }

  return "Location unavailable";
}

export default function EmergencyMap({
  records,
  selectedId = null,
  onSelect,
}: EmergencyMapProps) {
  const selectedRecord =
    records.find(
      (record) =>
        record.id === selectedId,
    ) ?? null;

  const mappedRecords =
    records.filter(
      (record) =>
        record.latitude !== null &&
        record.longitude !== null,
    );

  return (
    <div className="emergency-map-container">
      <MapContainer
        center={defaultCenter}
        zoom={6}
        scrollWheelZoom
        className="emergency-map"
      >
        <TileLayer
          attribution='&copy; OpenStreetMap contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <MapFocus record={selectedRecord} />

        {mappedRecords.map((record) => (
          <Marker
            key={record.id}
            position={[
              record.latitude!,
              record.longitude!,
            ]}
            icon={sosIcon}
            eventHandlers={{
              click: () => {
                onSelect?.(record);
              },
            }}
          >
            <Popup>
              <div>
                <strong>
                  Emergency SOS
                </strong>

                <div>
                  Patient:{" "}
                  {getPatientName(record)}
                </div>

                <div>
                  Blood:{" "}
                  {getBloodGroup(record)}
                </div>

                <div>
                  Units:{" "}
                  {record.units_required}
                </div>

                <div>
                  Urgency:{" "}
                  {record.urgency_level}
                </div>

                <div>
                  Location:{" "}
                  {getLocation(record)}
                </div>

                <div>
                  Status:{" "}
                  {record.status}
                </div>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}