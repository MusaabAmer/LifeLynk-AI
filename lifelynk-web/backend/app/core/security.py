from typing import Any

import jwt
from fastapi import HTTPException, status
from fastapi.security import HTTPBearer

from app.core.config import settings


bearer_scheme = HTTPBearer(auto_error=False)


class AuthenticationError(HTTPException):
    def __init__(
        self,
        detail: str = "Invalid or expired authentication token.",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


def decode_supabase_token(token: str) -> dict[str, Any]:
    """
    Verify a Supabase Auth JWT using the project's JWKS endpoint.

    Supabase currently signs this project's user access tokens with
    ES256 asymmetric signing keys. The corresponding public key is
    retrieved from the Supabase JWKS endpoint.

    The JWT header's `kid` is used by PyJWT's PyJWKClient to select
    the correct public verification key.
    """

    if not token:
        raise AuthenticationError(
            "Authentication credentials are required."
        )

    try:
        # ---------------------------------------------------------
        # SUPABASE JWKS
        # ---------------------------------------------------------
        jwks_client = jwt.PyJWKClient(
            settings.supabase_jwks_url,
            cache_jwk_set=True,
            lifespan=600,
        )

        # ---------------------------------------------------------
        # GET THE PUBLIC KEY MATCHING THE TOKEN'S `kid`
        # ---------------------------------------------------------
        signing_key = jwks_client.get_signing_key_from_jwt(token)

        # ---------------------------------------------------------
        # VERIFY TOKEN
        # ---------------------------------------------------------
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            issuer=settings.supabase_jwt_issuer,
            audience="authenticated",
            options={
                "require": [
                    "exp",
                    "sub",
                    "iss",
                    "aud",
                ],
            },
        )

    except jwt.ExpiredSignatureError as exc:
        raise AuthenticationError(
            "Authentication token has expired."
        ) from exc

    except jwt.InvalidIssuerError as exc:
        raise AuthenticationError(
            "Invalid authentication issuer."
        ) from exc

    except jwt.InvalidAudienceError as exc:
        raise AuthenticationError(
            "Invalid authentication audience."
        ) from exc

    except jwt.InvalidSignatureError as exc:
        raise AuthenticationError(
            "Invalid authentication token signature."
        ) from exc

    except jwt.PyJWKClientError as exc:
        raise AuthenticationError(
            "Unable to verify authentication signing key."
        ) from exc

    except jwt.InvalidTokenError as exc:
        raise AuthenticationError(
            "Invalid authentication token."
        ) from exc

    user_id = payload.get("sub")

    if not user_id:
        raise AuthenticationError(
            "Authentication token does not contain a user ID."
        )

    return payload