from fastapi import HTTPException, status

from app.repositories.blood_bank_repository import BloodBankRepository


class BloodBankService:
    def __init__(self, repository: BloodBankRepository) -> None:
        self.repository = repository

    async def list_blood_banks(self, city_id: str | None = None):
        return await self.repository.list_blood_banks(
            city_id=city_id,
        )

    async def get_blood_bank(self, blood_bank_id: str):
        blood_bank = await self.repository.get_blood_bank(
            blood_bank_id,
        )

        if blood_bank is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Blood bank not found.",
            )

        return blood_bank
