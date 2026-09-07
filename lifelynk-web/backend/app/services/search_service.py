from typing import Any

from app.repositories.search_repository import SearchRepository


class SearchService:
    def __init__(self, repository: SearchRepository) -> None:
        self.repository = repository

    async def search_organizations(
        self,
        blood_group: str | None = None,
        province: str | None = None,
        city: str | None = None,
    ) -> list[dict[str, Any]]:
        return await self.repository.search_organizations(
            blood_group=blood_group,
            province=province,
            city=city,
        )