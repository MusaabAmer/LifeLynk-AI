from typing import Any

import asyncpg


class UserRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def get_user(self, user_id: str) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                u.id,
                u.email,
                u.full_name,
                u.phone_number,
                u.role_id,
                u.is_active,
                u.is_verified,
                r.name AS role
            FROM public.users AS u
            LEFT JOIN public.roles AS r
                ON r.id = u.role_id
            WHERE u.id = $1
              AND u.deleted_at IS NULL
            LIMIT 1
            """,
            user_id,
        )

        return dict(row) if row else None

    async def get_profile(
        self,
        user_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                id,
                user_id,
                full_name,
                gender,
                date_of_birth,
                blood_group,
                province,
                city,
                address,
                emergency_name,
                emergency_phone,
                weight,
                is_donor,
                profile_image
            FROM public.profiles
            WHERE user_id = $1
            LIMIT 1
            """,
            user_id,
        )

        return dict(row) if row else None

    async def update_profile(
        self,
        user_id: str,
        fields: dict[str, Any],
    ) -> dict[str, Any] | None:
        if not fields:
            return await self.get_profile(user_id)

        allowed_fields = {
            "full_name",
            "gender",
            "date_of_birth",
            "blood_group",
            "province",
            "city",
            "address",
            "emergency_name",
            "emergency_phone",
            "weight",
            "is_donor",
            "profile_image",
        }

        fields = {
            key: value
            for key, value in fields.items()
            if key in allowed_fields
        }

        if not fields:
            return await self.get_profile(user_id)

        assignments = []
        values = []

        for index, (column, value) in enumerate(fields.items(), start=1):
            assignments.append(f'"{column}" = ${index}')
            values.append(value)

        assignments.append('"updated_at" = now()')

        user_id_position = len(values) + 1

        query = f"""
            UPDATE public.profiles
            SET {", ".join(assignments)}
            WHERE user_id = ${user_id_position}
            RETURNING
                id,
                user_id,
                full_name,
                gender,
                date_of_birth,
                blood_group,
                province,
                city,
                address,
                emergency_name,
                emergency_phone,
                weight,
                is_donor,
                profile_image
        """

        row = await self.connection.fetchrow(
            query,
            *values,
            user_id,
        )

        return dict(row) if row else None

    async def get_primary_organization(
        self,
        user_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            SELECT
                os.organization_id,
                os.is_primary,
                o.name,
                o.organization_type,
                o.verification_status
            FROM public.organization_staff AS os
            INNER JOIN public.organizations AS o
                ON o.id = os.organization_id
            WHERE os.user_id = $1
              AND os.deleted_at IS NULL
              AND o.deleted_at IS NULL
            ORDER BY
                os.is_primary DESC,
                os.created_at ASC
            LIMIT 1
            """,
            user_id,
        )

        return dict(row) if row else None
