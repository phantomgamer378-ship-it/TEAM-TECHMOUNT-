"""
POST /api/analyze/message (§MESSAGE SCANNER, Phase 14) — supporting feature.

Reuses the SAME scam intelligence layer as call analysis (scam rules → attack
types → bands → policy). A message has no voice/identity/context signals, so
the scam score IS the content risk — documented, not hidden.
"""
import uuid

from fastapi import APIRouter, Request

from app.models.schemas import (
    FallbackResponse,
    MessageAnalysisRequest,
    MessageAnalysisResponse,
)
from app.pipeline import analyze_message

router = APIRouter(prefix="/v1", tags=["messages"])


@router.post("/analyze/message",
             response_model=MessageAnalysisResponse | FallbackResponse)
def analyze_message_endpoint(request: Request, body: MessageAnalysisRequest):
    if not body.text or not body.text.strip():
        return FallbackResponse(error="text is required (use /api/analyze/url for links)")

    session_id = (body.session_id or "").strip() or uuid.uuid4().hex[:12]
    return analyze_message(
        request.app.state.services, body.text.strip(), session_id
    )
