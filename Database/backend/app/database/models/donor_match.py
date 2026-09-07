from uuid import uuid4

from sqlalchemy import (
    Integer,
    Float,
    String,
    DateTime,
    ForeignKey,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class DonorMatch(Base):

    __tablename__ = "donor_matches"


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


    donor_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "donors.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    compatibility_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )


    distance_km: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )


    ai_reason: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )


    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="PENDING",
    )


    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


    blood_request = relationship(
        "BloodRequest",
    )


    donor = relationship(
        "Donor",
    )


    __table_args__ = (

        Index(
            "ix_donor_matches_request_score",
            "blood_request_id",
            "compatibility_score",
        ),

    )