from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.user_repository import UserRepository
from app.schemas.user import ProfileResponse, ProfileUpdateRequest
from app.services.authorization_service import CurrentUser
from app.services.user_service import UserService


router = APIRouter(
    prefix="/me",
    tags=["Authentication"],
)


@router.get("")
async def get_me(
    current_user: CurrentUser = Depends(get_current_user),
) -> dict:
    return {
        "id": current_user.id,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "phone_number": current_user.phone_number,
        "role": current_user.role,
        "is_active": current_user.is_active,
        "is_verified": current_user.is_verified,
        "organization": (
            {
                "id": current_user.organization_id,
                "name": current_user.organization_name,
                "type": current_user.organization_type,
                "is_primary": current_user.is_primary,
            }
            if current_user.organization_id
            else None
        ),
    }


@router.get(
    "/profile",
    response_model=ProfileResponse,
)
async def get_my_profile(
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
) -> dict:
    service = UserService(UserRepository(connection))

    return await service.get_profile(current_user.id)


@router.patch(
    "/profile",
    response_model=ProfileResponse,
)
async def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
) -> dict:
    service = UserService(UserRepository(connection))

    fields = payload.model_dump(
        exclude_unset=True,
    )

    return await service.update_profile(
        current_user.id,
        fields,
    )
