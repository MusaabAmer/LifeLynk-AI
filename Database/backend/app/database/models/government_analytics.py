from uuid import uuid4

from sqlalchemy import (
    String,
    Integer,
    DateTime,
    JSON,
    Index,
    func,
)

from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class GovernmentAnalytics(Base):

    __tablename__ = "government_analytics"


    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


    metric_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )


    metric_value: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )


    region: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )


    extra_data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )


    generated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


    __table_args__ = (

        Index(
            "ix_government_analytics_metric_region",
            "metric_name",
            "region",
        ),

    )