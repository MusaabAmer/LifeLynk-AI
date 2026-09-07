from typing import Any

import asyncpg


class BloodBankRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def list_blood_banks(
        self,
        city_id: str | None = None,
    ) -> list[dict[str, Any]]:
        conditions = [
            "o.deleted_at IS NULL",
            "b.deleted_at IS NULL",
            "o.verification_status = 'VERIFIED'",
        ]

        values: list[Any] = []

        if city_id:
            values.append(city_id)
            conditions.append(f"o.city_id = ${len(values)}")

        rows = await self.connection.fetch(
            f"""
            SELECT
                b.id,
                b.organization_id,
                o.name,
                o.organization_type,
                b.license_number,
                b.storage_capacity,
                b.cold_storage_available,
                b.blood_processing_available,
                b.operating_hours,
                o.city_id,
                o.address,
                o.phone,
                o.email,
                o.latitude,
                o.longitude,
                o.verification_status
            FROM public.blood_banks b
            INNER JOIN public.organizations o
                ON o.id = b.organization_id
            WHERE {" AND ".join(conditions)}
            ORDER BY o.name ASC
            """,
            *values,
        )

        return [dict(row) for row in rows]

    async def get_blood_bank(
        self,
        blood_bank_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                b.id,
                b.organization_id,
                o.name,
                o.organization_type,
                b.license_number,
                b.storage_capacity,
                b.cold_storage_available,
                b.blood_processing_available,
                b.operating_hours,
                o.city_id,
                o.address,
                o.phone,
                o.email,
                o.latitude,
                o.longitude,
                o.verification_status
            FROM public.blood_banks b
            INNER JOIN public.organizations o
                ON o.id = b.organization_id
            WHERE b.id = $1
              AND b.deleted_at IS NULL
              AND o.deleted_at IS NULL
            LIMIT 1
            """,
            blood_bank_id,
        )

        return dict(row) if row else None
