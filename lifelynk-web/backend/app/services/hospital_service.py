from fastapi import HTTPException, status

from app.repositories.hospital_repository import HospitalRepository


class HospitalService:
    def __init__(self, repository: HospitalRepository) -> None:
        self.repository = repository

    async def list_hospitals(
        self,
        city_id: str | None = None,
        emergency_only: bool = False,
    ):
        return await self.repository.list_hospitals(
            city_id=city_id,
            emergency_only=emergency_only,
        )

    async def get_hospital(self, hospital_id: str):
        hospital = await self.repository.get_hospital(hospital_id)

        if hospital is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hospital not found.",
            )

        return hospital
