from typing import Any

from fastapi import HTTPException, status

from app.repositories.user_repository import UserRepository


class UserService:
    def __init__(self, repository: UserRepository) -> None:
        self.repository = repository

    async def get_profile(
        self,
        user_id: str,
    ) -> dict[str, Any]:
        profile = await self.repository.get_profile(user_id)

        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found.",
            )

        return profile

    async def update_profile(
        self,
        user_id: str,
        fields: dict[str, Any],
    ) -> dict[str, Any]:
        profile = await self.repository.update_profile(
            user_id,
            fields,
        )

        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found.",
            )

        return profile
