from typing import Any

import asyncpg


class DonorRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def get_by_user_id(
        self,
        user_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                d.id,
                d.user_id,
                d.blood_group_id,
                d.city_id,
                d.phone_number,
                d.date_of_birth,
                d.gender,
                d.is_available,
                d.total_donations,
                d.last_donation_date
            FROM public.donors d
            WHERE d.user_id = $1
            LIMIT 1
            """,
            user_id,
        )

        return dict(row) if row else None

    async def get_by_id(
        self,
        donor_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                d.id,
                d.user_id,
                u.full_name,
                d.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                d.city_id,
                c.name AS city_name,
                p.name AS province_name,
                d.is_available,
                d.total_donations,
                d.last_donation_date
            FROM public.donors d
            INNER JOIN public.users u
                ON u.id = d.user_id
            INNER JOIN public.blood_groups bg
                ON bg.id = d.blood_group_id
            INNER JOIN public.cities c
                ON c.id = d.city_id
            LEFT JOIN public.provinces p
                ON p.id = c.province_id
            WHERE d.id = $1
              AND u.deleted_at IS NULL
            LIMIT 1
            """,
            donor_id,
        )

        return dict(row) if row else None

    async def list_donors(
        self,
        blood_group_id: str | None = None,
        city_id: str | None = None,
        available_only: bool = True,
    ) -> list[dict[str, Any]]:
        conditions = [
            "u.deleted_at IS NULL",
        ]

        values: list[Any] = []

        if available_only:
            conditions.append("d.is_available = true")

        if blood_group_id:
            values.append(blood_group_id)
            conditions.append(
                f"d.blood_group_id = ${len(values)}"
            )

        if city_id:
            values.append(city_id)
            conditions.append(
                f"d.city_id = ${len(values)}"
            )

        rows = await self.connection.fetch(
            f"""
            SELECT
                d.id,
                d.user_id,
                u.full_name,
                d.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                d.city_id,
                c.name AS city_name,
                p.name AS province_name,
                d.is_available,
                d.total_donations,
                d.last_donation_date
            FROM public.donors d
            INNER JOIN public.users u
                ON u.id = d.user_id
            INNER JOIN public.blood_groups bg
                ON bg.id = d.blood_group_id
            INNER JOIN public.cities c
                ON c.id = d.city_id
            LEFT JOIN public.provinces p
                ON p.id = c.province_id
            WHERE {" AND ".join(conditions)}
            ORDER BY
                d.is_available DESC,
                d.total_donations DESC,
                d.created_at DESC
            """,
            *values,
        )

        return [dict(row) for row in rows]

    async def update_availability(
        self,
        user_id: str,
        is_available: bool,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            UPDATE public.donors
            SET
                is_available = $1,
                updated_at = now()
            WHERE user_id = $2
            RETURNING
                id,
                user_id,
                blood_group_id,
                city_id,
                phone_number,
                date_of_birth,
                gender,
                is_available,
                total_donations,
                last_donation_date
            """,
            is_available,
            user_id,
        )

        return dict(row) if row else None
