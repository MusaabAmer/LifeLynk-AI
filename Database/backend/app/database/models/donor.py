from uuid import uuid4

from sqlalchemy import (
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Donor(Base):

    __tablename__ = "donors"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    user_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "users.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        unique=True,
    )


    blood_group_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "blood_groups.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    city_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "cities.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    phone_number: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )


    date_of_birth: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    gender: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )


    is_available: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )


    total_donations: Mapped[int] = mapped_column(
        nullable=False,
        default=0,
    )


    last_donation_date: Mapped[DateTime | None] = mapped_column(
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


    user = relationship(
        "User",
    )


    blood_group = relationship(
        "BloodGroup",
    )


    city = relationship(
        "City",
    )


    __table_args__ = (

        Index(
            "ix_donors_matching_search",
            "blood_group_id",
            "city_id",
            "is_available",
        ),

    )