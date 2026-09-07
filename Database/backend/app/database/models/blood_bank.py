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


class BloodBank(Base, BaseModelMixin):

    __tablename__ = "blood_banks"


    organization_id: Mapped[str] = mapped_column(
        ForeignKey(
            "organizations.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        unique=True,
    )


    license_number: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )


    storage_capacity: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )


    cold_storage_available: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )


    blood_processing_available: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )


    operating_hours: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )


    organization = relationship(
        "Organization",
    )


Index(
    "ix_blood_banks_license_number",
    BloodBank.license_number,
)