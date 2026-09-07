from fastapi import HTTPException, status

from app.repositories.notification_repository import (
    NotificationRepository,
)


class NotificationService:
    def __init__(
        self,
        repository: NotificationRepository,
    ) -> None:
        self.repository = repository

    # ============================================================
    # CREATE NOTIFICATION
    # ============================================================

    async def create(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
    ):
        return await self.repository.create(
            user_id=user_id,
            title=title,
            message=message,
            notification_type=notification_type,
        )

    # ============================================================
    # GET ACTIVE USERS BY ROLE
    # ============================================================

    async def get_user_ids_by_roles(
        self,
        roles: list[str],
        exclude_user_id: str | None = None,
    ) -> list[str]:
        return await self.repository.get_user_ids_by_roles(
            roles=roles,
            exclude_user_id=exclude_user_id,
        )

    # ============================================================
    # LIST USER NOTIFICATIONS
    # ============================================================

    async def list_for_user(
        self,
        user_id: str,
    ):
        return await self.repository.list_for_user(
            user_id,
        )

    # ============================================================
    # GET UNREAD COUNT
    # ============================================================

    async def get_unread_count(
        self,
        user_id: str,
    ) -> int:
        return await self.repository.get_unread_count(
            user_id,
        )

    # ============================================================
    # MARK NOTIFICATION AS READ
    # ============================================================

    async def mark_as_read(
        self,
        notification_id: str,
        user_id: str,
    ):
        notification = await self.repository.mark_as_read(
            notification_id,
            user_id,
        )

        if notification is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found.",
            )

        return notification

    # ============================================================
    # MARK ALL USER NOTIFICATIONS AS READ
    # ============================================================

    async def mark_all_as_read(
        self,
        user_id: str,
    ) -> int:
        return await self.repository.mark_all_as_read(
            user_id,
        )