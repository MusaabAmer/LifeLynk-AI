from typing import Any

import asyncpg


class SosRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def create(
        self,
        user_id: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        row = await self.connection.fetchrow(
            """
            INSERT INTO public.emergency_sos (
                user_id,
                blood_group_id,
                city_id,
                units_required,
                urgency_level,
                description,
                status,
                latitude,
                longitude,
                gps_accuracy,
                location_timestamp
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6,
                'pending',
                $7,
                $8,
                $9,
                $10
            )
            RETURNING id
            """,
            user_id,
            data["blood_group_id"],
            data.get("city_id"),
            data["units_required"],
            data["urgency_level"],
            data.get("description"),
            data.get("latitude"),
            data.get("longitude"),
            data.get("gps_accuracy"),
            data.get("location_timestamp"),
        )

        return await self.get_by_id(
            str(row["id"]),
        )

    async def get_by_id(
        self,
        sos_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                s.id,
                s.user_id,
                s.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                s.city_id,
                c.name AS city_name,
                s.units_required,
                s.urgency_level,
                s.description,
                s.status,
                s.created_at,
                s.latitude,
                s.longitude,
                s.gps_accuracy,
                s.location_timestamp
            FROM public.emergency_sos s
            INNER JOIN public.blood_groups bg
                ON bg.id = s.blood_group_id
            LEFT JOIN public.cities c
                ON c.id = s.city_id
            WHERE s.id = $1
            LIMIT 1
            """,
            sos_id,
        )

        return dict(row) if row else None

    async def list_for_user(
        self,
        user_id: str,
    ) -> list[dict[str, Any]]:
        rows = await self.connection.fetch(
            """
            SELECT
                s.id,
                s.user_id,
                s.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                s.city_id,
                c.name AS city_name,
                s.units_required,
                s.urgency_level,
                s.description,
                s.status,
                s.created_at,
                s.latitude,
                s.longitude,
                s.gps_accuracy,
                s.location_timestamp
            FROM public.emergency_sos s
            INNER JOIN public.blood_groups bg
                ON bg.id = s.blood_group_id
            LEFT JOIN public.cities c
                ON c.id = s.city_id
            WHERE s.user_id = $1
            ORDER BY s.created_at DESC
            """,
            user_id,
        )

        return [dict(row) for row in rows]

    async def get_active_for_user(
        self,
        user_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                s.id,
                s.user_id,
                s.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                s.city_id,
                c.name AS city_name,
                s.units_required,
                s.urgency_level,
                s.description,
                s.status,
                s.created_at,
                s.latitude,
                s.longitude,
                s.gps_accuracy,
                s.location_timestamp
            FROM public.emergency_sos s
            INNER JOIN public.blood_groups bg
                ON bg.id = s.blood_group_id
            LEFT JOIN public.cities c
                ON c.id = s.city_id
            WHERE s.user_id = $1
              AND s.status IN (
                  'pending',
                  'matched',
                  'in_progress'
              )
            ORDER BY s.created_at DESC
            LIMIT 1
            """,
            user_id,
        )

        return dict(row) if row else None

    async def update(
        self,
        sos_id: str,
        user_id: str,
        fields: dict[str, Any],
    ) -> dict[str, Any] | None:
        allowed = {
            "description",
            "latitude",
            "longitude",
            "gps_accuracy",
            "location_timestamp",
        }

        fields = {
            key: value
            for key, value in fields.items()
            if key in allowed
        }

        if not fields:
            return await self.get_by_id(sos_id)

        assignments = []
        values: list[Any] = []

        for index, (column, value) in enumerate(
            fields.items(),
            start=1,
        ):
            assignments.append(
                f"{column} = ${index}"
            )
            values.append(value)

        values.extend([
            sos_id,
            user_id,
        ])

        sos_position = len(values) - 1
        user_position = len(values)

        row = await self.connection.fetchrow(
            f"""
            UPDATE public.emergency_sos
            SET
                {", ".join(assignments)}
            WHERE id = ${sos_position}
              AND user_id = ${user_position}
              AND status IN (
                  'pending',
                  'matched',
                  'in_progress'
              )
            RETURNING id
            """,
            *values,
        )

        if not row:
            return None

        return await self.get_by_id(sos_id)

    async def update_status(
        self,
        sos_id: str,
        status: str,
        user_id: str | None = None,
    ) -> dict[str, Any] | None:
        conditions = [
            "id = $2",
        ]

        values: list[Any] = [
            status,
            sos_id,
        ]

        if user_id is not None:
            values.append(user_id)
            conditions.append(
                f"user_id = ${len(values)}"
            )

        row = await self.connection.fetchrow(
            f"""
            UPDATE public.emergency_sos
            SET
                status = $1
            WHERE {" AND ".join(conditions)}
            RETURNING id
            """,
            *values,
        )

        if not row:
            return None

        return await self.get_by_id(sos_id)
