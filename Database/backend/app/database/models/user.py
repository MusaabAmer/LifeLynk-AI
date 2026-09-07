from datetime import datetime

from sqlalchemy import (
    Boolean,
    ForeignKey,
    String,
    DateTime,
    Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.mixins import BaseModelMixin


class User(Base, BaseModelMixin):
    __tablename__ = "users"

    role_id: Mapped[str] = mapped_column(
        ForeignKey("roles.id"),
        nullable=False,
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
    )

    full_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    phone_number: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # ---------------- Relationships ---------------- #

    role = relationship(
        "Role",
        back_populates="users",
    )

    refresh_tokens = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    patient = relationship(
        "Patient",
        back_populates="user",
        uselist=False,
    )

    organization_staff = relationship(
        "OrganizationStaff",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    blood_requests = relationship(
        "BloodRequest",
        back_populates="requester",
        cascade="all, delete-orphan",
    )

    notifications = relationship(
        "Notification",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    emergency_sos = relationship(
        "EmergencySOS",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    audit_logs = relationship(
        "AuditLog",
        back_populates="user",
    )

    ai_chat_history = relationship(
        "AIChatHistory",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index(
            "ix_users_email",
            "email",
        ),
    )