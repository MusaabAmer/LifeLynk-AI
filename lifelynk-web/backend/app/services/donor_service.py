from fastapi import HTTPException, status

from app.repositories.donor_repository import DonorRepository


class DonorService:
    def __init__(self, repository: DonorRepository) -> None:
        self.repository = repository

    async def list_donors(
        self,
        blood_group_id: str | None = None,
        city_id: str | None = None,
        available_only: bool = True,
    ):
        return await self.repository.list_donors(
            blood_group_id=blood_group_id,
            city_id=city_id,
            available_only=available_only,
        )

    async def get_donor(self, donor_id: str):
        donor = await self.repository.get_by_id(donor_id)

        if donor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Donor not found.",
            )

        return donor

    async def get_my_donor(
        self,
        user_id: str,
    ):
        donor = await self.repository.get_by_user_id(user_id)

        if donor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Donor profile not found.",
            )

        return donor

    async def update_availability(
        self,
        user_id: str,
        is_available: bool,
    ):
        donor = await self.repository.update_availability(
            user_id,
            is_available,
        )

        if donor is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Donor profile not found.",
            )

        return donor
