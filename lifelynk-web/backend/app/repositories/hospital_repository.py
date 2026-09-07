from typing import Any

import asyncpg


class HospitalRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def list_hospitals(
        self,
        city_id: str | None = None,
        emergency_only: bool = False,
    ) -> list[dict[str, Any]]:
        conditions = [
            "o.deleted_at IS NULL",
            "h.deleted_at IS NULL",
            "o.verification_status = 'VERIFIED'",
        ]

        values: list[Any] = []

        if city_id:
            values.append(city_id)
            conditions.append(f"o.city_id = ${len(values)}")

        if emergency_only:
            conditions.append("h.emergency_service = true")

        rows = await self.connection.fetch(
            f"""
            SELECT
                h.id,
                h.organization_id,
                o.name,
                o.organization_type,
                h.hospital_type,
                h.license_number,
                h.emergency_service,
                h.blood_storage_available,
                h.total_beds,
                h.icu_available,
                o.city_id,
                o.address,
                o.phone,
                o.email,
                o.latitude,
                o.longitude,
                o.verification_status
            FROM public.hospitals h
            INNER JOIN public.organizations o
                ON o.id = h.organization_id
            WHERE {" AND ".join(conditions)}
            ORDER BY o.name ASC
            """,
            *values,
        )

        return [dict(row) for row in rows]

    async def get_hospital(
        self,
        hospital_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                h.id,
                h.organization_id,
                o.name,
                o.organization_type,
                h.hospital_type,
                h.license_number,
                h.emergency_service,
                h.blood_storage_available,
                h.total_beds,
                h.icu_available,
                o.city_id,
                o.address,
                o.phone,
                o.email,
                o.latitude,
                o.longitude,
                o.verification_status
            FROM public.hospitals h
            INNER JOIN public.organizations o
                ON o.id = h.organization_id
            WHERE h.id = $1
              AND h.deleted_at IS NULL
              AND o.deleted_at IS NULL
            LIMIT 1
            """,
            hospital_id,
        )

        return dict(row) if row else None
