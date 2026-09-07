from datetime import date
from typing import Any

import asyncpg


class InventoryRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def list_inventory(
        self,
        organization_id: str | None = None,
        blood_group_id: str | None = None,
    ) -> list[dict[str, Any]]:
        conditions = [
            "bi.organization_id = o.id",
            "o.deleted_at IS NULL",
            "bi.status <> 'DELETED'",
        ]

        values: list[Any] = []

        if organization_id:
            values.append(organization_id)
            conditions.append(f"bi.organization_id = ${len(values)}")

        if blood_group_id:
            values.append(blood_group_id)
            conditions.append(f"bi.blood_group_id = ${len(values)}")

        rows = await self.connection.fetch(
            f"""
            SELECT
                bi.id,
                bi.organization_id,
                o.name AS organization_name,
                bi.blood_group_id,
                bg.name AS blood_group_name,
                bg.code AS blood_group_code,
                bi.total_units,
                bi.available_units,
                bi.reserved_units,
                bi.donation_date,
                bi.expiry_date,
                bi.storage_location,
                bi.status,
                bi.created_at,
                bi.updated_at
            FROM public.blood_inventory bi
            INNER JOIN public.organizations o
                ON o.id = bi.organization_id
            INNER JOIN public.blood_groups bg
                ON bg.id = bi.blood_group_id
            WHERE {" AND ".join(conditions)}
            ORDER BY
                bi.expiry_date ASC NULLS LAST,
                o.name ASC
            """,
            *values,
        )

        return [dict(row) for row in rows]

    async def get_inventory(
        self,
        inventory_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                bi.id,
                bi.organization_id,
                o.name AS organization_name,
                bi.blood_group_id,
                bg.name AS blood_group_name,
                bg.code AS blood_group_code,
                bi.total_units,
                bi.available_units,
                bi.reserved_units,
                bi.donation_date,
                bi.expiry_date,
                bi.storage_location,
                bi.status,
                bi.created_at,
                bi.updated_at
            FROM public.blood_inventory bi
            INNER JOIN public.organizations o
                ON o.id = bi.organization_id
            INNER JOIN public.blood_groups bg
                ON bg.id = bi.blood_group_id
            WHERE bi.id = $1
              AND bi.status <> 'DELETED'
            LIMIT 1
            """,
            inventory_id,
        )

        return dict(row) if row else None

    async def create_inventory(
        self,
        organization_id: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        row = await self.connection.fetchrow(
            """
            INSERT INTO public.blood_inventory (
                organization_id,
                blood_group_id,
                total_units,
                available_units,
                reserved_units,
                donation_date,
                expiry_date,
                storage_location,
                status
            )
            VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9
            )
            RETURNING id
            """,
            organization_id,
            data["blood_group_id"],
            data["total_units"],
            data["available_units"],
            data["reserved_units"],
            data["donation_date"],
            data["expiry_date"],
            data["storage_location"],
            data["status"],
        )

        return await self.get_inventory(str(row["id"]))

    async def update_inventory(
        self,
        inventory_id: str,
        organization_id: str,
        fields: dict[str, Any],
    ) -> dict[str, Any] | None:
        if not fields:
            return await self.get_inventory(inventory_id)

        allowed = {
            "total_units",
            "available_units",
            "reserved_units",
            "donation_date",
            "expiry_date",
            "storage_location",
            "status",
        }

        fields = {
            key: value
            for key, value in fields.items()
            if key in allowed
        }

        if not fields:
            return await self.get_inventory(inventory_id)

        assignments = []
        values: list[Any] = []

        for index, (column, value) in enumerate(fields.items(), start=1):
            assignments.append(f"{column} = ${index}")
            values.append(value)

        values.extend([inventory_id, organization_id])

        inventory_position = len(values) - 1
        organization_position = len(values)

        row = await self.connection.fetchrow(
            f"""
            UPDATE public.blood_inventory
            SET
                {", ".join(assignments)},
                updated_at = now()
            WHERE id = ${inventory_position}
              AND organization_id = ${organization_position}
              AND status <> 'DELETED'
            RETURNING id
            """,
            *values,
        )

        if not row:
            return None

        return await self.get_inventory(inventory_id)

    async def soft_delete_inventory(
        self,
        inventory_id: str,
        organization_id: str,
    ) -> bool:
        result = await self.connection.execute(
            """
            UPDATE public.blood_inventory
            SET
                status = 'DELETED',
                updated_at = now()
            WHERE id = $1
              AND organization_id = $2
              AND status <> 'DELETED'
            """,
            inventory_id,
            organization_id,
        )

        return result.endswith("1")
