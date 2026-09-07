from uuid import UUID

from pydantic import BaseModel, Field


class OrganizationResponse(BaseModel):
    id: UUID
    city_id: UUID

    organization_type: str
    name: str

    registration_number: str | None = None

    phone: str | None = None
    email: str | None = None
    address: str | None = None

    latitude: float | None = None
    longitude: float | None = None

    verification_status: str

    city: str | None = None
    province: str | None = None

    inventory: list[dict] = Field(
        default_factory=list
    )

    services: list[dict] = Field(
        default_factory=list
    )

    rating: float = 0.0
    review_count: int = 0

    is_verified: bool = False
    is_open: bool = True

    hospital: dict | None = None
    blood_bank: dict | None = None


class OrganizationSummary(BaseModel):
    id: UUID
    name: str
    organization_type: str
    city_id: UUID
    verification_status: str

    latitude: float | None = None
    longitude: float | None = None


class OrganizationMemberResponse(BaseModel):
    id: UUID
    user_id: UUID
    full_name: str
    email: str
    role: str | None = None
    is_primary: bool