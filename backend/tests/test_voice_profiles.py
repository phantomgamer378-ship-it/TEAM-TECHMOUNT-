"""
Phase 16 tests — trusted-voice enrollment endpoints (conceptual flow).

The honesty guarantee under test: enrollment stores METADATA ONLY, and the
identity signal remains null until a real speaker-embedding model exists.

Run from backend/:  python -m pytest -v
"""
import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.services import ServiceContainer


@pytest.fixture(scope="module")
def demo_client():
    from app.main import app

    settings.USE_DEMO_SERVICES = True
    original_services = app.state.services
    app.state.services = ServiceContainer.create()
    try:
        with TestClient(app) as c:
            yield c
    finally:
        settings.USE_DEMO_SERVICES = False
        app.state.services = original_services


def test_enroll_creates_metadata_only_profile(demo_client):
    r = demo_client.post("/api/voice-profile/enroll",
                         json={"label": "mom", "note": "primary trusted contact"})
    assert r.status_code == 200
    body = r.json()
    assert body["label"] == "mom"
    assert body["embedding_status"] == "not_implemented_prototype"  # honest


def test_enroll_requires_label(demo_client):
    r = demo_client.post("/api/voice-profile/enroll", json={"label": "   "})
    assert r.json()["fallback_used"] is True
    assert "label is required" in r.json()["error"]


def test_profiles_are_listed(demo_client):
    demo_client.post("/api/voice-profile/enroll", json={"label": "team-lead"})
    listed = demo_client.get("/api/voice-profiles").json()
    labels = [p["label"] for p in listed["profiles"]]
    assert "mom" in labels and "team-lead" in labels
    assert all(p["embedding_status"] == "not_implemented_prototype"
               for p in listed["profiles"])


def test_identity_signal_stays_null(demo_client):
    """Even with a profile enrolled, the speaker verifier must NOT invent a
    similarity score — the identity layer is a stub until the embedding model
    exists (Phase 16 research track)."""
    demo_client.post("/api/voice-profile/enroll", json={"label": "dad"})
    out = demo_client.app.state.services.speaker_verifier.compare(audio=None)
    assert out["speaker_mismatch_risk"] is None
    assert "Phase 16" in out["note"]
