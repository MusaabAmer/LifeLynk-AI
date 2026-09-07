from typing import Any
from uuid import UUID, uuid4

import asyncpg


class NotificationRepository:
    def __init__(
        self,
        connection: asyncpg.Connection,
    ) -> None:
        self.connection = connection

    # ============================================================
    # CREATE NOTIFICATION
    # ============================================================

    async def create(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
    ) -> dict[str, Any]:
        notification_id = uuid4()

        row = await self.connection.fetchrow(
            """
            INSERT INTO public.notifications (
                id,
                user_id,
                title,
                message,
                notification_type,
                is_read
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                false
            )
            RETURNING
                id,
                user_id,
                title,
                message,
                notification_type,
                is_read,
                created_at
            """,
            notification_id,
            user_id,
            title,
            message,
            notification_type,
        )

        if row is None:
            raise ValueError(
                "Notification could not be created."
            )

        return dict(row)

    # ============================================================
    # GET ACTIVE USERS BY ROLE
    # ============================================================

    async def get_user_ids_by_roles(
        self,
        roles: list[str],
        exclude_user_id: str | None = None,
    ) -> list[str]:
        if not roles:
            return []

        conditions = [
            "u.deleted_at IS NULL",
            "u.is_active = true",
            "r.name = ANY($1::text[])",
        ]

        values: list[Any] = [
            roles,
        ]

        if exclude_user_id is not None:
            normalized_exclude_user_id = exclude_user_id.strip()

            if normalized_exclude_user_id:
                try:
                    exclude_uuid = UUID(
                        normalized_exclude_user_id
                    )
                except ValueError as exc:
                    raise ValueError(
                        "Invalid exclude_user_id."
                    ) from exc

                values.append(exclude_uuid)

                conditions.append(
                    f"u.id <> ${len(values)}"
                )

        rows = await self.connection.fetch(
            f"""
            SELECT DISTINCT
                u.id
            FROM public.users AS u
            INNER JOIN public.roles AS r
                ON r.id = u.role_id
            WHERE {" AND ".join(conditions)}
            ORDER BY u.id
            """,
            *values,
        )

        return [
            str(row["id"])
            for row in rows
        ]

    # ============================================================
    # LIST USER NOTIFICATIONS
    # ============================================================

    async def list_for_user(
        self,
        user_id: str,
    ) -> list[dict[str, Any]]:
        rows = await self.connection.fetch(
            """
            SELECT
                id,
                user_id,
                title,
                message,
                notification_type,
                is_read,
                created_at
            FROM public.notifications
            WHERE user_id = $1
            ORDER BY created_at DESC
            """,
            user_id,
        )

        return [
            dict(row)
            for row in rows
        ]

    # ============================================================
    # GET UNREAD COUNT
    # ============================================================

    async def get_unread_count(
        self,
        user_id: str,
    ) -> int:
        count = await self.connection.fetchval(
            """
            SELECT COUNT(*)
            FROM public.notifications
            WHERE user_id = $1
              AND is_read = false
            """,
            user_id,
        )

        return int(count or 0)

    # ============================================================
    # MARK NOTIFICATION AS READ
    # ============================================================

    async def mark_as_read(
        self,
        notification_id: str,
        user_id: str,
    ) -> dict[str, Any] | None:
        row = await self.connection.fetchrow(
            """
            UPDATE public.notifications
            SET
                is_read = true
            WHERE id = $1
              AND user_id = $2
            RETURNING
                id,
                user_id,
                title,
                message,
                notification_type,
                is_read,
                created_at
            """,
            notification_id,
            user_id,
        )

        return dict(row) if row else None

    # ============================================================
    # MARK ALL USER NOTIFICATIONS AS READ
    # ============================================================

    async def mark_all_as_read(
        self,
        user_id: str,
    ) -> int:
        result = await self.connection.execute(
            """
            UPDATE public.notifications
            SET
                is_read = true
            WHERE user_id = $1
              AND is_read = false
            """,
            user_id,
        )

        # asyncpg returns e.g. "UPDATE 4"
        return int(
            result.split()[-1]
        )