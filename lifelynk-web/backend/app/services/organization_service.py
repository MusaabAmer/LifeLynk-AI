from fastapi import HTTPException, status

from app.repositories.organization_repository import (
    OrganizationRepository,
)


class OrganizationService:
    def __init__(
        self,
        repository: OrganizationRepository,
    ) -> None:
        self.repository = repository

    async def list_organizations(
        self,
        organization_type: str | None = None,
        city_id: str | None = None,
    ):
        return await self.repository.list_organizations(
            organization_type=organization_type,
            city_id=city_id,
        )

    async def get_organization(
        self,
        organization_id: str,
    ):
        organization = await self.repository.get_organization(
            organization_id,
        )

        if organization is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Organization not found.",
            )

        return organization

    async def get_members(
        self,
        organization_id: str,
    ):
        return await self.repository.get_members(
            organization_id,
        )