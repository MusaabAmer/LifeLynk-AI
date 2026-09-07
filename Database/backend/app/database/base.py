from sqlalchemy.orm import DeclarativeBase

from app.database.metadata import metadata


class Base(DeclarativeBase):
    metadata = metadata