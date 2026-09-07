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


class AuditLog(Base):

    __tablename__ = "audit_logs"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    user_id: Mapped[UUID] = mapped_column(
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )


    action: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )


    entity_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )


    entity_id: Mapped[UUID | None] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
    )


    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )


    ip_address: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
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
            "ix_audit_logs_user_action",
            "user_id",
            "action",
        ),

        Index(
            "ix_audit_logs_entity",
            "entity_type",
            "entity_id",
        ),

    )