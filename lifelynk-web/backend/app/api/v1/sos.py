from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.notification_repository import (
    NotificationRepository,
)
from app.repositories.sos_repository import SosRepository
from app.schemas.sos import (
    SosCreateRequest,
    SosResponse,
    SosUpdateRequest,
)
from app.services.authorization_service import CurrentUser
from app.services.notification_service import (
    NotificationService,
)
from app.services.sos_service import SosService


router = APIRouter(
    prefix="/sos",
    tags=["Emergency SOS"],
)


# ================================================================
# SERVICE FACTORY
# ================================================================

def _get_sos_service(
    connection,
) -> SosService:
    return SosService(
        repository=SosRepository(
            connection,
        ),
        notification_service=NotificationService(
            NotificationRepository(
                connection,
            ),
        ),
    )


# ================================================================
# CREATE SOS
# ================================================================

@router.post(
    "",
    response_model=SosResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_sos(
    payload: SosCreateRequest,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.create(
        current_user.id,
        payload.model_dump(),
    )


# ================================================================
# LIST MY SOS
# ================================================================

@router.get(
    "",
    response_model=list[SosResponse],
)
async def list_my_sos(
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.list_for_user(
        current_user.id,
    )


# ================================================================
# GET ACTIVE SOS
# ================================================================

@router.get(
    "/active",
    response_model=SosResponse | None,
)
async def get_active_sos(
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.get_active(
        current_user.id,
    )


# ================================================================
# GET SINGLE SOS
# ================================================================

@router.get(
    "/{sos_id}",
    response_model=SosResponse,
)
async def get_sos(
    sos_id: str,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    sos = await service.get(
        sos_id,
    )

    if (
        sos["user_id"] != current_user.id
        and current_user.role not in {
            "GOVERNMENT_ADMIN",
            "SUPER_ADMIN",
        }
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this SOS.",
        )

    return sos


# ================================================================
# UPDATE SOS
# ================================================================

@router.patch(
    "/{sos_id}",
    response_model=SosResponse,
)
async def update_sos(
    sos_id: str,
    payload: SosUpdateRequest,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.update(
        sos_id,
        current_user.id,
        payload.model_dump(
            exclude_unset=True,
        ),
    )


# ================================================================
# CANCEL SOS
# ================================================================

@router.post(
    "/{sos_id}/cancel",
    response_model=SosResponse,
)
async def cancel_sos(
    sos_id: str,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.cancel(
        sos_id,
        current_user.id,
    )


# ================================================================
# COMPLETE SOS
# ================================================================

@router.post(
    "/{sos_id}/complete",
    response_model=SosResponse,
)
async def complete_sos(
    sos_id: str,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_sos_service(
        connection,
    )

    return await service.complete(
        sos_id,
        current_user.id,
    )