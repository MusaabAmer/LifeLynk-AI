from __future__ import annotations

from pydantic import BaseModel, Field


class AIMessage(BaseModel):
    role: str = Field(
        ...,
        min_length=1,
        max_length=20,
    )
    content: str = Field(
        ...,
        min_length=1,
        max_length=8000,
    )


class AIChatRequest(BaseModel):
    message: str = Field(
        ...,
        min_length=1,
        max_length=8000,
    )

    conversation: list[AIMessage] = Field(
        default_factory=list,
    )

    context: str | None = Field(
        default=None,
        max_length=30000,
    )


class AIChatResponse(BaseModel):
    response: str
    model: str