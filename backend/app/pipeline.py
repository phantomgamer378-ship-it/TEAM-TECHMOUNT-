"""
Analysis orchestration (§API responsibilities: "analysis orchestration") —
the ONE place that wires the full prototype pipeline. THREE surfaces, one
logic (stream_analysis event generator):

  * scripts/demo_pipeline.py   → terminal card (stages forwarded to a printer)
  * POST /api/analyze/audio    → HTTP (events consumed, final response kept)
  * WS  /ws/session/{id}       → streams risk_update events as computed (§12)

Routes never reimplement pipeline logic — they prepare input (upload → temp
file), consume the stream, persist the response, and enforce the contract.

Stream events:
  ("stage", n, name, detail)                  — human-readable progress
  ("risk_update", point)                      — one Risk(t) point per chunk
  ("final", response_dict, meta_dict)         — canonical response (or fallback)

Stages: preprocess → voice trust → ASR → scam intent → attack types →
fusion → Risk(t) timeline → policy → adaptive liveness.

Failure discipline (§20): the individual services never raise; this generator
also never raises. A hard failure (e.g. unreadable audio) yields the bare
fallback shape as the final event; degraded signals produce
status="partial" + fallback_used on the canonical response.
"""
import logging
from typing import Callable, Dict, Generator, List, Optional, Tuple

from app.risk.policy_engine import decide, liveness_decision
from app.services import ServiceContainer
from app.services.attack_classifier import attack_types_from_indicators

log = logging.getLogger(__name__)

SR = 16000
VOICE_WINDOW_S = 4  # AASIST's native window — 1 s windows are out-of-distribution

RECOMMENDATIONS: Dict[str, str] = {
    "LOW": "No suspicious indicators detected. Stay alert for unexpected requests for money, codes or credentials.",
    "MEDIUM": "Stay cautious: do not share OTP/PIN or financial details; verify unexpected requests through official channels.",
    "HIGH": "Do not share OTP. Do not transfer money. Verify the caller through official channels before any action.",
    "CRITICAL": "Strong warning: do not share OTP, do not transfer money. End the interaction and verify via official channels.",
}


def stream_analysis(
    services: ServiceContainer,
    audio_path: str,
    session_id: str,
    lang: str = "hi",
    source_hint: str = "",
) -> Generator[Tuple, None, None]:
    """Run the full pipeline, yielding events as they happen (see module
    docstring). Never raises."""
    # 1. Preprocess -----------------------------------------------------------
    pre = services.audio_processor.preprocess(audio_path)
    if not pre.get("ok"):
        yield ("final", {
            "status": "partial",
            "error": pre.get("error", "audio rejected"),
            "fallback_used": True,
        }, {})
        return
    yield ("stage", 1, "Preprocess",
           f"{pre['duration_s']} s @ {pre['source_sr']} Hz ch{pre['channels_in']} → 16 kHz mono")
    waveform = pre["waveform"]

    # 2. Voice trust ----------------------------------------------------------
    voice = services.voice_detector.predict(waveform, source_hint=source_hint)
    voice_ok = "spoof_risk" in voice
    voice_tag = "REAL — AASIST-L" if str(voice.get("model", "")).startswith("aasist") else "DEMO MODE"
    yield ("stage", 2, "Voice trust",
           f"spoof {voice.get('spoof_risk', 0):.4f} {voice.get('status', '')}  [{voice_tag}]")

    # 3. ASR ------------------------------------------------------------------
    asr = services.asr_service.transcribe(waveform, lang=lang, source_hint=source_hint)
    asr_ok = isinstance(asr.get("transcript"), str)
    asr_tag = "REAL" if str(asr.get("model", "")) not in ("", "mock_fallback") else "DEMO MODE"
    yield ("stage", 3, f"ASR ({asr.get('language', lang)})",
           f"{len(asr.get('transcript') or '')} chars  [{asr_tag}]")

    # 4. Scam intent ----------------------------------------------------------
    scam = services.scam_detector.analyze(asr.get("transcript") or "", source_hint=source_hint)
    scam_ok = "risk" in scam
    scam_tag = ("REAL — rule engine"
                if scam.get("model") == "rule_engine" and scam.get("note") is None
                else "DEMO MODE")
    yield ("stage", 4, "Scam intent",
           f"score {scam.get('risk', 0):.2f} — {scam.get('category', '?')}  [{scam_tag}]")

    # 5. Attack types ---------------------------------------------------------
    attack_types = attack_types_from_indicators(
        scam.get("indicators") or [],
        voice_spoof_risk=voice.get("spoof_risk") if voice_ok else None,
    )
    yield ("stage", 5, "Attack types", f"{len(attack_types)} label(s)  [pure lookup]")

    # 6. Fusion (final score over the full clip) ------------------------------
    context_risk = 0.0  # honest placeholder: no channel/reputation signals yet
    risk = services.risk_engine.fuse(
        voice_risk=voice.get("spoof_risk") if voice_ok else None,
        scam_risk=scam.get("risk") if scam_ok else None,
        context_risk=context_risk,
    )
    yield ("stage", 6, "Risk fusion", f"final {risk['risk_score']}/100 {risk['risk_level']}")

    # 7. Risk(t) timeline — one point per chunk, streamed as computed ---------
    n_chunks = len(services.audio_processor.chunk(waveform, chunk_seconds=1.0))
    segments = asr.get("segments") or [] if asr_ok else []
    state: Dict = {}
    timeline: List[Dict] = []
    for i in range(n_chunks):
        window = waveform[i * SR : (i + VOICE_WINDOW_S) * SR]
        voice_raw = (
            services.voice_detector.predict(window, source_hint=source_hint).get("spoof_risk")
            if window.size else None
        )
        overlapping = " ".join(
            s.get("text", "") for s in segments
            if s.get("start", 0) < i + 1 and s.get("end", 1e9) > i
        ) if asr_ok else ""
        scam_raw = services.scam_detector.analyze(overlapping)["risk"] if overlapping.strip() else None

        point = services.risk_engine.fuse_point(state, i, voice_raw, scam_raw, context_risk=context_risk)
        timeline.append(point)
        yield ("risk_update", point)  # §12 — one message per audio chunk
    yield ("stage", 7, "Risk timeline",
           f"{len(timeline)} pts: " + " → ".join(str(p["risk_score"]) for p in timeline))

    # 8. Policy ---------------------------------------------------------------
    action = decide(risk["risk_level"])
    lv_tier = liveness_decision(risk["risk_score"])
    yield ("stage", 8, "Policy", f"{risk['risk_level']} → {action}")

    # 9. Adaptive liveness ----------------------------------------------------
    liveness_block: Dict = {"required": False, "status": None, "challenge": None}
    if lv_tier["required"]:
        started = services.liveness_service.start_challenge(session_id)
        liveness_block = {
            "required": True,
            "status": started["status"],
            "challenge": started["challenge"],
        }
        yield ("stage", 9, "Liveness", f"{lv_tier['tier']} — challenge issued")

    # Explanation + recommendation (USP 9) ------------------------------------
    explanation: List[str] = []
    if voice_ok:
        explanation.append(
            f"[voice] Synthetic-voice evidence: spoof risk {voice['spoof_risk']:.2f} "
            f"→ {voice.get('status')} (source: {voice.get('model')})"
        )
    explanation.extend(scam.get("evidence") or [])
    explanation.append(
        f"[fused] Risk {risk['risk_score']}/100 ({risk['risk_level']}) — "
        f"weights used: {risk.get('weights_used')}"
    )
    explanation.append(f"[policy] {risk['risk_level']} → {action}")
    if liveness_block["required"]:
        explanation.append(f"[liveness] {lv_tier['tier']} challenge issued (fixed prototype phrase)")

    # Degradation bookkeeping (§20) ------------------------------------------
    fallbacks: List[str] = []
    if not voice_ok:
        fallbacks.append("voice model")
    if not asr_ok:
        fallbacks.append("ASR")
    if not scam_ok:
        fallbacks.append("scam rules")

    response = {
        "session_id": session_id,
        "status": "complete" if not fallbacks else "partial",
        "audio": {
            "duration": pre["duration_s"],
            "language": asr.get("language") if asr_ok else None,
        },
        "voice_trust": voice if voice_ok else None,
        "asr": asr if asr_ok else None,
        "scam_analysis": scam if scam_ok else None,
        "attack_types": attack_types,
        "risk": {"score": risk["risk_score"], "level": risk["risk_level"]},
        "risk_timeline": timeline,
        "liveness": liveness_block,
        "explanation": explanation,
        "recommendation": RECOMMENDATIONS[risk["risk_level"]],
        "fallback_used": bool(fallbacks),
        "error": f"degraded signals: {', '.join(fallbacks)}" if fallbacks else None,
    }
    meta = {
        "voice_tag": voice_tag,
        "asr_tag": asr_tag,
        "scam_tag": scam_tag,
        "policy_action": action,
        "liveness_tier": lv_tier["tier"],
        "pre": {k: pre[k] for k in ("duration_s", "source_sr", "channels_in")},
    }
    yield ("final", response, meta)


def analyze_audio(
    services: ServiceContainer,
    audio_path: str,
    session_id: str,
    lang: str = "hi",
    source_hint: str = "",
    on_stage: Optional[Callable[[int, str, str], None]] = None,
) -> Dict:
    """Consume stream_analysis(); return {"response", "meta"} (HTTP/demo card)."""
    response: Optional[Dict] = None
    meta: Dict = {}
    for event in stream_analysis(services, audio_path, session_id, lang, source_hint):
        if event[0] == "stage" and on_stage is not None:
            on_stage(*event[1:])
        elif event[0] == "final":
            response, meta = event[1], event[2]
    return {"response": response or {}, "meta": meta}


# ---------------------------------------------------------------------------
# Supporting features (§MESSAGE SCANNER / §URL CHECKER) — they REUSE the same
# intelligence layer (scam rules / URL heuristics + bands + policy), they do
# not fork it. For a message there is no voice/identity/context signal, so
# the scam score IS the content risk (documented, not hidden).
# ---------------------------------------------------------------------------

def analyze_message(services: ServiceContainer, text: str, session_id: str) -> Dict:
    """Message scanner (Phase 14): text → scam intent → attack types → risk.

    Returns a MessageAnalysisResponse dict; never raises (§20).
    """
    scam = services.scam_detector.analyze(text)

    attack_types = attack_types_from_indicators(scam.get("indicators") or [])
    score = round(services.risk_engine._clamp(scam.get("risk", 0.0)) * 100)
    level = services.risk_engine.band(score)
    action = decide(level)

    explanation = list(scam.get("evidence") or [])
    explanation.append(f"[fused] Content risk {score}/100 ({level}) — messages carry "
                       f"no voice/identity/context signals in the prototype")
    explanation.append(f"[policy] {level} → {action}")

    return {
        "session_id": session_id,
        "status": "complete",
        "text": text,
        "scam_analysis": scam,
        "attack_types": attack_types,
        "risk": {"score": score, "level": level},
        "policy_action": action,
        "explanation": explanation,
        "recommendation": RECOMMENDATIONS[level],
        "fallback_used": False,
        "error": None,
    }


def analyze_url(services: ServiceContainer, url: str, session_id: str) -> Dict:
    """URL checker (Phase 15): structural heuristics → risk + reasons.

    Returns a URLAnalysisResponse dict; never raises (§20).
    """
    result = services.url_checker.analyze(url)

    score = round(services.risk_engine._clamp(result.get("risk", 0.0)) * 100)
    level = services.risk_engine.band(score)
    action = decide(level)

    explanation = list(result.get("reasons") or [])
    explanation.append(f"[fused] URL risk {score}/100 ({level}) — structural heuristics only, "
                       f"no live fetching (prototype)")
    explanation.append(f"[policy] {level} → {action}")

    return {
        "session_id": session_id,
        "status": "complete",
        "url": url,
        "url_analysis": {
            "risk": result.get("risk", 0.0),
            "reasons": result.get("reasons", []),
            "model": result.get("model", "heuristic_rules"),
            "note": result.get("note"),
        },
        "risk": {"score": score, "level": level},
        "policy_action": action,
        "explanation": explanation,
        "recommendation": RECOMMENDATIONS[level],
        "fallback_used": False,
        "error": None,
    }
