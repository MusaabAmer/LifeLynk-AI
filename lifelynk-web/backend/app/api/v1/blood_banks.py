from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.blood_bank_repository import BloodBankRepository
from app.schemas.blood_bank import BloodBankResponse
from app.services.authorization_service import CurrentUser
from app.services.blood_bank_service import BloodBankService


router = APIRouter(
    prefix="/blood-banks",
    tags=["Blood Banks"],
)


@router.get(
    "",
    response_model=list[BloodBankResponse],
)
async def list_blood_banks(
    city_id: str | None = Query(default=None),
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = BloodBankService(
        BloodBankRepository(connection),
    )

    return await service.list_blood_banks(city_id)


@router.get(
    "/{blood_bank_id}",
    response_model=BloodBankResponse,
)
async def get_blood_bank(
    blood_bank_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = BloodBankService(
        BloodBankRepository(connection),
    )

    return await service.get_blood_bank(blood_bank_id)
