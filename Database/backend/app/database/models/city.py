from sqlalchemy import (
    String,
    Boolean,
    ForeignKey,
    Index,
    Numeric,
    UniqueConstraint,
)

from decimal import Decimal

from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class City(Base, BaseModelMixin):

    __tablename__ = "cities"

    province_id = mapped_column(
        ForeignKey("provinces.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    name = mapped_column(
        String(100),
        nullable=False,
    )

    code = mapped_column(
        String(20),
        nullable=False,
        unique=True,
    )

    latitude: Mapped[Decimal | None] = mapped_column(
    Numeric(9, 6),
    nullable=True,
)

    longitude: Mapped[Decimal | None] = mapped_column(
    Numeric(9, 6),
    nullable=True,
)

    is_active = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    province = relationship(
        "Province",
        back_populates="cities",
    )

    __table_args__ = (
    UniqueConstraint(
        "province_id",
        "name",
        name="uq_city_province_name",
    ),
    Index(
        "ix_cities_province_name",
        "province_id",
        "name",
    ),
)