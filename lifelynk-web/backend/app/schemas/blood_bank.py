from pydantic import BaseModel


class BloodBankResponse(BaseModel):
    id: str
    organization_id: str
    name: str
    organization_type: str
    license_number: str | None = None
    storage_capacity: int | None = None
    cold_storage_available: bool
    blood_processing_available: bool
    operating_hours: str | None = None
    city_id: str
    address: str
    phone: str
    email: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    verification_status: str
