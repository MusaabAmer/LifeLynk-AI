from datetime import datetime

from sqlalchemy import (
    ForeignKey,
    Text,
    DateTime,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class RefreshToken(Base, BaseModelMixin):

    __tablename__ = "refresh_tokens"


    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )


    token_hash: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )


    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )


    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )


    user = relationship(
        "User",
        back_populates="refresh_tokens",
    )