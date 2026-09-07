from uuid import uuid4

from sqlalchemy import (
    String,
    DateTime,
    ForeignKey,
    Text,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class AIChatHistory(Base):

    __tablename__ = "ai_chat_history"


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


    question: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )


    response: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )


    model_used: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
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
            "ix_ai_chat_history_user_date",
            "user_id",
            "created_at",
        ),

    )