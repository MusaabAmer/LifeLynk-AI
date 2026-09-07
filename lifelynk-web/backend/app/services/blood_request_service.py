from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status

from app.repositories.blood_request_repository import (
    BloodRequestRepository,
)
from app.repositories.notification_repository import (
    NotificationRepository,
)
from app.repositories.organization_repository import (
    OrganizationRepository,
)
from app.services.notification_service import (
    NotificationService,
)


class BloodRequestService:
    def __init__(
        self,
        repository: BloodRequestRepository,
        notification_service: NotificationService | None = None,
        organization_repository: OrganizationRepository | None = None,
    ) -> None:
        self.repository = repository

        self.notification_service = notification_service

        self.organization_repository = organization_repository

    # ============================================================
    # NOTIFICATION HELPERS
    # ============================================================

    async def _notify_organization_members(
        self,
        organization_id: str,
        title: str,
        message: str,
        notification_type: str,
        exclude_user_id: str | None = None,
    ) -> None:
        """
        Send a notification to all active staff members of an
        organization.

        Notification delivery is intentionally best-effort:
        failure to create a notification must not roll back an
        already successful blood operation.
        """

        if (
            self.notification_service is None
            or self.organization_repository is None
        ):
            return

        try:
            members = (
                await self.organization_repository.get_members(
                    organization_id,
                )
            )

            for member in members:
                member_user_id = str(
                    member["user_id"],
                )

                if (
                    exclude_user_id is not None
                    and member_user_id == str(
                        exclude_user_id
                    )
                ):
                    continue

                await self.notification_service.create(
                    user_id=member_user_id,
                    title=title,
                    message=message,
                    notification_type=notification_type,
                )

        except Exception:
            # Notifications are secondary to the successful blood
            # operation. Never convert a successful request,
            # reservation, or status change into an API failure
            # merely because notification delivery failed.
            return

    async def _notify_user(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
    ) -> None:
        """
        Send one notification to a specific real application user.

        Notification delivery is best-effort and never changes the
        result of the underlying blood operation.
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

    # ============================================================
    # RESERVE BLOOD
    # ============================================================

    async def reserve_blood(
        self,
        requester_id: str,
        organization_id: str,
        blood_group_id: str,
        units_required: int,
        urgency: str,
        required_date: datetime,
        notes: str | None,
    ):
        if units_required <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Required blood units must be "
                    "greater than zero."
                ),
            )

        # --------------------------------------------------------
        # Normalize required date to UTC
        # --------------------------------------------------------

        now = datetime.now(
            timezone.utc,
        )

        if required_date.tzinfo is None:
            required_date = required_date.replace(
                tzinfo=timezone.utc,
            )
        else:
            required_date = required_date.astimezone(
                timezone.utc,
            )

        if required_date <= now:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Required date must be in the future."
                ),
            )

        # --------------------------------------------------------
        # Resolve patient from authenticated user
        # --------------------------------------------------------

        patient_id = await self.repository.get_patient_id(
            requester_id,
        )

        if patient_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "A patient profile is required "
                    "before reserving blood."
                ),
            )

        try:
            result = await self.repository.create_reservation(
                requester_id=requester_id,
                organization_id=organization_id,
                patient_id=patient_id,
                blood_group_id=blood_group_id,
                units_required=units_required,
                urgency=urgency,
                required_date=required_date,
                notes=notes,
            )

        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(exc),
            ) from exc

        # --------------------------------------------------------
        # Notification: reservation confirmation
        # --------------------------------------------------------

        request = result.get("request")

        if request is not None:
            organization_name = (
                request.get("organization_name")
                or "the selected organization"
            )

            blood_group_code = (
                request.get("blood_group_code")
                or "requested blood group"
            )

            request_id = str(
                request["id"],
            )

            await self._notify_user(
                user_id=requester_id,
                title="Blood Reservation Confirmed",
                message=(
                    f"Your reservation for "
                    f"{units_required} unit(s) of "
                    f"{blood_group_code} at "
                    f"{organization_name} has been created "
                    f"successfully. Request ID: {request_id}."
                ),
                notification_type="BLOOD_RESERVATION",
            )

            # ----------------------------------------------------
            # Notification: organization staff
            # ----------------------------------------------------

            await self._notify_organization_members(
                organization_id=organization_id,
                title="New Blood Reservation",
                message=(
                    f"A new reservation has been created for "
                    f"{units_required} unit(s) of "
                    f"{blood_group_code}. "
                    f"Request ID: {request_id}."
                ),
                notification_type="BLOOD_RESERVATION",
                exclude_user_id=requester_id,
            )

        return result

    # ============================================================
    # CREATE NORMAL BLOOD REQUEST
    # ============================================================

    async def create(
        self,
        requester_id: str,
        organization_id: str,
        data: dict[str, Any],
    ):
        request = await self.repository.create(
            requester_id,
            organization_id,
            data,
        )

        # --------------------------------------------------------
        # Notify real organization staff.
        #
        # The requester is excluded because they created the
        # request themselves.
        # --------------------------------------------------------

        blood_group_code = (
            request.get("blood_group_code")
            or "requested blood group"
        )

        units_required = request.get(
            "units_required",
            data.get("units_required"),
        )

        request_id = str(
            request["id"],
        )

        await self._notify_organization_members(
            organization_id=organization_id,
            title="New Blood Request",
            message=(
                f"A new blood request has been created for "
                f"{units_required} unit(s) of "
                f"{blood_group_code}. "
                f"Request ID: {request_id}."
            ),
            notification_type="BLOOD_REQUEST",
            exclude_user_id=requester_id,
        )

        return request

    # ============================================================
    # GET BLOOD REQUEST
    # ============================================================

    async def get(
        self,
        request_id: str,
    ):
        request = await self.repository.get_by_id(
            request_id,
        )

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Blood request not found.",
            )

        return request

    # ============================================================
    # LIST USER REQUESTS
    # ============================================================

    async def list_for_user(
        self,
        user_id: str,
    ):
        return await self.repository.list_for_user(
            user_id,
        )

    # ============================================================
    # LIST ORGANIZATION REQUESTS
    # ============================================================

    async def list_for_organization(
        self,
        organization_id: str,
    ):
        return await self.repository.list_for_organization(
            organization_id,
        )

    # ============================================================
    # UPDATE REQUEST
    # ============================================================

    async def update(
        self,
        request_id: str,
        requester_id: str,
        fields: dict[str, Any],
    ):
        request = await self.repository.update(
            request_id,
            requester_id,
            fields,
        )

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "Blood request not found, "
                    "does not belong to you, or "
                    "cannot be edited."
                ),
            )

        return request

    # ============================================================
    # CANCEL REQUEST
    # ============================================================

    async def cancel(
        self,
        request_id: str,
        requester_id: str,
    ):
        # --------------------------------------------------------
        # Fetch first so we know the target organization before
        # changing the request status.
        # --------------------------------------------------------

        existing = await self.repository.get_by_id(
            request_id,
        )

        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "Blood request not found "
                    "or cannot be cancelled."
                ),
            )

        if str(existing["requester_id"]) != str(
            requester_id
        ):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "Blood request not found "
                    "or cannot be cancelled."
                ),
            )

        organization_id = str(
            existing["organization_id"],
        )

        request = await self.repository.update_status(
            request_id,
            "CANCELLED",
            requester_id=requester_id,
        )

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "Blood request not found "
                    "or cannot be cancelled."
                ),
            )

        # --------------------------------------------------------
        # Notify organization staff.
        # --------------------------------------------------------

        blood_group_code = (
            request.get("blood_group_code")
            or "requested blood group"
        )

        await self._notify_organization_members(
            organization_id=organization_id,
            title="Blood Request Cancelled",
            message=(
                f"Blood request {request_id} for "
                f"{request.get('units_required', 0)} unit(s) "
                f"of {blood_group_code} has been cancelled "
                "by the requester."
            ),
            notification_type="BLOOD_REQUEST_CANCELLED",
            exclude_user_id=requester_id,
        )

        return request

    # ============================================================
    # ORGANIZATION STATUS UPDATE
    # ============================================================

    async def update_organization_status(
        self,
        request_id: str,
        organization_id: str,
        new_status: str,
    ):
        request = await self.repository.get_by_id(
            request_id,
        )

        if request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Blood request not found.",
            )

        if str(request["organization_id"]) != str(
            organization_id
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "You do not have access to "
                    "this blood request."
                ),
            )

        allowed_transitions = {
            "PENDING": {
                "MATCHED",
                "IN_PROGRESS",
                "REJECTED",
                "FULFILLED",
            },
            "MATCHED": {
                "IN_PROGRESS",
                "FULFILLED",
                "CANCELLED",
            },
            "IN_PROGRESS": {
                "FULFILLED",
                "CANCELLED",
            },
        }

        current_status = request["status"]

        if new_status not in allowed_transitions.get(
            current_status,
            set(),
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Invalid status transition: "
                    f"{current_status} -> {new_status}"
                ),
            )

        updated = await self.repository.update_status(
            request_id,
            new_status,
            organization_id=organization_id,
        )

        if updated is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Blood request could not be updated."
                ),
            )

        # --------------------------------------------------------
        # Notify the real requester.
        # --------------------------------------------------------

        requester_id = updated.get(
            "requester_id",
        )

        if requester_id is not None:
            blood_group_code = (
                updated.get("blood_group_code")
                or "requested blood group"
            )

            units_required = updated.get(
                "units_required",
                0,
            )

            await self._notify_user(
                user_id=str(requester_id),
                title="Blood Request Status Updated",
                message=(
                    f"Your blood request {request_id} for "
                    f"{units_required} unit(s) of "
                    f"{blood_group_code} has changed from "
                    f"{current_status} to {new_status}."
                ),
                notification_type="BLOOD_REQUEST_STATUS",
            )

        return updated