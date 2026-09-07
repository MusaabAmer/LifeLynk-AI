from pydantic import BaseModel


class SearchOrganizationResult(BaseModel):
    id: str
    organization_id: str
    organization_name: str
    organization_type: str

    blood_group: str
    available_units: int

    province: str
    city: str
    address: str

    phone: str | None = None
    email: str | None = None
    website: str | None = None

    license_number: str | None = None
    operating_hours: str | None = None

    latitude: float | None = None
    longitude: float | None = None
    distance_km: float | None = None

    rating: float | None = None
    review_count: int | None = None

    services: list[str] = []

    is_verified: bool = False
    is_open: bool = True