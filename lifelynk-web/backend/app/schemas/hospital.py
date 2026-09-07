from pydantic import BaseModel


class HospitalResponse(BaseModel):
    id: str
    organization_id: str
    name: str
    organization_type: str
    hospital_type: str | None = None
    license_number: str | None = None
    emergency_service: bool
    blood_storage_available: bool
    total_beds: int | None = None
    icu_available: int | None = None
    city_id: str
    address: str
    phone: str
    email: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    verification_status: str
