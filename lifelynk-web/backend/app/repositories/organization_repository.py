from typing import Any
from uuid import UUID

import asyncpg


class OrganizationRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def list_organizations(
        self,
        organization_type: str | None = None,
        city_id: str | None = None,
        verified_only: bool = True,
    ) -> list[dict[str, Any]]:
        conditions = [
            "o.deleted_at IS NULL",
        ]

        values: list[Any] = []

        if verified_only:
            values.append("VERIFIED")
            conditions.append(
                f"o.verification_status = ${len(values)}"
            )

        if organization_type:
            values.append(organization_type)
            conditions.append(
                f"o.organization_type = ${len(values)}"
            )

        if city_id:
            values.append(city_id)
            conditions.append(
                f"o.city_id = ${len(values)}"
            )

        query = f"""
            SELECT
                o.id,
                o.name,
                o.organization_type,
                o.city_id,
                o.verification_status,
                o.latitude,
                o.longitude
            FROM public.organizations AS o
            WHERE {" AND ".join(conditions)}
            ORDER BY o.name ASC
        """

        rows = await self.connection.fetch(
            query,
            *values,
        )

        return [dict(row) for row in rows]

    async def get_organization(
        self,
        organization_id: str,
    ) -> dict[str, Any] | None:
        try:
            organization_uuid = UUID(organization_id.strip())
        except (ValueError, AttributeError):
            return None

        # ---------------------------------------------------------
        # 1. Base organization information
        # ---------------------------------------------------------

        organization_row = await self.connection.fetchrow(
            """
            SELECT
                o.id,
                o.city_id,
                o.organization_type,
                o.name,
                o.registration_number,
                o.phone,
                o.email,
                o.address,
                o.latitude,
                o.longitude,
                o.verification_status,

                c.name AS city,
                p.name AS province

            FROM public.organizations AS o

            LEFT JOIN public.cities AS c
                ON c.id = o.city_id

            LEFT JOIN public.provinces AS p
                ON p.id = c.province_id

            WHERE o.id = $1
              AND o.deleted_at IS NULL

            LIMIT 1
            """,
            organization_uuid,
        )

        if organization_row is None:
            return None

        organization = dict(organization_row)

        # ---------------------------------------------------------
        # 2. Real blood inventory
        #
        # blood_inventory has no deleted_at column.
        # ---------------------------------------------------------

        inventory_rows = await self.connection.fetch(
            """
            SELECT
                bi.id,
                bi.organization_id,
                bi.blood_group_id,

                bg.code AS blood_group_code,
                bg.name AS blood_group_name,

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

            INNER JOIN public.blood_groups AS bg
                ON bg.id = bi.blood_group_id

            WHERE bi.organization_id = $1
              AND bi.available_units > 0
              AND bi.expiry_date > NOW()

            ORDER BY
                bg.code ASC,
                bi.expiry_date ASC
            """,
            organization_uuid,
        )

        organization["inventory"] = [
            dict(row)
            for row in inventory_rows
        ]

        # ---------------------------------------------------------
        # 3. Real organization services/capabilities
        #
        # There is no services table in the database.
        #
        # Hospital capabilities come from hospitals.
        # Blood-bank capabilities come from blood_banks.
        # ---------------------------------------------------------

        services: list[dict[str, Any]] = []

        organization_type = organization[
            "organization_type"
        ]

        if organization_type == "HOSPITAL":
            hospital_row = await self.connection.fetchrow(
                """
                SELECT
                    h.id,
                    h.organization_id,
                    h.hospital_type,
                    h.license_number,
                    h.emergency_service,
                    h.blood_storage_available,
                    h.total_beds,
                    h.icu_available,
                    h.created_at,
                    h.updated_at

                FROM public.hospitals AS h

                WHERE h.organization_id = $1
                  AND h.deleted_at IS NULL

                LIMIT 1
                """,
                organization_uuid,
            )

            if hospital_row is not None:
                hospital = dict(hospital_row)

                # Real hospital information
                organization["hospital"] = hospital

                # Real capabilities represented as services.
                if hospital["emergency_service"]:
                    services.append(
                        {
                            "key": "emergency_service",
                            "name": "Emergency Service",
                            "available": True,
                        }
                    )

                if hospital["blood_storage_available"]:
                    services.append(
                        {
                            "key": "blood_storage",
                            "name": "Blood Storage",
                            "available": True,
                        }
                    )

                if hospital["icu_available"]:
                    services.append(
                        {
                            "key": "icu",
                            "name": "ICU",
                            "available": True,
                        }
                    )

                if hospital["total_beds"] is not None:
                    services.append(
                        {
                            "key": "total_beds",
                            "name": "Hospital Beds",
                            "available": True,
                            "value": hospital["total_beds"],
                        }
                    )

        elif organization_type == "BLOOD_BANK":
            blood_bank_row = await self.connection.fetchrow(
                """
                SELECT
                    bb.id,
                    bb.organization_id,
                    bb.license_number,
                    bb.storage_capacity,
                    bb.cold_storage_available,
                    bb.blood_processing_available,
                    bb.operating_hours,
                    bb.created_at,
                    bb.updated_at

                FROM public.blood_banks AS bb

                WHERE bb.organization_id = $1
                  AND bb.deleted_at IS NULL

                LIMIT 1
                """,
                organization_uuid,
            )

            if blood_bank_row is not None:
                blood_bank = dict(blood_bank_row)

                # Real blood-bank information
                organization["blood_bank"] = blood_bank

                if blood_bank[
                    "cold_storage_available"
                ]:
                    services.append(
                        {
                            "key": "cold_storage",
                            "name": "Cold Storage",
                            "available": True,
                        }
                    )

                if blood_bank[
                    "blood_processing_available"
                ]:
                    services.append(
                        {
                            "key": "blood_processing",
                            "name": "Blood Processing",
                            "available": True,
                        }
                    )

                if blood_bank[
                    "storage_capacity"
                ] is not None:
                    services.append(
                        {
                            "key": "storage_capacity",
                            "name": "Storage Capacity",
                            "available": True,
                            "value": blood_bank[
                                "storage_capacity"
                            ],
                        }
                    )

                if blood_bank[
                    "operating_hours"
                ]:
                    services.append(
                        {
                            "key": "operating_hours",
                            "name": "Operating Hours",
                            "available": True,
                            "value": blood_bank[
                                "operating_hours"
                            ],
                        }
                    )

        organization["services"] = services

        # ---------------------------------------------------------
        # 4. Verification
        # ---------------------------------------------------------

        organization["is_verified"] = (
            str(
                organization["verification_status"]
            ).upper()
            == "VERIFIED"
        )

        # ---------------------------------------------------------
        # 5. Rating
        #
        # There is currently no ratings/reviews table in the
        # supplied database schema, so do not fabricate ratings.
        # ---------------------------------------------------------

        organization["rating"] = 0.0
        organization["review_count"] = 0

        # ---------------------------------------------------------
        # 6. Opening status
        #
        # The database does not contain a generic is_open field.
        # Blood banks have operating_hours, but there is no reliable
        # structured schedule to calculate live opening status.
        # Keep this as true rather than falsely claiming closed/open.
        # ---------------------------------------------------------

        organization["is_open"] = True

        return organization

    async def get_members(
        self,
        organization_id: str,
    ) -> list[dict[str, Any]]:
        try:
            organization_uuid = UUID(organization_id.strip())
        except (ValueError, AttributeError):
            return []

        rows = await self.connection.fetch(
            """
            SELECT
                os.id,
                os.user_id,
                u.full_name,
                u.email,
                r.name AS role,
                os.is_primary

            FROM public.organization_staff AS os

            INNER JOIN public.users AS u
                ON u.id = os.user_id

            LEFT JOIN public.roles AS r
                ON r.id = u.role_id

            WHERE os.organization_id = $1
              AND os.deleted_at IS NULL
              AND u.deleted_at IS NULL
              AND u.is_active = true

            ORDER BY
                os.is_primary DESC,
                u.full_name ASC
            """,
            organization_uuid,
        )

        return [dict(row) for row in rows]