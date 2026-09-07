from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column , relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin



class BloodGroup(Base, BaseModelMixin):

    __tablename__ = "blood_groups"


    code: Mapped[str] = mapped_column(
        String(5),
        unique=True,
        nullable=False,
    )


    name: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
    )
    
    patients = relationship(
    "Patient",
    )