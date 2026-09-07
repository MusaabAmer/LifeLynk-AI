from uuid import uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class DonorAvailability(Base):

    __tablename__ = "donor_availability"


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
        unique=True,
    )


    is_available: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )


    last_checked_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


    next_eligible_date: Mapped[DateTime | None] = mapped_column(
        DateTime(timezone=True),
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


    __table_args__ = (

        Index(
            "ix_donor_availability_search",
            "is_available",
            "next_eligible_date",
        ),

    )