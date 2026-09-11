"""
POST /api/analyze/url (§URL CHECKER, Phase 15) — supporting feature.

Structural heuristics only (services/url_checker.py): no live fetching, no
threat-intelligence feeds, no ML. Never claim enterprise-grade phishing
detection (master prompt honesty rule).
"""
import uuid

from fastapi import APIRouter, Request

from app.models.schemas import (
    FallbackResponse,
    URLAnalysisRequest,
    URLAnalysisResponse,
)
from app.pipeline import analyze_url

router = APIRouter(prefix="/api", tags=["urls"])


@router.post("/analyze/url", response_model=URLAnalysisResponse | FallbackResponse)
def analyze_url_endpoint(request: Request, body: URLAnalysisRequest):
    if not body.url or not body.url.strip():
        return FallbackResponse(error="url is required")

    session_id = (body.session_id or "").strip() or uuid.uuid4().hex[:12]
    return analyze_url(request.app.state.services, body.url.strip(), session_id)
