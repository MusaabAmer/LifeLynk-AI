from sqlalchemy import create_engine
from app.database.config import settings

print("DATABASE_URL:")
print(settings.DATABASE_URL)

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
)

try:
    with engine.connect() as conn:
        print("✅ Connected successfully!")
except Exception as e:
    print("❌ Connection failed:")
    print(type(e).__name__)
    print(e)