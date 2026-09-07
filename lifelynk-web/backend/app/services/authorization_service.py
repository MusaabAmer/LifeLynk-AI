from dataclasses import dataclass
from typing import Any

from fastapi import HTTPException, status


@dataclass(frozen=True)
class CurrentUser:
    id: str
    email: str | None
    full_name: str | None
    phone_number: str | None
    role: str | None
    is_active: bool
    is_verified: bool
    organization_id: str | None
    organization_name: str | None
    organization_type: str | None
    is_primary: bool


def build_current_user(
    user: dict[str, Any],
    organization: dict[str, Any] | None,
) -> CurrentUser:
    return CurrentUser(
        id=str(user["id"]),
        email=user.get("email"),
        full_name=user.get("full_name"),
        phone_number=user.get("phone_number"),
        role=user.get("role"),
        is_active=bool(user.get("is_active", False)),
        is_verified=bool(user.get("is_verified", False)),
        organization_id=(
            str(organization["organization_id"])
            if organization
            else None
        ),
        organization_name=(
            organization.get("name")
            if organization
            else None
        ),
        organization_type=(
            organization.get("organization_type")
            if organization
            else None
        ),
        is_primary=(
            bool(organization.get("is_primary", False))
            if organization
            else False
        ),
    )


def require_active_user(user: CurrentUser) -> None:
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive.",
        )


def require_role(
    user: CurrentUser,
    *allowed_roles: str,
) -> None:
    require_active_user(user)

    if user.role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action.",
        )


def require_organization_member(user: CurrentUser) -> None:
    require_active_user(user)

    if not user.organization_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not an active organization member.",
        )


def require_primary_admin(user: CurrentUser) -> None:
    require_organization_member(user)

    if not user.is_primary:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the primary organization administrator can perform this action.",
        )


def require_government_access(user: CurrentUser) -> None:
    require_role(
        user,
        "GOVERNMENT_ADMIN",
        "SUPER_ADMIN",
    )


def require_super_admin(user: CurrentUser) -> None:
    require_role(user, "SUPER_ADMIN")
