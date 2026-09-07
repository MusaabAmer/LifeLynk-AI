from enum import Enum


class OrganizationType(str, Enum):
    HOSPITAL = "HOSPITAL"
    BLOOD_BANK = "BLOOD_BANK"
    NGO = "NGO"