from fastapi import HTTPException, status

from app.repositories.inventory_repository import InventoryRepository


class InventoryService:
    def __init__(self, repository: InventoryRepository) -> None:
        self.repository = repository

    async def list_inventory(
        self,
        organization_id: str | None = None,
        blood_group_id: str | None = None,
    ):
        return await self.repository.list_inventory(
            organization_id=organization_id,
            blood_group_id=blood_group_id,
        )

    async def get_inventory(self, inventory_id: str):
        inventory = await self.repository.get_inventory(inventory_id)

        if inventory is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Inventory record not found.",
            )

        return inventory

    async def create_inventory(
        self,
        organization_id: str,
        data: dict,
    ):
        return await self.repository.create_inventory(
            organization_id,
            data,
        )

    async def update_inventory(
        self,
        inventory_id: str,
        organization_id: str,
        fields: dict,
    ):
        inventory = await self.repository.update_inventory(
            inventory_id,
            organization_id,
            fields,
        )

        if inventory is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Inventory record not found or does not belong to your organization.",
            )

        if (
            inventory["available_units"]
            + inventory["reserved_units"]
            > inventory["total_units"]
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Available and reserved units cannot exceed total units.",
            )

        return inventory

    async def delete_inventory(
        self,
        inventory_id: str,
        organization_id: str,
    ):
        deleted = await self.repository.soft_delete_inventory(
            inventory_id,
            organization_id,
        )

        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Inventory record not found or does not belong to your organization.",
            )

        return {
            "success": True,
            "message": "Inventory record deleted.",
        }
