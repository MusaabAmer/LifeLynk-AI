from uuid import uuid4

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    ForeignKey,
    Text,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class EmergencySOS(Base):

    __tablename__ = "emergency_sos"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    user_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
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


    city_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "cities.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    units_required: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )


    urgency_level: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="HIGH",
    )


    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )


    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="OPEN",
    )


    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
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
            "ix_emergency_sos_search",
            "blood_group_id",
            "city_id",
            "status",
        ),

    )