from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.ai import router as ai_router
from app.api.v1.router import router as api_router
from app.core.config import settings
from app.db.postgres import connect_db, disconnect_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await disconnect_db()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="LifeLynk AI National Digital Blood Infrastructure API",
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root() -> dict[str, str]:
    return {
        "service": "LifeLynk AI API",
        "status": "running",
        "version": "1.0.0",
    }


# Existing LifeLynk API routes.
app.include_router(
    api_router,
    prefix=settings.api_v1_prefix,
)


# Local AI routes powered by Ollama + Gemma 3.
#
# The AI router itself uses:
#     prefix="/ai"
#
# Therefore the final endpoints are:
#
# GET  /api/v1/ai/health
# POST /api/v1/ai/chat
#
app.include_router(
    ai_router,
    prefix=settings.api_v1_prefix,
)