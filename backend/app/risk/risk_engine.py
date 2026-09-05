"""
RiskEngine — dynamic risk fusion (§DYNAMIC RISK SCORE, §RISK FUSION).
Phase 9: the v3 5-signal weighted fusion + per-chunk risk_timeline.

PROTOTYPE weights (master prompt):
    risk = 0.30*voice + 0.20*identity + 0.30*scam + 0.10*context + 0.10*liveness
These are DEMO weights only — never claim scientific calibration. FUTURE
PRODUCT: a calibrated model (logistic regression / gradient boosting /
temporal fusion) replaces this class behind the same interface.

Honesty rules (the engine never invents evidence):
  * A signal with NO value yet — identity until Phase 16, liveness until a
    challenge actually runs — is EXCLUDED and the remaining weights are
    renormalized across the signals that ARE present. `weights_used` in the
    output makes this transparent (good judge moment).
  * Bands: LOW 0–39 · MEDIUM 40–69 · HIGH 70–84 · CRITICAL 85–100 — prototype
    bands aligned with the liveness tiers (risk<40 no challenge, 40–69
    monitor, 70–84 consider challenge, ≥85 mandatory).

Risk(t) (§DYNAMIC RISK SCORE): `fuse_timeline()` computes a risk point per
~1 s chunk. Scam evidence PERSISTS once uttered (running max) — matching the
conceptual Risk(t+1) = Risk(t) + new evidence. Voice per point comes from the
caller (sliding ~4 s windows — 1 s windows are out-of-distribution for AASIST;
this caveat must be stated, the timeline is prototype-grade).
"""
from typing import Dict, List, Optional

# §DYNAMIC RISK SCORE fixed prototype weights (demo only)
WEIGHTS: Dict[str, float] = {
    "voice": 0.30,
    "identity": 0.20,
    "scam": 0.30,
    "context": 0.10,
    "liveness": 0.10,
}

# Prototype bands (§API contract deltas): LOW 0–39 · MEDIUM 40–69 ·
# HIGH 70–84 · CRITICAL 85–100
BANDS: List[tuple] = [(39, "LOW"), (69, "MEDIUM"), (84, "HIGH")]  # else CRITICAL

# Prototype mapping of liveness outcomes onto a 0–1 risk signal (§ADAPTIVE
# LIVENESS — "liveness should be inside the decision loop"). Documented demo
# semantics, not calibrated.
LIVENESS_TO_RISK: Dict[str, float] = {
    "PASSED": 0.0,
    "SUSPICIOUS": 0.7,
    "FAILED": 1.0,
}


class RiskEngine:
    """Stateless fusion component — no model to load (reported in /api/health)."""

    has_model = False

    # ------------------------------------------------------------- final score

    def fuse(
        self,
        voice_risk: Optional[float] = None,
        scam_risk: Optional[float] = None,
        context_risk: Optional[float] = None,
        identity_risk: Optional[float] = None,
        liveness_risk: Optional[float] = None,
    ) -> Dict:
        """Fuse 0–1 risk signals into a 0–100 score + 4-tier level.

        Signals that are None (no evidence yet) are excluded and the weights
        of the present signals are renormalized — see module docstring.
        """
        signals = {
            "voice": voice_risk,
            "identity": identity_risk,
            "scam": scam_risk,
            "context": context_risk,
            "liveness": liveness_risk,
        }
        present = {k: self._clamp(v) for k, v in signals.items() if v is not None}

        if not present:  # no evidence at all — honest zero, not a guess
            return {
                "risk_score": 0,
                "risk_level": self.band(0),
                "signals": signals,
                "weights_used": {},
            }

        total_weight = sum(WEIGHTS[k] for k in present)
        risk = sum(WEIGHTS[k] * v for k, v in present.items()) / total_weight
        score = round(self._clamp(risk) * 100)
        return {
            "risk_score": score,
            "risk_level": self.band(score),
            "signals": signals,
            "weights_used": {k: round(WEIGHTS[k] / total_weight, 4) for k in present},
        }

    # --------------------------------------------------------------- Risk(t)

    def fuse_point(
        self,
        state: Dict,
        t: float,
        voice_raw: Optional[float] = None,
        scam_raw: Optional[float] = None,
        context_risk: Optional[float] = None,
        identity_risk: Optional[float] = None,
        liveness_risk: Optional[float] = None,
    ) -> Dict:
        """Fuse ONE chunk observation, carrying evidence forward via `state`.

        Evidence accumulates (§DYNAMIC RISK SCORE: Risk(t+1) = Risk(t) + new
        evidence): scam = running max; voice = running max (CAVEAT, stated in
        docs/demo: a single noisy window persists; a temporal model replaces
        this in the future). The returned point records the RAW voice
        observation. Pass the same `state` dict across chunks; missing values
        (never measured) are excluded, not guessed.
        """
        if scam_raw is not None:
            state["max_scam"] = max(state.get("max_scam", 0.0), self._clamp(scam_raw))
            state["seen_scam"] = True  # a measured signal — even a 0.0 — counts
        if voice_raw is not None:
            v = self._clamp(voice_raw)
            state["max_voice"] = v if state.get("max_voice") is None else max(state["max_voice"], v)

        fused = self.fuse(
            voice_risk=state.get("max_voice"),
            scam_risk=state.get("max_scam") if state.get("seen_scam") else None,
            context_risk=context_risk,
            identity_risk=identity_risk,
            liveness_risk=liveness_risk,
        )
        return {
            "t": float(t),
            "voice_risk": voice_raw,  # RAW observation; fusion used the accumulators
            "scam_risk": round(state.get("max_scam", 0.0), 4) if state.get("seen_scam") else None,
            "risk_score": fused["risk_score"],
            "level": fused["risk_level"],
        }

    def fuse_timeline(
        self,
        voice_risks: List[Optional[float]],
        scam_risks: List[Optional[float]],
        context_risk: Optional[float] = None,
        identity_risk: Optional[float] = None,
        liveness_risk: Optional[float] = None,
    ) -> List[Dict]:
        """Batch form of fuse_point — one fusion point per chunk index."""
        state: Dict = {}
        return [
            self.fuse_point(state, t, v, s,
                            context_risk=context_risk,
                            identity_risk=identity_risk,
                            liveness_risk=liveness_risk)
            for t, (v, s) in enumerate(zip(voice_risks, scam_risks))
        ]

    # ---------------------------------------------------------------- helpers

    def liveness_to_risk(self, status: Optional[str]) -> Optional[float]:
        """Map a liveness state to a 0–1 risk signal (documented demo mapping)."""
        if status is None:
            return None
        return LIVENESS_TO_RISK.get(status)

    @staticmethod
    def band(score: int) -> str:
        for ceiling, label in BANDS:
            if score <= ceiling:
                return label
        return "CRITICAL"

    @staticmethod
    def _clamp(v: float) -> float:
        return max(0.0, min(1.0, float(v)))
