from enum import Enum


class AuditAction(str, Enum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"
    LOGIN = "LOGIN"
    LOGOUT = "LOGOUT"
    APPROVE = "APPROVE"
    REJECT = "REJECT"
    RESERVE = "RESERVE"
    FULFILL = "FULFILL"
    EXPORT = "EXPORT"