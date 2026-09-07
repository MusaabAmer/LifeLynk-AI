from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


# ================================================================
# BLOOD REQUEST ENUMS
# ================================================================

class BloodRequestUrgency(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class BloodRequestStatus(str, Enum):
    PENDING = "PENDING"
    MATCHED = "MATCHED"
    IN_PROGRESS = "IN_PROGRESS"
    FULFILLED = "FULFILLED"
    CANCELLED = "CANCELLED"
    REJECTED = "REJECTED"


# ================================================================
# NORMAL BLOOD REQUEST
# ================================================================

class BloodRequestCreate(BaseModel):
    blood_group_id: str

    units_required: int = Field(
        gt=0,
        le=1000,
    )

    urgency: BloodRequestUrgency

    required_date: datetime

    patient_id: str

    notes: str | None = Field(
        default=None,
        max_length=2000,
    )


class BloodRequestUpdate(BaseModel):
    urgency: BloodRequestUrgency | None = None

    required_date: datetime | None = None

    notes: str | None = Field(
        default=None,
        max_length=2000,
    )


class BloodRequestStatusUpdate(BaseModel):
    status: BloodRequestStatus


# ================================================================
# BLOOD REQUEST RESPONSE
# ================================================================

class BloodRequestResponse(BaseModel):
    id: UUID

    requester_id: UUID

    organization_id: UUID

    organization_name: str

    blood_group_id: UUID

    blood_group_code: str

    blood_group_name: str

    units_required: int

    urgency: str

    status: str

    required_date: datetime

    notes: str | None = None

    patient_id: UUID

    created_at: datetime

    updated_at: datetime


# ================================================================
# BLOOD RESERVATION REQUEST
# ================================================================

class BloodReservationCreate(BaseModel):
    organization_id: str

    blood_group_id: str

    units_required: int = Field(
        gt=0,
        le=1000,
    )

    urgency: BloodRequestUrgency

    required_date: datetime

    notes: str | None = Field(
        default=None,
        max_length=2000,
    )


# ================================================================
# BLOOD RESERVATION RESPONSE
#
# A single request can use multiple inventory lots.
# ================================================================

class BloodReservationResponse(BaseModel):
    request: BloodRequestResponse

    reservations: list[dict]

    inventory: list[dict]