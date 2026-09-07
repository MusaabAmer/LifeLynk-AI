from fastapi import HTTPException, status

from app.repositories.notification_repository import (
    NotificationRepository,
)
from app.repositories.sos_repository import SosRepository
from app.services.notification_service import NotificationService


class SosService:
    # ============================================================
    # HEALTHCARE NOTIFICATION RECIPIENTS
    #
    # These are real roles from public.roles.
    #
    # We intentionally do not invent an organization/responder
    # assignment because emergency_sos does not contain one.
    # ============================================================

    _HEALTHCARE_NOTIFICATION_ROLES = [
        "HOSPITAL_ADMIN",
        "BLOOD_BANK_ADMIN",
        "GOVERNMENT_ADMIN",
        "SUPER_ADMIN",
    ]

    def __init__(
        self,
        repository: SosRepository,
        notification_service: NotificationService | None = None,
    ) -> None:
        self.repository = repository
        self.notification_service = notification_service

    # ============================================================
    # NOTIFICATION HELPERS
    # ============================================================

    async def _notify_user(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
    ) -> None:
        """
        Notification delivery is best-effort.

        A notification failure must never turn a successfully
        completed emergency operation into an API failure.
        """

        if self.notification_service is None:
            return

        try:
            await self.notification_service.create(
                user_id=str(user_id),
                title=title,
                message=message,
                notification_type=notification_type,
            )
        except Exception:
            return

    async def _notify_healthcare_users(
        self,
        title: str,
        message: str,
        notification_type: str,
        exclude_user_id: str | None = None,
    ) -> None:
        """
        Notify active healthcare/admin users using the real roles
        stored in public.roles.

        No organization or responder is fabricated.
        """

        if self.notification_service is None:
            return

        try:
            user_ids = (
                await self.notification_service
                .get_user_ids_by_roles(
                    roles=self._HEALTHCARE_NOTIFICATION_ROLES,
                    exclude_user_id=exclude_user_id,
                )
            )

            for user_id in user_ids:
                await self._notify_user(
                    user_id=user_id,
                    title=title,
                    message=message,
                    notification_type=notification_type,
                )

        except Exception:
            return

    # ============================================================
    # CREATE SOS
    # ============================================================

    async def create(
        self,
        user_id: str,
        data: dict,
    ):
        active = await self.repository.get_active_for_user(
            user_id,
        )

        if active is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "You already have an active emergency SOS. "
                    "Cancel or complete it before creating another SOS."
                ),
            )

        sos = await self.repository.create(
            user_id,
            data,
        )

        # --------------------------------------------------------
        # Confirmation to the SOS creator
        # --------------------------------------------------------

        sos_id = str(sos["id"])

        blood_group_code = (
            sos.get("blood_group_code")
            or "requested blood group"
        )

        units_required = sos.get(
            "units_required",
            0,
        )

        await self._notify_user(
            user_id=user_id,
            title="Emergency SOS Activated",
            message=(
                f"Your emergency SOS has been activated for "
                f"{units_required} unit(s) of "
                f"{blood_group_code}. "
                f"SOS ID: {sos_id}."
            ),
            notification_type="SOS_CREATED",
        )

        # --------------------------------------------------------
        # Notify active healthcare/admin users
        # --------------------------------------------------------

        await self._notify_healthcare_users(
            title="New Emergency SOS",
            message=(
                f"A new emergency SOS requires attention. "
                f"Requested blood: {units_required} unit(s) "
                f"of {blood_group_code}. "
                f"SOS ID: {sos_id}."
            ),
            notification_type="SOS_CREATED",
            exclude_user_id=user_id,
        )

        return sos

    # ============================================================
    # LIST USER SOS
    # ============================================================

    async def list_for_user(
        self,
        user_id: str,
    ):
        return await self.repository.list_for_user(
            user_id,
        )

    # ============================================================
    # GET SOS
    # ============================================================

    async def get(
        self,
        sos_id: str,
    ):
        sos = await self.repository.get_by_id(
            sos_id,
        )

        if sos is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Emergency SOS not found.",
            )

        return sos

    # ============================================================
    # GET ACTIVE SOS
    # ============================================================

    async def get_active(
        self,
        user_id: str,
    ):
        return await self.repository.get_active_for_user(
            user_id,
        )

    # ============================================================
    # UPDATE SOS
    # ============================================================

    async def update(
        self,
        sos_id: str,
        user_id: str,
        fields: dict,
    ):
        sos = await self.repository.update(
            sos_id,
            user_id,
            fields,
        )

        if sos is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "SOS not found, does not belong to you, "
                    "or can no longer be updated."
                ),
            )

        return sos

    # ============================================================
    # CANCEL SOS
    # ============================================================

    async def cancel(
        self,
        sos_id: str,
        user_id: str,
    ):
        current = await self.repository.get_by_id(
            sos_id,
        )

        if current is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Emergency SOS not found.",
            )

        if current["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have access to this SOS.",
            )

        if current["status"] not in {
            "pending",
            "matched",
            "in_progress",
        }:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This SOS cannot be cancelled.",
            )

        result = await self.repository.update_status(
            sos_id,
            "cancelled",
            user_id=user_id,
        )

        if result is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="SOS cancellation failed.",
            )

        # --------------------------------------------------------
        # Notify healthcare users that the active SOS was
        # cancelled by the requester.
        # --------------------------------------------------------

        blood_group_code = (
            result.get("blood_group_code")
            or "requested blood group"
        )

        await self._notify_healthcare_users(
            title="Emergency SOS Cancelled",
            message=(
                f"Emergency SOS {sos_id} has been cancelled "
                f"by the requester. "
                f"Requested blood: {blood_group_code}."
            ),
            notification_type="SOS_CANCELLED",
            exclude_user_id=user_id,
        )

        return result

    # ============================================================
    # COMPLETE SOS
    # ============================================================

    async def complete(
        self,
        sos_id: str,
        user_id: str,
    ):
        current = await self.repository.get_by_id(
            sos_id,
        )

        if current is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Emergency SOS not found.",
            )

        if current["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have access to this SOS.",
            )

        if current["status"] not in {
            "matched",
            "in_progress",
        }:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Only matched or in-progress SOS requests "
                    "can be completed."
                ),
            )

        result = await self.repository.update_status(
            sos_id,
            "completed",
            user_id=user_id,
        )

        if result is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="SOS completion failed.",
            )

        # --------------------------------------------------------
        # Notify healthcare users.
        # --------------------------------------------------------

        await self._notify_healthcare_users(
            title="Emergency SOS Completed",
            message=(
                f"Emergency SOS {sos_id} has been completed "
                "by the requester."
            ),
            notification_type="SOS_COMPLETED",
            exclude_user_id=user_id,
        )

        return result

    # ============================================================
    # OPERATOR STATUS UPDATE
    # ============================================================

    async def update_status_from_operator(
        self,
        sos_id: str,
        new_status: str,
    ):
        current = await self.repository.get_by_id(
            sos_id,
        )

        if current is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Emergency SOS not found.",
            )

        transitions = {
            "pending": {
                "matched",
                "cancelled",
            },
            "matched": {
                "in_progress",
                "cancelled",
                "completed",
            },
            "in_progress": {
                "completed",
                "cancelled",
            },
        }

        current_status = current["status"]

        if new_status not in transitions.get(
            current_status,
            set(),
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Invalid SOS status transition: "
                    f"{current_status} -> {new_status}"
                ),
            )

        result = await self.repository.update_status(
            sos_id,
            new_status,
        )

        if result is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="SOS status update failed.",
            )

        # --------------------------------------------------------
        # Notify the actual SOS owner.
        # --------------------------------------------------------

        owner_id = result.get(
            "user_id",
        )

        if owner_id is not None:
            await self._notify_user(
                user_id=str(owner_id),
                title="Emergency SOS Status Updated",
                message=(
                    f"Your emergency SOS {sos_id} has changed "
                    f"from {current_status} to {new_status}."
                ),
                notification_type="SOS_STATUS",
            )

        return result