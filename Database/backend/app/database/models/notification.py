from uuid import uuid4

from sqlalchemy import (
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Text,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Notification(Base):

    __tablename__ = "notifications"


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


    title: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )


    message: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )


    notification_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )


    is_read: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )


    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


    user = relationship(
        "User",
    )


    __table_args__ = (

        Index(
            "ix_notifications_user_read",
            "user_id",
            "is_read",
        ),

    )