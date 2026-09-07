from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.inventory_repository import InventoryRepository
from app.schemas.inventory import (
    InventoryCreateRequest,
    InventoryResponse,
    InventoryUpdateRequest,
)
from app.services.authorization_service import (
    CurrentUser,
    require_organization_member,
)
from app.services.inventory_service import InventoryService


router = APIRouter(
    prefix="/inventory",
    tags=["Blood Inventory"],
)


@router.get(
    "",
    response_model=list[InventoryResponse],
)
async def list_inventory(
    blood_group_id: str | None = Query(default=None),
    organization_id: str | None = Query(default=None),
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = InventoryService(
        InventoryRepository(connection),
    )

    # Ordinary users can only access their own organization's inventory.
    # Government and Super Admin can query across organizations.
    if current_user.role not in {
        "GOVERNMENT_ADMIN",
        "SUPER_ADMIN",
    }:
        organization_id = current_user.organization_id

    return await service.list_inventory(
        organization_id=organization_id,
        blood_group_id=blood_group_id,
    )


@router.get(
    "/{inventory_id}",
    response_model=InventoryResponse,
)
async def get_inventory(
    inventory_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    service = InventoryService(
        InventoryRepository(connection),
    )

    inventory = await service.get_inventory(inventory_id)

    if current_user.role not in {
        "GOVERNMENT_ADMIN",
        "SUPER_ADMIN",
    }:
        if inventory["organization_id"] != current_user.organization_id:
            from fastapi import HTTPException

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have access to this inventory.",
            )

    return inventory


@router.post(
    "",
    response_model=InventoryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_inventory(
    payload: InventoryCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    require_organization_member(current_user)

    if current_user.role not in {
        "HOSPITAL_ADMIN",
        "BLOOD_BANK_ADMIN",
        "SUPER_ADMIN",
        "GOVERNMENT_ADMIN",
    }:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to manage blood inventory.",
        )

    service = InventoryService(
        InventoryRepository(connection),
    )

    return await service.create_inventory(
        current_user.organization_id,
        payload.model_dump(),
    )


@router.patch(
    "/{inventory_id}",
    response_model=InventoryResponse,
)
async def update_inventory(
    inventory_id: str,
    payload: InventoryUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    require_organization_member(current_user)

    if current_user.role not in {
        "HOSPITAL_ADMIN",
        "BLOOD_BANK_ADMIN",
        "SUPER_ADMIN",
        "GOVERNMENT_ADMIN",
    }:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to manage blood inventory.",
        )

    service = InventoryService(
        InventoryRepository(connection),
    )

    fields = payload.model_dump(exclude_unset=True)

    return await service.update_inventory(
        inventory_id,
        current_user.organization_id,
        fields,
    )


@router.delete(
    "/{inventory_id}",
    status_code=status.HTTP_200_OK,
)
async def delete_inventory(
    inventory_id: str,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
):
    require_organization_member(current_user)

    if current_user.role not in {
        "HOSPITAL_ADMIN",
        "BLOOD_BANK_ADMIN",
        "SUPER_ADMIN",
        "GOVERNMENT_ADMIN",
    }:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to manage blood inventory.",
        )

    service = InventoryService(
        InventoryRepository(connection),
    )

    return await service.delete_inventory(
        inventory_id,
        current_user.organization_id,
    )
