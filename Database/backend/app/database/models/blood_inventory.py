from uuid import uuid4

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    ForeignKey,
    CheckConstraint,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class BloodInventory(Base):

    __tablename__ = "blood_inventory"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    organization_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "organizations.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    blood_group_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "blood_groups.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    total_units: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )


    available_units: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )


    reserved_units: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )


    donation_date: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    expiry_date: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    storage_location: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )


    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="AVAILABLE",
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


    organization = relationship(
        "Organization",
    )


    blood_group = relationship(
        "BloodGroup",
    )


    __table_args__ = (

        CheckConstraint(
            "total_units >= 0",
            name="check_total_units_positive",
        ),

        CheckConstraint(
            "available_units >= 0",
            name="check_available_units_positive",
        ),

        CheckConstraint(
            "reserved_units >= 0",
            name="check_reserved_units_positive",
        ),

        CheckConstraint(
            "available_units + reserved_units <= total_units",
            name="check_inventory_balance",
        ),

        Index(
            "ix_blood_inventory_org_group",
            "organization_id",
            "blood_group_id",
        ),

    )