import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.config import settings
from app.database.models import Base

log = logging.getLogger(__name__)

# If DATABASE_URL is provided, use Postgres. Otherwise, fallback to SQLite for tests/local.
DATABASE_URL = getattr(settings, "DATABASE_URL", None)

if DATABASE_URL:
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
else:
    # Fallback to local sqlite to ensure tests don't break
    engine = create_engine(
        f"sqlite:///{settings.DATABASE_PATH}",
        connect_args={"check_same_thread": False}
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)
    log.info(f"SQLAlchemy ORM initialized on {engine.url}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
