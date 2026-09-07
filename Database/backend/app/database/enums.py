from enum import Enum


class UserRole(str, Enum):
    ADMIN = "admin"
    PATIENT = "patient"
    HOSPITAL_STAFF = "hospital_staff"
    BLOOD_BANK_STAFF = "blood_bank_staff"
    GOVERNMENT = "government"


class BloodGroup(str, Enum):
    A_POSITIVE = "A+"
    A_NEGATIVE = "A-"
    B_POSITIVE = "B+"
    B_NEGATIVE = "B-"
    AB_POSITIVE = "AB+"
    AB_NEGATIVE = "AB-"
    O_POSITIVE = "O+"
    O_NEGATIVE = "O-"


class ReservationStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    EXPIRED = "expired"