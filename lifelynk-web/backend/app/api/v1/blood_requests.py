from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.blood_request_repository import (
    BloodRequestRepository,
)
from app.repositories.notification_repository import (
    NotificationRepository,
)
from app.repositories.organization_repository import (
    OrganizationRepository,
)
from app.schemas.blood_request import (
    BloodRequestCreate,
    BloodRequestResponse,
    BloodRequestStatusUpdate,
    BloodRequestUpdate,
    BloodReservationCreate,
    BloodReservationResponse,
)
from app.services.authorization_service import (
    CurrentUser,
    require_organization_member,
)
from app.services.blood_request_service import (
    BloodRequestService,
)
from app.services.notification_service import (
    NotificationService,
)


router = APIRouter(
    prefix="/blood-requests",
    tags=["Blood Requests"],
)


# ================================================================
# SERVICE FACTORY
# ================================================================

def _get_blood_request_service(
    connection,
) -> BloodRequestService:
    return BloodRequestService(
        repository=BloodRequestRepository(
            connection,
        ),
        notification_service=NotificationService(
            NotificationRepository(
                connection,
            ),
        ),
        organization_repository=OrganizationRepository(
            connection,
        ),
    )


# ================================================================
# CREATE NORMAL BLOOD REQUEST
# ================================================================

@router.post(
    "",
    response_model=BloodRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_blood_request(
    payload: BloodRequestCreate,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    require_organization_member(
        current_user,
    )

    service = _get_blood_request_service(
        connection,
    )

    return await service.create(
        requester_id=current_user.id,
        organization_id=current_user.organization_id,
        data=payload.model_dump(),
    )


# ================================================================
# RESERVE BLOOD FROM SEARCH
#
# IMPORTANT:
# This route must appear before /{request_id}
# ================================================================

@router.post(
    "/reserve",
    response_model=BloodReservationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def reserve_blood(
    payload: BloodReservationCreate,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_blood_request_service(
        connection,
    )

    return await service.reserve_blood(
        requester_id=current_user.id,
        organization_id=payload.organization_id,
        blood_group_id=payload.blood_group_id,
        units_required=payload.units_required,
        urgency=payload.urgency.value,
        required_date=payload.required_date,
        notes=payload.notes,
    )


# ================================================================
# GET MY BLOOD REQUESTS
# ================================================================

@router.get(
    "/mine",
    response_model=list[BloodRequestResponse],
)
async def get_my_blood_requests(
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_blood_request_service(
        connection,
    )

    return await service.list_for_user(
        current_user.id,
    )


# ================================================================
# GET ORGANIZATION BLOOD REQUESTS
# ================================================================

@router.get(
    "/organization",
    response_model=list[BloodRequestResponse],
)
async def get_organization_blood_requests(
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    require_organization_member(
        current_user,
    )

    service = _get_blood_request_service(
        connection,
    )

    return await service.list_for_organization(
        current_user.organization_id,
    )


# ================================================================
# GET SINGLE BLOOD REQUEST
# ================================================================

@router.get(
    "/{request_id}",
    response_model=BloodRequestResponse,
)
async def get_blood_request(
    request_id: str,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_blood_request_service(
        connection,
    )

    request = await service.get(
        request_id,
    )

    if current_user.role not in {
        "GOVERNMENT_ADMIN",
        "SUPER_ADMIN",
    }:
        allowed = (
            request["requester_id"]
            == current_user.id
            or request["organization_id"]
            == current_user.organization_id
        )

        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "You do not have access to "
                    "this blood request."
                ),
            )

    return request


# ================================================================
# UPDATE BLOOD REQUEST
# ================================================================

@router.patch(
    "/{request_id}",
    response_model=BloodRequestResponse,
)
async def update_blood_request(
    request_id: str,
    payload: BloodRequestUpdate,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_blood_request_service(
        connection,
    )

    return await service.update(
        request_id,
        current_user.id,
        payload.model_dump(
            exclude_unset=True,
        ),
    )


# ================================================================
# CANCEL BLOOD REQUEST
# ================================================================

@router.post(
    "/{request_id}/cancel",
    response_model=BloodRequestResponse,
)
async def cancel_blood_request(
    request_id: str,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    service = _get_blood_request_service(
        connection,
    )

    return await service.cancel(
        request_id,
        current_user.id,
    )


# ================================================================
# ORGANIZATION STATUS UPDATE
# ================================================================

@router.patch(
    "/{request_id}/status",
    response_model=BloodRequestResponse,
)
async def update_blood_request_status(
    request_id: str,
    payload: BloodRequestStatusUpdate,
    current_user: CurrentUser = Depends(
        get_current_user,
    ),
    connection=Depends(get_connection),
):
    require_organization_member(
        current_user,
    )

    if current_user.role not in {
        "HOSPITAL_ADMIN",
        "BLOOD_BANK_ADMIN",
        "SUPER_ADMIN",
        "GOVERNMENT_ADMIN",
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "You do not have permission "
                "to update request status."
            ),
        )

    service = _get_blood_request_service(
        connection,
    )

    return await service.update_organization_status(
        request_id,
        current_user.organization_id,
        payload.status.value,
    )