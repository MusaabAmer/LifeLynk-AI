from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.search_repository import SearchRepository
from app.services.authorization_service import CurrentUser
from app.services.search_service import SearchService

router = APIRouter(
    prefix="/search",
    tags=["Search"],
)


@router.get("/organizations")
async def search_organizations(
    blood_group: Annotated[
        str | None,
        Query(max_length=10),
    ] = None,
    province: Annotated[
        str | None,
        Query(max_length=100),
    ] = None,
    city: Annotated[
        str | None,
        Query(max_length=100),
    ] = None,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
) -> list[dict]:
    repository = SearchRepository(connection)

    service = SearchService(repository)

    return await service.search_organizations(
        blood_group=blood_group,
        province=province,
        city=city,
    )