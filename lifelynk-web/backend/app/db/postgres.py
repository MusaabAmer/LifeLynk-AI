from collections.abc import AsyncGenerator

import asyncpg

from app.core.config import settings


_pool: asyncpg.Pool | None = None


async def connect_db() -> None:
    global _pool

    if _pool is None:
        _pool = await asyncpg.create_pool(
            dsn=settings.database_url,
            min_size=1,
            max_size=10,
            command_timeout=30,
        )


async def disconnect_db() -> None:
    global _pool

    if _pool is not None:
        await _pool.close()
        _pool = None


async def get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("Database pool has not been initialized.")

    return _pool


async def get_connection() -> AsyncGenerator[asyncpg.Connection, None]:
    pool = await get_pool()

    async with pool.acquire() as connection:
        yield connection
