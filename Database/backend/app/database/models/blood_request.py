from uuid import UUID

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    ForeignKey,
    Text,
    CheckConstraint,
    Index,
)

from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class BloodRequest(Base, BaseModelMixin):

    __tablename__ = "blood_requests"

    requester_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    patient_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey(
            "patients.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    organization_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey(
            "organizations.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    blood_group_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey(
            "blood_groups.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    units_required: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    urgency: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="NORMAL",
    )

    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="PENDING",
    )

    required_date: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    requester = relationship(
        "User",
        back_populates="blood_requests",
    )

    patient = relationship(
        "Patient",
        back_populates="blood_requests",
    )

    organization = relationship(
        "Organization",
    )

    blood_group = relationship(
        "BloodGroup",
    )

    reservations = relationship(
        "BloodReservation",
        back_populates="blood_request",
        cascade="all, delete-orphan",
    )

    __table_args__ = (

        CheckConstraint(
            "units_required > 0",
            name="check_units_required_positive",
        ),

        Index(
            "ix_blood_requests_search",
            "blood_group_id",
            "organization_id",
            "status",
        ),

    )