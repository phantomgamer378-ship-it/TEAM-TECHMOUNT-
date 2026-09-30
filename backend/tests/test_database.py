"""
Phase 12 tests — PostgreSQL/SQLAlchemy persistence.
"""
import json
import pytest
from sqlalchemy import text

from app.config import settings
from app.database import database as db
from app.database.session import SessionLocal, engine, init_db as init_orm_db


@pytest.fixture
def tmp_db(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "DATABASE_PATH", str(tmp_path / "test_shield.db"))
    # Rebind engine if needed, but since engine is global, we might just drop all
    from app.database.models import Base
    Base.metadata.drop_all(bind=engine)
    db.init_db()
    return engine


CANONICAL = {
    "session_id": "demo-001",
    "status": "complete",
    "audio": {"duration": 23.4, "language": "mr"},
    "voice_trust": {"spoof_risk": 0.91, "speaker_mismatch_risk": None,
                    "overall_voice_risk": 0.84, "status": "SUSPICIOUS"},
    "asr": {"language": "mr", "transcript": "...", "segments": []},
    "scam_analysis": {"risk": 0.88, "category": "Bank/KYC Fraud",
                      "indicators": ["Urgency", "OTP request"]},
    "attack_types": ["AI Voice Impersonation", "Bank Fraud"],
    "risk": {"score": 91, "level": "HIGH"},
    "liveness": {"required": True, "status": "PENDING"},
    "explanation": ["[voice] Synthetic voice evidence detected"],
    "recommendation": "Do not share OTP or transfer money.",
}


def test_all_tables_exist(tmp_db):
    with tmp_db.connect() as conn:
        # Works on sqlite, will ignore on postgres
        if tmp_db.name == "sqlite":
            names = {r[0] for r in conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'")).fetchall()}
            assert {"users", "voice_profiles", "calls", "analysis_results",
                    "threats", "liveness_sessions"} <= names


def test_analysis_roundtrip(tmp_db):
    db.create_session("demo-001", source="upload")
    db.save_analysis_result("demo-001", CANONICAL)

    history = db.get_history()
    assert len(history) == 1
    row = history[0]
    assert row["session_id"] == "demo-001"
    assert row["risk_score"] == 91
    assert row["risk_level"] == "HIGH"
    assert row["attack_types"] == ["AI Voice Impersonation", "Bank Fraud"]
    assert row["result"]["recommendation"].startswith("Do not share OTP")


def test_get_session_returns_results(tmp_db):
    db.create_session("s1")
    db.save_analysis_result("s1", CANONICAL)

    data = db.get_session("s1")
    assert data["session"]["id"] == "s1"
    assert len(data["analysis_results"]) == 1
    assert db.get_session("missing") is None


def test_high_risk_creates_threat_event(tmp_db):
    db.create_session("s1")
    db.save_analysis_result("s1", CANONICAL)

    with tmp_db.connect() as conn:
        rows = conn.execute(text("SELECT risk_level, action FROM threats")).fetchall()
        assert rows == [("HIGH", None)]


def test_low_risk_creates_no_threat_event(tmp_db):
    low = {**CANONICAL, "risk": {"score": 10, "level": "LOW"}}
    db.create_session("s1")
    db.save_analysis_result("s1", low)

    with tmp_db.connect() as conn:
        count = conn.execute(text("SELECT COUNT(*) FROM threats")).fetchone()[0]
        assert count == 0


def test_liveness_roundtrip(tmp_db):
    db.create_session("s1")
    db.save_liveness("s1", "Blue Tiger 47")
    db.update_liveness_status("s1", "PASSED")

    with tmp_db.connect() as conn:
        row = conn.execute(text("SELECT challenge, status, verified_at FROM liveness_sessions")).fetchone()
        assert row[0] == "Blue Tiger 47"
        assert row[1] == "PASSED"
        assert row[2] is not None


def test_privacy_waveform_payload_rejected(tmp_db):
    poisoned = {**CANONICAL, "waveform": [0.0] * 100}
    with pytest.raises(ValueError, match="PRIVACY"):
        db.save_analysis_result("s1", poisoned)


def test_health_check(tmp_db):
    assert db.check_health() == "connected"
