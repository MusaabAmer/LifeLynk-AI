from datetime import datetime
from pydantic import BaseModel, Field


class DonorResponse(BaseModel):
    id: str
    user_id: str
    full_name: str
    blood_group_id: str
    blood_group_code: str
    blood_group_name: str
    city_id: str
    city_name: str
    province_name: str | None = None
    is_available: bool
    total_donations: int
    last_donation_date: datetime | None = None


class DonorMeResponse(BaseModel):
    id: str
    user_id: str
    blood_group_id: str
    city_id: str
    phone_number: str
    date_of_birth: datetime
    gender: str
    is_available: bool
    total_donations: int
    last_donation_date: datetime | None = None


class DonorAvailabilityUpdate(BaseModel):
    is_available: bool


class DonorSearchQuery(BaseModel):
    blood_group_id: str | None = None
    city_id: str | None = None
    available_only: bool = True
