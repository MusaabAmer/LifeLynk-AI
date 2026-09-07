from fastapi import APIRouter

from app.api.v1 import (
    blood_banks,
    blood_requests,
    donors,
    health,
    hospitals,
    inventory,
    me,
    notifications,
    organizations,
    search,
    sos,
)

router = APIRouter()

router.include_router(health.router)
router.include_router(me.router)
router.include_router(organizations.router)
router.include_router(hospitals.router)
router.include_router(blood_banks.router)
router.include_router(inventory.router)
router.include_router(donors.router)
router.include_router(blood_requests.router)
router.include_router(sos.router)
router.include_router(notifications.router)
router.include_router(search.router)