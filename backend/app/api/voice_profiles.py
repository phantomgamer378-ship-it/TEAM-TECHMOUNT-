"""
Trusted Voice Memory endpoints (§TRUSTED VOICE MEMORY, Phase 16 — conceptual flow).

POST /api/voice-profile/enroll — enroll a trusted person (label + metadata)
GET  /api/voice-profiles      — list enrolled profiles

PROTOTYPE honesty (§TRUSTED VOICE MEMORY): enrollment stores LABEL + METADATA
only. The real flow — voice sample → speaker embedding → secure reference →
similarity comparison → identity-consistency score — arrives with the research
track (training/README.md). Until a real embedding model exists, the identity
signal stays honestly NULL (DemoSpeakerVerifier) and voice identity alone
never proves identity. Raw audio is never accepted or stored here (privacy).
"""
from typing import Union

from fastapi import APIRouter

from app.database import database as db
from app.models.schemas import (
    FallbackResponse,
    VoiceProfileEnrollRequest,
    VoiceProfileResponse,
)

router = APIRouter(prefix="/api", tags=["voice-profiles"])


@router.post("/voice-profile/enroll",
             response_model=VoiceProfileResponse | FallbackResponse)
def enroll(body: VoiceProfileEnrollRequest):
    if not body.label or not body.label.strip():
        return FallbackResponse(error="label is required (who is this trusted voice?)")
    return db.save_voice_profile(
        label=body.label.strip(), user_id=body.user_id, note=body.note
    )


@router.get("/voice-profiles")
def list_profiles():
    profiles = db.list_voice_profiles()
    return {"profiles": profiles, "count": len(profiles)}
