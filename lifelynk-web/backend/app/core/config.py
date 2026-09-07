from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    app_name: str = "LifeLynk AI API"
    api_v1_prefix: str = "/api/v1"

    database_url: str

    supabase_url: str

    supabase_jwt_issuer: str

    supabase_jwt_secret: str = ""

    supabase_jwks_url: str

    cors_origins: str = (
        "http://localhost:3000,"
        "http://localhost:5000,"
        "http://localhost:8080,"
        "http://127.0.0.1:5000,"
        "http://127.0.0.1:8080"
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def cors_origin_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_origins.split(",")
            if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()