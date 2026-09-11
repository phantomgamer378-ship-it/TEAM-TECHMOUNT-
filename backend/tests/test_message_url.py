"""
Phase 14/15 tests — message + URL scanner endpoints (§10 supporting features).
Reuse the intelligence layer: scam rules / URL heuristics → bands → policy.

Run from backend/:  python -m pytest -v
"""
import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.models.schemas import MessageAnalysisResponse, URLAnalysisResponse
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


def test_scam_message_scores_high(demo_client):
    r = demo_client.post("/api/analyze/message",
                         json={"text": "Your bank account will be blocked today. Send the OTP immediately."})
    assert r.status_code == 200
    body = MessageAnalysisResponse(**r.json())  # contract validation
    assert body.risk.level in ("HIGH", "CRITICAL")
    assert body.policy_action in ("VERIFY_CALLER", "WARN")
    assert "OTP request" in body.scam_analysis.indicators
    assert "Bank Fraud" in body.attack_types and "OTP Theft" in body.attack_types
    assert any(e.startswith("[scam_rule]") for e in body.explanation)
    assert any(e.startswith("[fused]") for e in body.explanation)


def test_normal_message_scores_low(demo_client):
    r = demo_client.post("/api/analyze/message",
                         json={"text": "नमस्ते! कल की मीटिंग 11 बजे है। रिपोर्ट भेज देना।"})
    body = MessageAnalysisResponse(**r.json())
    assert body.risk.level == "LOW"
    assert body.policy_action == "CONTINUE"
    assert body.attack_types == []


def test_empty_message_returns_fallback(demo_client):
    r = demo_client.post("/api/analyze/message", json={"text": "   "})
    body = r.json()
    assert body["status"] == "partial" and body["fallback_used"] is True


def test_phishing_url_scores_high(demo_client):
    r = demo_client.post("/api/analyze/url",
                         json={"url": "http://192.168.4.22/sbi/kyc/verify?otp=1"})
    body = URLAnalysisResponse(**r.json())
    assert body.risk.level in ("HIGH", "CRITICAL")
    assert body.policy_action in ("VERIFY_CALLER", "WARN")
    assert any("raw IP" in e for e in body.explanation)
    assert body.url_analysis["model"] == "heuristic_rules"


def test_benign_url_scores_low(demo_client):
    r = demo_client.post("/api/analyze/url", json={"url": "https://www.google.com/search?q=weather"})
    body = URLAnalysisResponse(**r.json())
    assert body.risk.level == "LOW"
    assert body.policy_action == "CONTINUE"


def test_empty_url_returns_fallback(demo_client):
    r = demo_client.post("/api/analyze/url", json={"url": "  "})
    assert r.json()["fallback_used"] is True
