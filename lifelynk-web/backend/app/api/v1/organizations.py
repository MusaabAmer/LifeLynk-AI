from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.organization_repository import (
    OrganizationRepository,
)
from app.schemas.organization import (
    OrganizationMemberResponse,
    OrganizationResponse,
    OrganizationSummary,
)
from app.services.authorization_service import (
    CurrentUser,
    require_organization_member,
)
from app.services.organization_service import OrganizationService


router = APIRouter(
    prefix="/organizations",
    tags=["Organizations"],
)


@router.get(
    "",
    response_model=list[OrganizationSummary],
)
async def list_organizations(
    organization_type: str | None = Query(
        default=None,
        max_length=30,
    ),
    city_id: str | None = Query(
        default=None,
    ),
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = OrganizationService(
        OrganizationRepository(connection),
    )

    return await service.list_organizations(
        organization_type=organization_type,
        city_id=city_id,
    )


@router.get(
    "/{organization_id}",
    response_model=OrganizationResponse,
)
async def get_organization(
    organization_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = OrganizationService(
        OrganizationRepository(connection),
    )

    return await service.get_organization(
        organization_id,
    )


@router.get(
    "/{organization_id}/members",
    response_model=list[OrganizationMemberResponse],
)
async def get_organization_members(
    organization_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    require_organization_member(current_user)

    if current_user.organization_id != organization_id:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this organization.",
        )

    service = OrganizationService(
        OrganizationRepository(connection),
    )

    return await service.get_members(
        organization_id,
    )