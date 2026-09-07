from sqlalchemy import String, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class Province(Base, BaseModelMixin):

    __tablename__ = "provinces"


    name: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )


    code: Mapped[str] = mapped_column(
        String(10),
        unique=True,
        nullable=False,
    )


    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )


    cities = relationship(
    "City",
    back_populates="province",
)


Index(
    "ix_provinces_name",
    Province.name,
)