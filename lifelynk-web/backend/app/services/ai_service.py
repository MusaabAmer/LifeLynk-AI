from __future__ import annotations

from typing import Any

import httpx


class AIService:
    """
    Local LifeLynk AI service.

    The language model runs locally through Ollama.
    No paid AI API is required.

    Database access is intentionally handled outside this service.
    FastAPI should retrieve trusted LifeLynk data and pass it as context.
    """

    OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
    MODEL = "gemma3:4b"

    REQUEST_TIMEOUT = 180.0
    MAX_CONTEXT_CHARS = 30000
    MAX_MESSAGE_CHARS = 8000
    MAX_HISTORY_MESSAGES = 20

    SYSTEM_PROMPT = """
You are LifeLynk AI, the healthcare assistance assistant for LifeLynk AI.

LifeLynk AI is a digital blood infrastructure platform that connects
patients, donors, hospitals, blood banks, and healthcare authorities.

Your responsibilities:

1. LifeLynk assistance
- Help users understand and use LifeLynk features.
- Explain blood availability, blood requests, donor information,
  hospitals, blood banks, emergency SOS, locations, and related
  platform features when trusted LifeLynk data is provided.

2. Blood and healthcare education
- Explain general blood-related and blood-donation topics clearly.
- Provide general educational information about blood groups,
  donation eligibility, donation preparation, and related topics.
- Keep medical explanations understandable and concise.

3. Real-data accuracy
- When trusted LifeLynk application context is provided, use it.
- Never invent blood inventory, blood units, hospitals, blood banks,
  donors, locations, availability, blood requests, emergency SOS
  records, or other real-world LifeLynk records.
- Never create fake names, phone numbers, addresses, quantities,
  distances, availability statuses, or database records.
- If the requested real-time LifeLynk information is not provided,
  clearly say that the required information is currently unavailable.
- Do not pretend that general knowledge is real-time LifeLynk data.

4. Medical safety
- Do not diagnose diseases or medical conditions.
- Do not claim certainty about a user's medical condition.
- Do not replace a doctor, hospital, emergency service, or qualified
  healthcare professional.
- Do not provide dangerous instructions.
- For serious or potentially life-threatening situations, advise the
  user to seek immediate professional/emergency medical assistance.

5. Communication
- Respond in English, Urdu, or Roman Urdu according to the user's
  language.
- Keep responses concise, useful, respectful, and easy to understand.
- Do not unnecessarily repeat the user's question.

Always prioritize patient safety, factual accuracy, and trusted
LifeLynk application data.
"""

    def _build_messages(
        self,
        message: str,
        conversation: list[dict[str, str]] | None,
        context: str | None,
    ) -> list[dict[str, str]]:
        messages: list[dict[str, str]] = [
            {
                "role": "system",
                "content": self.SYSTEM_PROMPT.strip(),
            }
        ]

        if context:
            trusted_context = context.strip()

            if trusted_context:
                trusted_context = trusted_context[: self.MAX_CONTEXT_CHARS]

                messages.append(
                    {
                        "role": "system",
                        "content": (
                            "TRUSTED LIFELYNK APPLICATION CONTEXT\n"
                            "The following context was retrieved by the "
                            "LifeLynk backend from connected application "
                            "data. Use it as the source of truth for "
                            "LifeLynk-specific facts.\n\n"
                            f"{trusted_context}\n\n"
                            "Do not invent LifeLynk-specific facts that "
                            "are not contained in this context."
                        ),
                    }
                )

        if conversation:
            valid_messages: list[dict[str, str]] = []

            for item in conversation:
                role = str(item.get("role", "")).strip().lower()
                content = str(item.get("content", "")).strip()

                if role not in {"user", "assistant"}:
                    continue

                if not content:
                    continue

                valid_messages.append(
                    {
                        "role": role,
                        "content": content,
                    }
                )

            # Keep the most recent conversation turns. This prevents
            # excessive context usage on the local machine while still
            # preserving useful conversation history.
            valid_messages = valid_messages[-self.MAX_HISTORY_MESSAGES :]

            messages.extend(valid_messages)

        messages.append(
            {
                "role": "user",
                "content": message,
            }
        )

        return messages

    async def chat(
        self,
        message: str,
        conversation: list[dict[str, str]] | None = None,
        context: str | None = None,
    ) -> str:
        message = message.strip()

        if not message:
            raise ValueError("Message cannot be empty.")

        if len(message) > self.MAX_MESSAGE_CHARS:
            raise ValueError(
                f"Message cannot exceed {self.MAX_MESSAGE_CHARS} characters."
            )

        messages = self._build_messages(
            message=message,
            conversation=conversation,
            context=context,
        )

        payload: dict[str, Any] = {
            "model": self.MODEL,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": 0.3,
                "num_ctx": 4096,
            },
        }

        try:
            async with httpx.AsyncClient(
                timeout=self.REQUEST_TIMEOUT,
            ) as client:
                response = await client.post(
                    self.OLLAMA_URL,
                    json=payload,
                )

                response.raise_for_status()

        except httpx.ConnectError as exc:
            raise RuntimeError(
                "Local AI is not running. Please start Ollama."
            ) from exc

        except httpx.TimeoutException as exc:
            raise RuntimeError(
                "The local AI took too long to respond."
            ) from exc

        except httpx.HTTPStatusError as exc:
            try:
                error_data = exc.response.json()
            except ValueError:
                error_data = None

            if isinstance(error_data, dict):
                error_message = error_data.get("error")

                if isinstance(error_message, str) and error_message.strip():
                    raise RuntimeError(
                        f"Ollama error: {error_message.strip()}"
                    ) from exc

            raise RuntimeError(
                f"Ollama returned HTTP {exc.response.status_code}."
            ) from exc

        except httpx.HTTPError as exc:
            raise RuntimeError(
                f"Could not communicate with local AI: {exc}"
            ) from exc

        try:
            data = response.json()
        except ValueError as exc:
            raise RuntimeError(
                "Ollama returned an invalid JSON response."
            ) from exc

        if not isinstance(data, dict):
            raise RuntimeError(
                "Ollama returned an unexpected response format."
            )

        message_data = data.get("message")

        if not isinstance(message_data, dict):
            raise RuntimeError(
                "Ollama response does not contain a valid message."
            )

        answer = message_data.get("content")

        if not isinstance(answer, str) or not answer.strip():
            raise RuntimeError(
                "Ollama returned an empty AI response."
            )

        return answer.strip()


ai_service = AIService()

