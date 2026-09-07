from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator


class InventoryResponse(BaseModel):
    id: str
    organization_id: str
    organization_name: str
    blood_group_id: str
    blood_group_name: str
    blood_group_code: str | None = None
    total_units: int
    available_units: int
    reserved_units: int
    donation_date: date | None = None
    expiry_date: date | None = None
    storage_location: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime


class InventoryCreateRequest(BaseModel):
    blood_group_id: str
    total_units: int = Field(ge=0)
    available_units: int = Field(ge=0)
    reserved_units: int = Field(default=0, ge=0)
    donation_date: date | None = None
    expiry_date: date | None = None
    storage_location: str | None = Field(default=None, max_length=255)
    status: str = Field(default="AVAILABLE", max_length=30)

    @model_validator(mode="after")
    def validate_units(self):
        if self.available_units + self.reserved_units > self.total_units:
            raise ValueError(
                "Available and reserved units cannot exceed total units."
            )

        if (
            self.expiry_date is not None
            and self.donation_date is not None
            and self.expiry_date < self.donation_date
        ):
            raise ValueError(
                "Expiry date cannot be earlier than donation date."
            )

        return self


class InventoryUpdateRequest(BaseModel):
    total_units: int | None = Field(default=None, ge=0)
    available_units: int | None = Field(default=None, ge=0)
    reserved_units: int | None = Field(default=None, ge=0)
    donation_date: date | None = None
    expiry_date: date | None = None
    storage_location: str | None = Field(default=None, max_length=255)
    status: str | None = Field(default=None, max_length=30)
