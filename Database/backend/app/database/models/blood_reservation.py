from uuid import uuid4

from sqlalchemy import (
    Integer,
    String,
    DateTime,
    ForeignKey,
    CheckConstraint,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class BloodReservation(Base):

    __tablename__ = "blood_reservations"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    blood_request_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "blood_requests.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    blood_inventory_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "blood_inventory.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    units_reserved: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )


    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="ACTIVE",
    )


    reserved_until: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


    blood_request = relationship(
    "BloodRequest",
    back_populates="reservations",
)


    blood_inventory = relationship(
        "BloodInventory",
    )


    __table_args__ = (

        CheckConstraint(
            "units_reserved > 0",
            name="check_reserved_units_positive",
        ),

        Index(
            "ix_blood_reservations_request_status",
            "blood_request_id",
            "status",
        ),

    )