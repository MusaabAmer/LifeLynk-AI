from typing import Any

import asyncpg


class SearchRepository:
    def __init__(self, connection: asyncpg.Connection) -> None:
        self.connection = connection

    async def search_organizations(
        self,
        blood_group: str | None = None,
        province: str | None = None,
        city: str | None = None,
    ) -> list[dict[str, Any]]:
        conditions = [
            "o.deleted_at IS NULL",
            "o.verification_status = 'VERIFIED'",
        ]

        values: list[Any] = []
        parameter_index = 1

        # ---------------------------------------------------------
        # BLOOD GROUP FILTER
        # ---------------------------------------------------------
        if blood_group:
            conditions.append(
                f"UPPER(bg.code) = UPPER(${parameter_index})"
            )
            values.append(blood_group.strip())
            parameter_index += 1

        # ---------------------------------------------------------
        # PROVINCE FILTER
        # ---------------------------------------------------------
        if province:
            conditions.append(
                f"LOWER(p.name) = LOWER(${parameter_index})"
            )
            values.append(province.strip())
            parameter_index += 1

        # ---------------------------------------------------------
        # CITY FILTER
        # ---------------------------------------------------------
        if city:
            conditions.append(
                f"LOWER(c.name) = LOWER(${parameter_index})"
            )
            values.append(city.strip())
            parameter_index += 1

        where_clause = " AND ".join(conditions)

        query = f"""
            SELECT
                o.id AS organization_id,
                o.name AS organization_name,
                o.organization_type,
                o.phone,
                o.email,
                o.address,
                o.latitude,
                o.longitude,
                o.verification_status,

                c.name AS city,
                p.name AS province,

                h.license_number,

                bg.code AS blood_group,

                COALESCE(
                    SUM(
                        CASE
                            WHEN bi.available_units > 0
                            THEN bi.available_units
                            ELSE 0
                        END
                    ),
                    0
                )::integer AS available_units

            FROM public.organizations AS o

            INNER JOIN public.cities AS c
                ON c.id = o.city_id

            INNER JOIN public.provinces AS p
                ON p.id = c.province_id

            LEFT JOIN public.hospitals AS h
                ON h.organization_id = o.id
                AND h.deleted_at IS NULL

            LEFT JOIN public.blood_inventory AS bi
                ON bi.organization_id = o.id
                AND bi.status <> 'DELETED'

            LEFT JOIN public.blood_groups AS bg
                ON bg.id = bi.blood_group_id

            WHERE {where_clause}

            GROUP BY
                o.id,
                o.name,
                o.organization_type,
                o.phone,
                o.email,
                o.address,
                o.latitude,
                o.longitude,
                o.verification_status,
                c.name,
                p.name,
                h.license_number,
                bg.code

            ORDER BY
                available_units DESC,
                o.name ASC
        """

        rows = await self.connection.fetch(
            query,
            *values,
        )

        return [dict(row) for row in rows]