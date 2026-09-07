from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    full_name: str
    gender: str | None = None
    date_of_birth: date | None = None
    blood_group: str | None = None
    province: str | None = None
    city: str | None = None
    address: str | None = None
    emergency_name: str | None = None
    emergency_phone: str | None = None
    weight: Decimal | None = None
    is_donor: bool
    profile_image: str | None = None


class ProfileUpdateRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    gender: str | None = Field(default=None, max_length=50)
    date_of_birth: date | None = None
    blood_group: str | None = Field(default=None, max_length=20)
    province: str | None = Field(default=None, max_length=100)
    city: str | None = Field(default=None, max_length=100)
    address: str | None = Field(default=None, max_length=500)
    emergency_name: str | None = Field(default=None, max_length=150)
    emergency_phone: str | None = Field(default=None, max_length=30)
    weight: Decimal | None = Field(default=None, ge=0, le=500)
    is_donor: bool | None = None
    profile_image: str | None = Field(default=None, max_length=1000)
