from app.database.mixins.soft_delete import SoftDeleteMixin
from app.database.mixins.timestamp import TimestampMixin
from app.database.mixins.uuid_primary_key import UUIDPrimaryKeyMixin


class BaseModelMixin(
    UUIDPrimaryKeyMixin,
    TimestampMixin,
    SoftDeleteMixin,
):
    """Base mixin shared by all business models."""

    pass