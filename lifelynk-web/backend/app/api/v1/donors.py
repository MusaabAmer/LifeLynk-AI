from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.donor_repository import DonorRepository
from app.schemas.donor import (
    DonorAvailabilityUpdate,
    DonorMeResponse,
    DonorResponse,
)
from app.services.authorization_service import CurrentUser
from app.services.donor_service import DonorService


router = APIRouter(
    prefix="/donors",
    tags=["Donors"],
)


@router.get(
    "",
    response_model=list[DonorResponse],
)
async def list_donors(
    blood_group_id: str | None = Query(default=None),
    city_id: str | None = Query(default=None),
    available_only: bool = Query(default=True),
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = DonorService(
        DonorRepository(connection),
    )

    return await service.list_donors(
        blood_group_id=blood_group_id,
        city_id=city_id,
        available_only=available_only,
    )


@router.get(
    "/me",
    response_model=DonorMeResponse,
)
async def get_my_donor_profile(
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = DonorService(
        DonorRepository(connection),
    )

    return await service.get_my_donor(
        current_user.id,
    )


@router.patch(
    "/me/availability",
    response_model=DonorMeResponse,
)
async def update_my_availability(
    payload: DonorAvailabilityUpdate,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = DonorService(
        DonorRepository(connection),
    )

    return await service.update_availability(
        current_user.id,
        payload.is_available,
    )


@router.get(
    "/{donor_id}",
    response_model=DonorResponse,
)
async def get_donor(
    donor_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = DonorService(
        DonorRepository(connection),
    )

    return await service.get_donor(donor_id)
