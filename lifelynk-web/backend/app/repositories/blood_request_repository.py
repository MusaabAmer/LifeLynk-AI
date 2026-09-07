from typing import Any

import asyncpg


class BloodRequestRepository:
    def __init__(
        self,
        connection: asyncpg.Connection,
    ) -> None:
        self.connection = connection

    # ============================================================
    # CREATE NORMAL BLOOD REQUEST
    # ============================================================

    async def create(
        self,
        requester_id: str,
        organization_id: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:

        row = await self.connection.fetchrow(
            """
            INSERT INTO public.blood_requests (
                requester_id,
                organization_id,
                blood_group_id,
                units_required,
                urgency,
                status,
                required_date,
                notes,
                patient_id
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                'PENDING',
                $6,
                $7,
                $8
            )
            RETURNING id
            """,
            requester_id,
            organization_id,
            data["blood_group_id"],
            data["units_required"],
            data["urgency"],
            data["required_date"],
            data.get("notes"),
            data["patient_id"],
        )

        return await self.get_by_id(
            str(row["id"]),
        )

    # ============================================================
    # GET PATIENT ID FOR AUTHENTICATED USER
    # ============================================================

    async def get_patient_id(
        self,
        user_id: str,
    ) -> str | None:

        row = await self.connection.fetchrow(
            """
            SELECT id
            FROM public.patients
            WHERE user_id = $1
              AND deleted_at IS NULL
            LIMIT 1
            """,
            user_id,
        )

        if row is None:
            return None

        return str(row["id"])

    # ============================================================
    # CREATE BLOOD RESERVATION
    #
    # Uses a single database transaction.
    #
    # Inventory is allocated using FEFO:
    # First Expiry, First Out.
    #
    # Multiple inventory lots can satisfy one reservation.
    # ============================================================

    async def create_reservation(
        self,
        requester_id: str,
        organization_id: str,
        patient_id: str,
        blood_group_id: str,
        units_required: int,
        urgency: str,
        required_date,
        notes: str | None,
    ) -> dict[str, Any]:

        async with self.connection.transaction():

            # ====================================================
            # VERIFY ORGANIZATION
            # ====================================================

            organization = await self.connection.fetchrow(
                """
                SELECT
                    id,
                    name
                FROM public.organizations
                WHERE id = $1
                  AND verification_status = 'VERIFIED'
                  AND deleted_at IS NULL
                FOR UPDATE
                """,
                organization_id,
            )

            if organization is None:
                raise ValueError(
                    "Organization is not verified or does not exist."
                )

            # ====================================================
            # VERIFY BLOOD GROUP
            # ====================================================

            blood_group = await self.connection.fetchrow(
                """
                SELECT
                    id,
                    code,
                    name
                FROM public.blood_groups
                WHERE id = $1
                  AND deleted_at IS NULL
                LIMIT 1
                """,
                blood_group_id,
            )

            if blood_group is None:
                raise ValueError(
                    "The requested blood group does not exist."
                )

            # ====================================================
            # VERIFY PATIENT
            # ====================================================

            patient = await self.connection.fetchrow(
                """
                SELECT
                    id
                FROM public.patients
                WHERE id = $1
                  AND user_id = $2
                  AND deleted_at IS NULL
                LIMIT 1
                """,
                patient_id,
                requester_id,
            )

            if patient is None:
                raise ValueError(
                    "Patient profile is invalid."
                )

            # ====================================================
            # LOCK AVAILABLE INVENTORY
            #
            # FEFO:
            # earliest expiry first.
            #
            # We intentionally do not require one inventory row
            # to contain the complete requested quantity.
            # ====================================================

            inventory_rows = await self.connection.fetch(
                """
                SELECT
                    bi.id,
                    bi.organization_id,
                    bi.blood_group_id,
                    bi.total_units,
                    bi.available_units,
                    bi.reserved_units,
                    bi.donation_date,
                    bi.expiry_date,
                    bi.storage_location,
                    bi.status,
                    bi.created_at,
                    bi.updated_at
                FROM public.blood_inventory AS bi
                WHERE bi.organization_id = $1
                  AND bi.blood_group_id = $2
                  AND bi.available_units > 0
                  AND bi.expiry_date > NOW()
                ORDER BY
                    bi.expiry_date ASC,
                    bi.created_at ASC,
                    bi.id ASC
                FOR UPDATE OF bi
                """,
                organization_id,
                blood_group_id,
            )

            if not inventory_rows:
                raise ValueError(
                    "The requested blood units are not available."
                )

            # ====================================================
            # CHECK TOTAL AVAILABILITY
            # ====================================================

            total_available = sum(
                int(row["available_units"])
                for row in inventory_rows
            )

            if total_available < units_required:
                raise ValueError(
                    "The requested blood units are not available. "
                    f"Only {total_available} unit(s) are currently "
                    "available."
                )

            # ====================================================
            # FEFO ALLOCATION
            # ====================================================

            remaining = units_required

            allocations: list[dict[str, Any]] = []

            for row in inventory_rows:

                if remaining <= 0:
                    break

                available_units = int(
                    row["available_units"]
                )

                units_from_lot = min(
                    available_units,
                    remaining,
                )

                if units_from_lot <= 0:
                    continue

                allocations.append(
                    {
                        "inventory_id": row["id"],
                        "units": units_from_lot,
                        "expiry_date": row["expiry_date"],
                    }
                )

                remaining -= units_from_lot

            if remaining > 0:
                raise ValueError(
                    "Blood inventory changed before reservation."
                )

            # ====================================================
            # CREATE BLOOD REQUEST
            # ====================================================

            request = await self.connection.fetchrow(
                """
                INSERT INTO public.blood_requests (
                    requester_id,
                    organization_id,
                    blood_group_id,
                    units_required,
                    urgency,
                    status,
                    required_date,
                    notes,
                    patient_id
                )
                VALUES (
                    $1,
                    $2,
                    $3,
                    $4,
                    $5,
                    'PENDING',
                    $6,
                    $7,
                    $8
                )
                RETURNING id
                """,
                requester_id,
                organization_id,
                blood_group_id,
                units_required,
                urgency,
                required_date,
                notes,
                patient_id,
            )

            if request is None:
                raise ValueError(
                    "Blood request could not be created."
                )

            request_id = request["id"]

            reservation_rows: list[dict[str, Any]] = []

            inventory_results: list[dict[str, Any]] = []

            # ====================================================
            # UPDATE INVENTORY + CREATE RESERVATIONS
            # ====================================================

            for allocation in allocations:

                inventory_id = allocation["inventory_id"]

                units = allocation["units"]

                # ------------------------------------------------
                # MOVE AVAILABLE -> RESERVED
                # ------------------------------------------------

                updated_inventory = (
                    await self.connection.fetchrow(
                        """
                        UPDATE public.blood_inventory
                        SET
                            available_units =
                                available_units - $1,
                            reserved_units =
                                reserved_units + $1,
                            updated_at = NOW()
                        WHERE id = $2
                          AND available_units >= $1
                        RETURNING
                            id,
                            organization_id,
                            blood_group_id,
                            total_units,
                            available_units,
                            reserved_units,
                            donation_date,
                            expiry_date,
                            storage_location,
                            status,
                            created_at,
                            updated_at
                        """,
                        units,
                        inventory_id,
                    )
                )

                if updated_inventory is None:
                    raise ValueError(
                        "Blood inventory changed before reservation."
                    )

                inventory_results.append(
                    dict(updated_inventory)
                )

                # ------------------------------------------------
                # CREATE RESERVATION RECORD
                # ------------------------------------------------

                reservation = await self.connection.fetchrow(
                    """
                    INSERT INTO public.blood_reservations (
                        blood_request_id,
                        blood_inventory_id,
                        units_reserved,
                        status,
                        reserved_until
                    )
                    VALUES (
                        $1,
                        $2,
                        $3,
                        'ACTIVE',
                        LEAST(
                            $4,
                            NOW() + INTERVAL '24 hours'
                        )
                    )
                    RETURNING
                        id,
                        blood_request_id,
                        blood_inventory_id,
                        units_reserved,
                        status,
                        reserved_until,
                        created_at,
                        updated_at
                    """,
                    request_id,
                    inventory_id,
                    units,
                    required_date,
                )

                if reservation is None:
                    raise ValueError(
                        "Blood reservation could not be created."
                    )

                reservation_rows.append(
                    dict(reservation)
                )

            # ====================================================
            # FETCH FINAL REQUEST
            # ====================================================

            result = await self.connection.fetchrow(
                """
                SELECT
                    br.id,
                    br.requester_id,
                    br.organization_id,
                    o.name AS organization_name,
                    br.blood_group_id,
                    bg.code AS blood_group_code,
                    bg.name AS blood_group_name,
                    br.units_required,
                    br.urgency,
                    br.status,
                    br.required_date,
                    br.notes,
                    br.patient_id,
                    br.created_at,
                    br.updated_at
                FROM public.blood_requests AS br
                INNER JOIN public.organizations AS o
                    ON o.id = br.organization_id
                INNER JOIN public.blood_groups AS bg
                    ON bg.id = br.blood_group_id
                WHERE br.id = $1
                  AND br.deleted_at IS NULL
                LIMIT 1
                """,
                request_id,
            )

            if result is None:
                raise ValueError(
                    "Blood request could not be retrieved "
                    "after creation."
                )

            return {
                "request": dict(result),
                "reservations": reservation_rows,
                "inventory": inventory_results,
            }

    # ============================================================
    # GET BLOOD REQUEST
    # ============================================================

    async def get_by_id(
        self,
        request_id: str,
    ) -> dict[str, Any] | None:

        row = await self.connection.fetchrow(
            """
            SELECT
                br.id,
                br.requester_id,
                br.organization_id,
                o.name AS organization_name,
                br.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                br.units_required,
                br.urgency,
                br.status,
                br.required_date,
                br.notes,
                br.patient_id,
                br.created_at,
                br.updated_at
            FROM public.blood_requests AS br
            INNER JOIN public.organizations AS o
                ON o.id = br.organization_id
            INNER JOIN public.blood_groups AS bg
                ON bg.id = br.blood_group_id
            WHERE br.id = $1
              AND br.deleted_at IS NULL
            LIMIT 1
            """,
            request_id,
        )

        return dict(row) if row else None

    # ============================================================
    # LIST USER BLOOD REQUESTS
    # ============================================================

    async def list_for_user(
        self,
        user_id: str,
    ) -> list[dict[str, Any]]:

        rows = await self.connection.fetch(
            """
            SELECT
                br.id,
                br.requester_id,
                br.organization_id,
                o.name AS organization_name,
                br.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                br.units_required,
                br.urgency,
                br.status,
                br.required_date,
                br.notes,
                br.patient_id,
                br.created_at,
                br.updated_at
            FROM public.blood_requests AS br
            INNER JOIN public.organizations AS o
                ON o.id = br.organization_id
            INNER JOIN public.blood_groups AS bg
                ON bg.id = br.blood_group_id
            WHERE br.requester_id = $1
              AND br.deleted_at IS NULL
            ORDER BY br.created_at DESC
            """,
            user_id,
        )

        return [
            dict(row)
            for row in rows
        ]

    # ============================================================
    # LIST ORGANIZATION BLOOD REQUESTS
    # ============================================================

    async def list_for_organization(
        self,
        organization_id: str,
    ) -> list[dict[str, Any]]:

        rows = await self.connection.fetch(
            """
            SELECT
                br.id,
                br.requester_id,
                br.organization_id,
                o.name AS organization_name,
                br.blood_group_id,
                bg.code AS blood_group_code,
                bg.name AS blood_group_name,
                br.units_required,
                br.urgency,
                br.status,
                br.required_date,
                br.notes,
                br.patient_id,
                br.created_at,
                br.updated_at
            FROM public.blood_requests AS br
            INNER JOIN public.organizations AS o
                ON o.id = br.organization_id
            INNER JOIN public.blood_groups AS bg
                ON bg.id = br.blood_group_id
            WHERE br.organization_id = $1
              AND br.deleted_at IS NULL
            ORDER BY br.created_at DESC
            """,
            organization_id,
        )

        return [
            dict(row)
            for row in rows
        ]

    # ============================================================
    # UPDATE USER BLOOD REQUEST
    # ============================================================

    async def update(
        self,
        request_id: str,
        requester_id: str,
        fields: dict[str, Any],
    ) -> dict[str, Any] | None:

        allowed = {
            "urgency",
            "required_date",
            "notes",
        }

        fields = {
            key: value
            for key, value in fields.items()
            if key in allowed
        }

        if not fields:
            return await self.get_by_id(
                request_id,
            )

        assignments: list[str] = []

        values: list[Any] = []

        for index, (
            column,
            value,
        ) in enumerate(
            fields.items(),
            start=1,
        ):
            assignments.append(
                f"{column} = ${index}"
            )

            values.append(value)

        values.extend(
            [
                request_id,
                requester_id,
            ]
        )

        request_position = len(values) - 1

        requester_position = len(values)

        row = await self.connection.fetchrow(
            f"""
            UPDATE public.blood_requests
            SET
                {", ".join(assignments)},
                updated_at = NOW()
            WHERE id = ${request_position}
              AND requester_id = ${requester_position}
              AND deleted_at IS NULL
              AND status = 'PENDING'
            RETURNING id
            """,
            *values,
        )

        if not row:
            return None

        return await self.get_by_id(
            request_id,
        )

    # ============================================================
    # UPDATE BLOOD REQUEST STATUS
    # ============================================================

    async def update_status(
        self,
        request_id: str,
        status: str,
        organization_id: str | None = None,
        requester_id: str | None = None,
    ) -> dict[str, Any] | None:

        # $1 = status
        # $2 = request_id

        conditions = [
            "id = $2",
            "deleted_at IS NULL",
        ]

        values: list[Any] = [
            status,
            request_id,
        ]

        if organization_id:

            values.append(
                organization_id,
            )

            conditions.append(
                f"organization_id = ${len(values)}"
            )

        if requester_id:

            values.append(
                requester_id,
            )

            conditions.append(
                f"requester_id = ${len(values)}"
            )

        row = await self.connection.fetchrow(
            f"""
            UPDATE public.blood_requests
            SET
                status = $1,
                updated_at = NOW()
            WHERE {" AND ".join(conditions)}
            RETURNING id
            """,
            *values,
        )

        if not row:
            return None

        return await self.get_by_id(
            request_id,
        )