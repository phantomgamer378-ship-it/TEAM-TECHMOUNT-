"""
Database Operations Layer
Migrated to SQLAlchemy ORM (Phase 12: PostgreSQL persistence).
"""
import json
import logging
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.database.session import SessionLocal, init_db as init_orm_db, engine
from app.database.models import (
    CallSession, AnalysisResult, Threat, LivenessSession, VoiceProfile
)

log = logging.getLogger(__name__)

THREAT_LEVELS = ("MEDIUM", "HIGH", "CRITICAL")

def init_db() -> None:
    init_orm_db()

def check_health() -> str:
    try:
        with engine.connect() as conn:
            # simple ping
            conn.execute(text("SELECT 1"))
        return "connected"
    except Exception as exc:
        log.warning("Database health check failed: %s", exc)
        return "unavailable"

def _ensure_session(db: Session, session_id: str, source: str = "upload") -> None:
    sess = db.query(CallSession).filter_by(id=session_id).first()
    if not sess:
        sess = CallSession(id=session_id, source=source)
        db.add(sess)
        db.commit()

def create_session(session_id: str, source: str = "upload") -> str:
    db = SessionLocal()
    try:
        sess = db.query(CallSession).filter_by(id=session_id).first()
        if not sess:
            sess = CallSession(id=session_id, source=source)
            db.add(sess)
            db.commit()
            db.refresh(sess)
        return sess.created_at.isoformat()
    finally:
        db.close()

def save_analysis_result(session_id: str, response: Dict[str, Any]) -> None:
    flat = json.dumps(response, ensure_ascii=False)
    if '"waveform"' in flat:
        raise ValueError("PRIVACY violation: refusing to persist a response containing a waveform")

    risk = response.get("risk") or {}
    voice = response.get("voice_trust") or {}
    scam = response.get("scam_analysis") or {}
    audio = response.get("audio") or {}
    asr = response.get("asr") or {}
    language = asr.get("language") or audio.get("language")

    db = SessionLocal()
    try:
        _ensure_session(db, session_id)
        
        ar = AnalysisResult(
            session_id=session_id,
            duration_s=audio.get("duration"),
            language=language,
            spoof_risk=voice.get("spoof_risk"),
            scam_risk=scam.get("risk"),
            risk_score=risk.get("score"),
            risk_level=risk.get("level"),
            attack_types=response.get("attack_types", []),
            indicators=scam.get("indicators") or [],
            fallback_used=bool(response.get("fallback_used")),
            result_json=response
        )
        db.add(ar)
        db.commit()

        if risk.get("level") in THREAT_LEVELS:
            t = Threat(
                session_id=session_id,
                risk_level=risk["level"],
                attack_types=response.get("attack_types", []),
                action=None
            )
            db.add(t)
            db.commit()
    finally:
        db.close()

def save_threat_event(session_id: str, risk_level: str, attack_types: List[str], action: Optional[str]) -> None:
    db = SessionLocal()
    try:
        _ensure_session(db, session_id)
        t = Threat(session_id=session_id, risk_level=risk_level, attack_types=attack_types, action=action)
        db.add(t)
        db.commit()
    finally:
        db.close()

def save_liveness(session_id: str, challenge: str) -> None:
    db = SessionLocal()
    try:
        _ensure_session(db, session_id)
        ls = LivenessSession(session_id=session_id, challenge=challenge, status='PENDING')
        db.add(ls)
        db.commit()
    finally:
        db.close()

def update_liveness_status(session_id: str, status: str) -> None:
    db = SessionLocal()
    try:
        ls = db.query(LivenessSession).filter_by(session_id=session_id, status='PENDING').order_by(LivenessSession.id.desc()).first()
        if not ls:
            log.warning("No PENDING liveness challenge for session=%s", session_id)
            return
        ls.status = status
        ls.verified_at = datetime.now(timezone.utc)
        db.commit()
    finally:
        db.close()

def save_voice_profile(label: str, user_id: Optional[int] = None, note: Optional[str] = None) -> Dict[str, Any]:
    db = SessionLocal()
    try:
        vp = VoiceProfile(label=label, user_id=user_id, reference_meta={"note": note} if note else None)
        db.add(vp)
        db.commit()
        db.refresh(vp)
        return {
            "id": vp.id, "label": vp.label, "note": note,
            "created_at": vp.created_at.isoformat(), "embedding_status": "not_implemented_prototype"
        }
    finally:
        db.close()

def list_voice_profiles() -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        profiles = db.query(VoiceProfile).order_by(VoiceProfile.id).all()
        out = []
        for vp in profiles:
            meta = vp.reference_meta or {}
            out.append({
                "id": vp.id, "label": vp.label, "note": meta.get("note"),
                "created_at": vp.created_at.isoformat(),
                "embedding_status": "not_implemented_prototype"
            })
        return out
    finally:
        db.close()

def get_history(limit: int = 50) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        results = db.query(AnalysisResult).order_by(AnalysisResult.id.desc()).limit(limit).all()
        out = []
        for ar in results:
            out.append({
                "id": ar.id,
                "session_id": ar.session_id,
                "created_at": ar.created_at.isoformat(),
                "duration_s": ar.duration_s,
                "language": ar.language,
                "spoof_risk": ar.spoof_risk,
                "scam_risk": ar.scam_risk,
                "risk_score": ar.risk_score,
                "risk_level": ar.risk_level,
                "attack_types": ar.attack_types,
                "indicators": ar.indicators,
                "fallback_used": 1 if ar.fallback_used else 0,
                "result": ar.result_json
            })
        return out
    finally:
        db.close()

def get_session(session_id: str) -> Optional[Dict[str, Any]]:
    db = SessionLocal()
    try:
        sess = db.query(CallSession).filter_by(id=session_id).first()
        if not sess:
            return None
        
        results = db.query(AnalysisResult).filter_by(session_id=session_id).order_by(AnalysisResult.id.asc()).all()
        ar_list = []
        for ar in results:
            ar_list.append({
                "id": ar.id,
                "session_id": ar.session_id,
                "created_at": ar.created_at.isoformat(),
                "duration_s": ar.duration_s,
                "language": ar.language,
                "spoof_risk": ar.spoof_risk,
                "scam_risk": ar.scam_risk,
                "risk_score": ar.risk_score,
                "risk_level": ar.risk_level,
                "attack_types": ar.attack_types,
                "indicators": ar.indicators,
                "fallback_used": 1 if ar.fallback_used else 0,
                "result": ar.result_json
            })
        
        return {
            "session": {
                "id": sess.id,
                "source": sess.source,
                "created_at": sess.created_at.isoformat()
            },
            "analysis_results": ar_list
        }
    finally:
        db.close()
