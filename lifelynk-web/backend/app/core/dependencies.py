from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials

from app.core.security import bearer_scheme, decode_supabase_token
from app.db.postgres import get_connection
from app.repositories.user_repository import UserRepository
from app.services.authorization_service import (
    CurrentUser,
    build_current_user,
)


async def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
    connection=Depends(get_connection),
) -> CurrentUser:
    if credentials is None:
        from app.core.security import AuthenticationError

        raise AuthenticationError("Authentication credentials are required.")

    payload = decode_supabase_token(credentials.credentials)

    user_id = str(payload["sub"])

    repository = UserRepository(connection)

    user = await repository.get_user(user_id)

    if user is None:
        from fastapi import HTTPException, status

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authenticated user does not exist in LifeLynk.",
        )

    organization = await repository.get_primary_organization(user_id)

    return build_current_user(user, organization)
