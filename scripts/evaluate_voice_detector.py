"""
Voice-detector evaluation harness (§EVALUATION / §22 — small and honest).

Measures the PRODUCTION VoiceDetector over a folder of labelled clips and
writes an honest per-sample table + metrics (accuracy, EER when both classes
exist). Naming convention IS the label:

    real_*  / genuine_* / bonafide_*  → bonafide (genuine speech)
    fake_*  / tts_* / synth_* / clone_* → spoof (synthetic speech)
    anything else                      → skipped with a warning

Usage (from repo root, venv active):
    python scripts/evaluate_voice_detector.py --dir demo_data
    python scripts/evaluate_voice_detector.py --dir my_eval_set --out evaluation/results

This is the Phase-A baseline your future fine-tuned model must beat
(see training/README.md). Never present these numbers as benchmark results.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "backend"))  # noqa: E402

from app.services import ServiceContainer  # noqa: E402
from app.services.audio_processor import AudioProcessor  # noqa: E402
from app.services.voice_detector import SPOOF_THRESHOLD, VoiceDetector  # noqa: E402

BONAFIDE_PREFIXES = ("real_", "genuine_", "bonafide_")
SPOOF_PREFIXES = ("fake_", "tts_", "synth_", "clone_")


def label_for(name: str):
    low = name.lower()
    if low.startswith(BONAFIDE_PREFIXES):
        return "bonafide"
    if low.startswith(SPOOF_PREFIXES):
        return "spoof"
    return None


def compute_eer(spoof_scores, bonafide_scores):
    """EER where FAR(spoof accepted as real) == FRR(real accepted as spoof).

    spoof_score = our spoof_risk (higher = more synthetic). Computed by a
    sorted-score sweep with linear interpolation. Returns None when either
    class is missing — the harness never invents an EER.
    """
    if not spoof_scores or not bonafide_scores:
        return None
    scores = np.array(spoof_scores + bonafide_scores)
    labels = np.array([1] * len(spoof_scores) + [0] * len(bonafide_scores))  # 1 = spoof

    thresholds = np.unique(scores)
    best_gap, eer = None, None
    for i, t in enumerate(thresholds):
        far = float((scores[labels == 0] >= t).mean())  # real → flagged fake
        frr = float((scores[labels == 1] < t).mean())   # fake → passed as real
        gap = far - frr
        if best_gap is None or abs(gap) < abs(best_gap[0]):
            best_gap = (gap, far, frr, t)
        # linear interpolation when the sign flips between adjacent thresholds
        if i > 0:
            prev_far = float((scores[labels == 0] >= thresholds[i - 1]).mean())
            prev_frr = float((scores[labels == 1] < thresholds[i - 1]).mean())
            if (prev_far - prev_frr) * gap <= 0 and prev_far != prev_frr:
                d = (prev_far - prev_frr) - gap
                frac = 0.0 if d == 0 else (prev_far - prev_frr) / d
                eer = prev_far + frac * (far - prev_far)
                break
    if eer is None and best_gap is not None:
        eer = best_gap[1]  # degenerate small sets: report the closest point
    return round(float(eer), 4) if eer is not None else None


def main() -> int:
    parser = argparse.ArgumentParser(description="VoiceDetector evaluation harness")
    parser.add_argument("--dir", default="demo_data", help="folder with labelled clips")
    parser.add_argument("--out", default="evaluation/results", help="results output dir")
    args = parser.parse_args()

    folder = Path(args.dir)
    if not folder.is_dir():
        print(f"Folder not found: {folder}")
        return 1

    samples = []
    skipped = []
    for path in sorted(folder.iterdir()):
        if not path.is_file() or path.suffix.lower() not in (".wav", ".mp3", ".flac", ".ogg", ".aiff", ".aif"):
            continue
        label = label_for(path.name)
        if label is None:
            skipped.append(path.name)
            continue
        samples.append((path, label))

    print(f"VoiceDetector evaluation — {len(samples)} labelled clip(s) in {folder}")
    for name in skipped:
        print(f"  skipped (no real_/fake_ prefix): {name}")
    if not samples:
        print("Nothing to evaluate. Name files real_* (genuine) or fake_/tts_* (synthetic).")
        return 0

    services = ServiceContainer.create()
    if not services.voice_detector.load_model():
        print("Voice model unavailable — cannot evaluate (would be demo-mode fake numbers).")
        return 1
    processor = AudioProcessor()

    rows, spoof_scores, bonafide_scores = [], [], []
    for path, label in samples:
        pre = processor.preprocess(path)
        if not pre.get("ok"):
            rows.append({"file": path.name, "label": label, "error": pre.get("error")})
            continue
        out = services.voice_detector.predict(pre["waveform"])
        score = out.get("spoof_risk")
        if score is None:
            rows.append({"file": path.name, "label": label, "error": "no score (fallback)"})
            continue
        prediction = "spoof" if score >= SPOOF_THRESHOLD else "bonafide"
        correct = prediction == label
        (spoof_scores if label == "spoof" else bonafide_scores).append(score)
        rows.append({
            "file": path.name, "label": label, "spoof_score": score,
            "prediction": prediction, "correct": correct,
        })

    labelled = [r for r in rows if "spoof_score" in r]
    errors = [r for r in rows if "error" in r]
    eer = compute_eer(spoof_scores, bonafide_scores)

    # ------------------------------------------------------------- report
    lines = []
    lines.append(f"# VoiceDetector evaluation — {time.strftime('%Y-%m-%d %H:%M')}")
    lines.append("")
    lines.append(f"Clips: {len(labelled)} scored, {len(errors)} errored, "
                 f"{len(skipped)} skipped (no label prefix)")
    lines.append(f"Model: {services.voice_detector.model._get_name() if services.voice_detector.model else '?'} "
                 f"(pretrained baseline — NOT validated on Indian-language speech)")
    lines.append(f"Threshold: {SPOOF_THRESHOLD} (uncalibrated prototype cut)")
    lines.append("")
    n_spoof, n_bona = len(spoof_scores), len(bonafide_scores)
    lines.append(f"- spoof clips: {n_spoof} — flagged: "
                 f"{sum(1 for r in labelled if r['label'] == 'spoof' and r['prediction'] == 'spoof')}")
    lines.append(f"- bonafide clips: {n_bona} — passed: "
                 f"{sum(1 for r in labelled if r['label'] == 'bonafide' and r['prediction'] == 'bonafide')}")
    if eer is not None:
        lines.append(f"- **EER: {eer}** (computed on this tiny set — prototype measurement, "
                     f"not a benchmark)")
    else:
        lines.append(f"- EER: **not computable** — need BOTH classes "
                     f"(add real_* genuine recordings; see evaluation/README.md)")
    lines.append("")
    lines.append("| file | expected | spoof score | prediction | correct |")
    lines.append("|---|---|---|---|---|")
    for r in labelled:
        lines.append(f"| {r['file']} | {r['label']} | {r['spoof_score']:.4f} | "
                     f"{r['prediction']} | {'✅' if r['correct'] else '❌'} |")
    for r in errors:
        lines.append(f"| {r['file']} | {r.get('label')} | — | error: {r['error']} | — |")
    lines.append("")
    lines.append("*PROTOTYPE measurement on a tiny set — never a benchmark claim (§22).*")

    report = "\n".join(lines)
    print()
    print(report)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    (out_dir / f"voice_eval_{stamp}.json").write_text(json.dumps(
        {"rows": rows, "spoof_scores": spoof_scores, "bonafide_scores": bonafide_scores,
         "eer": eer, "threshold": SPOOF_THRESHOLD}, indent=2))
    (out_dir / f"voice_eval_{stamp}.md").write_text(report + "\n")
    print(f"\nSaved: {out_dir}/voice_eval_{stamp}.json + .md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
