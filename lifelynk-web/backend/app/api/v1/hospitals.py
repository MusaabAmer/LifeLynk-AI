from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.hospital_repository import HospitalRepository
from app.schemas.hospital import HospitalResponse
from app.services.authorization_service import CurrentUser
from app.services.hospital_service import HospitalService


router = APIRouter(
    prefix="/hospitals",
    tags=["Hospitals"],
)


@router.get(
    "",
    response_model=list[HospitalResponse],
)
async def list_hospitals(
    city_id: str | None = Query(default=None),
    emergency_only: bool = Query(default=False),
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = HospitalService(
        HospitalRepository(connection),
    )

    return await service.list_hospitals(
        city_id=city_id,
        emergency_only=emergency_only,
    )


@router.get(
    "/{hospital_id}",
    response_model=HospitalResponse,
)
async def get_hospital(
    hospital_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = HospitalService(
        HospitalRepository(connection),
    )

    return await service.get_hospital(hospital_id)
