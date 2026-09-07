from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class SosUrgency(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class SosStatus(str, Enum):
    PENDING = "pending"
    MATCHED = "matched"
    IN_PROGRESS = "in_progress"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class SosCreateRequest(BaseModel):
    blood_group_id: str
    city_id: str | None = None
    units_required: int = Field(gt=0, le=1000)
    urgency_level: SosUrgency
    description: str | None = Field(default=None, max_length=2000)

    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    gps_accuracy: float | None = Field(default=None, ge=0)
    location_timestamp: datetime | None = None


class SosUpdateRequest(BaseModel):
    description: str | None = Field(default=None, max_length=2000)

    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    gps_accuracy: float | None = Field(default=None, ge=0)
    location_timestamp: datetime | None = None


class SosResponse(BaseModel):
    id: str
    user_id: str
    blood_group_id: str
    blood_group_code: str
    blood_group_name: str
    city_id: str | None = None
    city_name: str | None = None
    units_required: int
    urgency_level: str
    description: str | None = None
    status: str
    created_at: datetime
    latitude: float | None = None
    longitude: float | None = None
    gps_accuracy: float | None = None
    location_timestamp: datetime | None = None
