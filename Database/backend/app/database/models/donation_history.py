from uuid import uuid4

from sqlalchemy import (
    Integer,
    Boolean,
    DateTime,
    ForeignKey,
    Text,
    CheckConstraint,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class DonationHistory(Base):

    __tablename__ = "donation_history"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    donor_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "donors.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
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


    units_donated: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )


    donation_date: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )


    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
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


    donor = relationship(
        "Donor",
    )


    organization = relationship(
        "Organization",
    )


    blood_group = relationship(
        "BloodGroup",
    )


    __table_args__ = (

        CheckConstraint(
            "units_donated > 0",
            name="check_units_donated_positive",
        ),

        Index(
            "ix_donation_history_donor_date",
            "donor_id",
            "donation_date",
        ),

    )