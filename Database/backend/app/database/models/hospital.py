from sqlalchemy import (
    String,
    Boolean,
    Integer,
    ForeignKey,
    Index,
)

from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class Hospital(Base, BaseModelMixin):

    __tablename__ = "hospitals"


    organization_id: Mapped[str] = mapped_column(
        ForeignKey(
            "organizations.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        unique=True,
    )


    hospital_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )


    license_number: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )


    emergency_service: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )


    blood_storage_available: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )


    total_beds: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )


    icu_available: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )


    organization = relationship(
        "Organization",
    )


Index(
    "ix_hospitals_license_number",
    Hospital.license_number,
)