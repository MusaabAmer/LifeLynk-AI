
from __future__ import annotations

import re
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from app.core.dependencies import get_current_user
from app.db.postgres import get_connection
from app.repositories.search_repository import SearchRepository
from app.schemas.ai import AIChatRequest, AIChatResponse
from app.services.ai_service import ai_service
from app.services.authorization_service import (
    CurrentUser,
    require_active_user,
)


router = APIRouter(
    prefix="/ai",
    tags=["AI"],
)


# ---------------------------------------------------------------------------
# LifeLynk AI entity extraction
# ---------------------------------------------------------------------------

_BLOOD_GROUP_ALIASES: dict[str, str] = {
    "a positive": "A+",
    "a+": "A+",
    "a pos": "A+",
    "a negative": "A-",
    "a-": "A-",
    "a neg": "A-",
    "b positive": "B+",
    "b+": "B+",
    "b pos": "B+",
    "b negative": "B-",
    "b-": "B-",
    "b neg": "B-",
    "ab positive": "AB+",
    "ab+": "AB+",
    "ab pos": "AB+",
    "ab negative": "AB-",
    "ab-": "AB-",
    "ab neg": "AB-",
    "o positive": "O+",
    "o+": "O+",
    "o pos": "O+",
    "o negative": "O-",
    "o-": "O-",
    "o neg": "O-",
}


def _extract_blood_group(message: str) -> str | None:
    """
    Extract a blood-group code from normal user language.

    Examples:
        "O-negative in Lahore" -> O-
        "Do you have A positive?" -> A+
        "need AB-" -> AB-
    """
    normalized = " ".join(message.lower().split())

    # Prefer longer textual aliases first.
    aliases = sorted(
        _BLOOD_GROUP_ALIASES.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    )

    for alias, blood_group in aliases:
        pattern = rf"(?<![a-z0-9]){re.escape(alias)}(?![a-z0-9])"

        if re.search(pattern, normalized):
            return blood_group

    return None


async def _extract_city(
    connection: Any,
    message: str,
) -> str | None:
    """
    Resolve a city mentioned in the user's message against the real
    LifeLynk cities table.

    The model is never allowed to invent a city name.

    A longest-name-first match is used so names such as "Lahore" and
    multi-word city names can be resolved safely.
    """
    rows = await connection.fetch(
        """
        SELECT name
        FROM public.cities
        ORDER BY LENGTH(name) DESC, name ASC
        """
    )

    normalized_message = message.casefold()

    for row in rows:
        city_name = str(row["name"]).strip()

        if not city_name:
            continue

        if city_name.casefold() in normalized_message:
            return city_name

    return None


# ---------------------------------------------------------------------------
# Trusted LifeLynk database context
# ---------------------------------------------------------------------------

async def _build_trusted_context(
    connection: Any,
    message: str,
) -> str | None:
    """
    Retrieve a small, sanitized set of real LifeLynk records relevant to
    the user's question.

    Important:
        - Client-supplied request.context is never trusted.
        - Gemma does not query PostgreSQL directly.
        - Only backend-retrieved records are sent as LifeLynk context.
        - Sensitive patient/donor information is intentionally excluded.
    """
    blood_group = _extract_blood_group(message)
    city = await _extract_city(connection, message)

    # At the moment, organization search is the safest real-data source
    # for blood availability questions. If the message does not contain
    # a recognizable blood group or city, avoid dumping the entire
    # database into the model.
    if not blood_group and not city:
        return None

    repository = SearchRepository(connection)

    organizations = await repository.search_organizations(
        blood_group=blood_group,
        city=city,
    )

    if not organizations:
        filters: list[str] = []

        if blood_group:
            filters.append(f"blood group {blood_group}")

        if city:
            filters.append(f"city {city}")

        requested_data = ", ".join(filters)

        return (
            "No verified LifeLynk organization records currently match "
            f"the requested {requested_data}."
        )

    # Keep the context intentionally small. Gemma should receive only
    # the information needed to answer availability/location questions.
    organizations = organizations[:50]

    context_lines: list[str] = [
        "REAL LIFELYNK BLOOD AVAILABILITY DATA",
        f"Matched blood group: {blood_group or 'not specified'}",
        f"Matched city: {city or 'not specified'}",
        "",
    ]

    for index, organization in enumerate(
        organizations,
        start=1,
    ):
        organization_name = str(
            organization.get("organization_name") or "Unknown organization"
        )

        organization_type = str(
            organization.get("organization_type") or "UNKNOWN"
        )

        organization_city = str(
            organization.get("city") or "Unknown city"
        )

        province = str(
            organization.get("province") or "Unknown province"
        )

        blood_group_code = organization.get("blood_group")

        available_units = organization.get("available_units", 0)

        if blood_group_code:
            blood_description = str(blood_group_code)
        else:
            blood_description = "Blood group not specified"

        try:
            available_units_value = int(available_units or 0)
        except (TypeError, ValueError):
            available_units_value = 0

        context_lines.extend(
            [
                f"{index}. Organization: {organization_name}",
                f"   Type: {organization_type}",
                f"   City: {organization_city}",
                f"   Province: {province}",
                f"   Blood group: {blood_description}",
                f"   Available units: {available_units_value}",
                "",
            ]
        )

    context_lines.append(
        "These records are retrieved by the LifeLynk backend from "
        "verified database records. Do not invent additional records "
        "or availability information."
    )

    return "\n".join(context_lines)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@router.get("/health")
async def ai_health() -> dict[str, str]:
    """
    Public health endpoint for the local AI service.

    This endpoint does not expose user or database information.
    """
    return {
        "status": "ok",
        "model": ai_service.MODEL,
        "provider": "ollama",
        "type": "local",
    }


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------

@router.post(
    "/chat",
    response_model=AIChatResponse,
)
async def chat(
    request: AIChatRequest,
    current_user: CurrentUser = Depends(get_current_user),
    connection=Depends(get_connection),
) -> AIChatResponse:
    """
    Send an authenticated user's message to LifeLynk AI.

    Flow:

        Supabase JWT
            ↓
        Current LifeLynk user
            ↓
        Real PostgreSQL data
            ↓
        Sanitized trusted context
            ↓
        Local Gemma 3 4B / Ollama
            ↓
        AI response
            ↓
        ai_chat_history

    Client-supplied context is deliberately ignored because the client
    cannot be trusted to provide authoritative LifeLynk database data.
    """
    require_active_user(current_user)

    try:
        conversation = [
            {
                "role": item.role,
                "content": item.content,
            }
            for item in request.conversation
        ]

        trusted_context = await _build_trusted_context(
            connection=connection,
            message=request.message,
        )

        response = await ai_service.chat(
            message=request.message,
            conversation=conversation,
            context=trusted_context,
        )

        history_id = uuid4()

        await connection.execute(
            """
            INSERT INTO public.ai_chat_history (
                id,
                user_id,
                question,
                response,
                model_used
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $5
            )
            """,
            history_id,
            current_user.id,
            request.message.strip(),
            response,
            ai_service.MODEL,
        )

        return AIChatResponse(
            response=response,
            model=ai_service.MODEL,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc

