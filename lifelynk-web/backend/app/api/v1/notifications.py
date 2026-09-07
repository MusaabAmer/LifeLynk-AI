from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.notification_repository import (
    NotificationRepository,
)
from app.schemas.notification import (
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.services.authorization_service import CurrentUser
from app.services.notification_service import NotificationService


router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
)


@router.get(
    "",
    response_model=list[NotificationResponse],
)
async def list_notifications(
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = NotificationService(
        NotificationRepository(connection),
    )

    return await service.list_for_user(
        current_user.id,
    )


@router.get(
    "/unread-count",
    response_model=NotificationUnreadCountResponse,
)
async def get_unread_count(
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = NotificationService(
        NotificationRepository(connection),
    )

    count = await service.get_unread_count(
        current_user.id,
    )

    return {
        "unread_count": count,
    }


@router.patch(
    "/{notification_id}/read",
    response_model=NotificationResponse,
)
async def mark_notification_as_read(
    notification_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = NotificationService(
        NotificationRepository(connection),
    )

    return await service.mark_as_read(
        notification_id,
        current_user.id,
    )


@router.post(
    "/read-all",
    status_code=status.HTTP_200_OK,
)
async def mark_all_notifications_as_read(
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = NotificationService(
        NotificationRepository(connection),
    )

    count = await service.mark_all_as_read(
        current_user.id,
    )

    return {
        "marked_read": count,
    }
