from __future__ import annotations

from datetime import date
from uuid import UUID

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class Patient(Base, BaseModelMixin):
    __tablename__ = "patients"

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    blood_group_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("blood_groups.id", ondelete="SET NULL"),
        nullable=True,
    )

    date_of_birth: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    gender: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    emergency_contact: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    medical_notes: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    user = relationship(
        "User",
        back_populates="patient",
    )

    blood_group = relationship(
        "BloodGroup",
    )

    blood_requests = relationship(
        "BloodRequest",
        back_populates="patient",
        cascade="all, delete-orphan",
    )