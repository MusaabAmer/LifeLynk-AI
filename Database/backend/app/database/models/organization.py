from sqlalchemy import (
    String,
    Boolean,
    ForeignKey,
    Enum,
    Index,
)

from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.database.base import Base
from app.database.mixins import BaseModelMixin

import enum


class OrganizationType(str, enum.Enum):
    HOSPITAL = "hospital"
    BLOOD_BANK = "blood_bank"


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"



class Organization(Base, BaseModelMixin):

    __tablename__ = "organizations"


    city_id: Mapped[str] = mapped_column(
        ForeignKey(
            "cities.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )


    organization_type: Mapped[OrganizationType] = mapped_column(
        Enum(
            OrganizationType,
            name="organization_type",
        ),
        nullable=False,
    )


    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )


    registration_number: Mapped[str | None] = mapped_column(
        String(100),
        unique=True,
        nullable=True,
    )


    phone: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )


    email: Mapped[str | None] = mapped_column(
        String(150),
        nullable=True,
    )


    address: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )


    latitude: Mapped[float | None]


    longitude: Mapped[float | None]


    verification_status: Mapped[VerificationStatus] = mapped_column(
        Enum(
            VerificationStatus,
            name="verification_status",
        ),
        default=VerificationStatus.PENDING,
        nullable=False,
    )
    
    staff_members = relationship(
    "OrganizationStaff",
    back_populates="organization",
    cascade="all, delete-orphan",
)


Index(
    "ix_organizations_name",
    Organization.name,
)