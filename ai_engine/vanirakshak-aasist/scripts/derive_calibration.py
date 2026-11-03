"""
Derive domain-calibration constants from MEASURED validation scores (§22
discipline: never ship magic numbers).

Replaces the undocumented theta=8.6 / temperature=1.6 in
backend/app/ml/aasist_detector.py with values FIT to the model's actual
logit-margin distribution on a held-out validation set:

  * margin        = logit_spoof - logit_bonafide   (raw model evidence)
  * theta         = midpoint between the class medians (score 0.5 cut)
  * temperature   = scale so the sigmoid is meaningful across the spread
                    (fit so that the class quartiles map to ~0.27 / ~0.73)

Usage (from ai_engine/vanirakshak-aasist, venv active):
    python scripts/derive_calibration.py --splits data/splits/hindi \
        --model checkpoints/hindi_v1/best.pt \
        --checkpoint-tag v2

Writes:
    reports/calibration.json   (theta, temperature, distributions, per-sample)
    and prints the exact backend snippet to paste into aasist_detector.py.
"""
import argparse
import json
import os
import sys

import numpy as np
import torch
import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
sys.path.insert(0, os.path.join(ROOT, "src", "upstream_aasist"))

import soundfile as sf  # noqa: E402
import librosa  # noqa: E402

from models.AASIST import Model  # noqa: E402


def load_audio(path: str, sr: int, num_samples: int) -> np.ndarray:
    wav, file_sr = sf.read(path, dtype="float32")
    if wav.ndim > 1:
        wav = wav.mean(axis=1)
    if file_sr != sr:
        wav = librosa.resample(wav, orig_sr=file_sr, target_sr=sr)
    if len(wav) < num_samples:
        wav = np.pad(wav, (0, num_samples - len(wav)))
    return wav[:num_samples]


def collect_margins(model, device, csv_path: str, sr: int, num_samples: int):
    """Return (bonafide_margins, spoof_margins) over a split CSV."""
    import csv

    bon, spo = [], []
    with open(csv_path, newline="") as f:
        for row in csv.DictReader(f):
            wav = load_audio(row["path"], sr, num_samples)
            x = torch.FloatTensor(wav).unsqueeze(0).to(device)
            with torch.no_grad():
                _, out = model(x)
            margin = float(out[0, 0] - out[0, 1])  # spoof - bonafide
            (bon if row["label"] == "1" else spo).append(margin)
    return np.array(bon), np.array(spo)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--splits", default="data/splits/hindi")
    p.add_argument("--model", default="checkpoints/hindi_v1/best.pt")
    p.add_argument("--checkpoint-tag", default="v2")
    p.add_argument("--out", default="reports/calibration.json")
    args = p.parse_args()

    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    with open(os.path.join(ROOT, "src", "upstream_aasist", "config", "AASIST-L.conf")) as f:
        model = Model(json.load(f)["model_config"])
    state = torch.load(args.model, map_location="cpu", weights_only=True)
    model.load_state_dict(state, strict=False)
    model.to(device).eval()

    # Preprocessing config from the packaged model (single source of truth)
    prep_path = os.path.join(ROOT, "packaged", "preprocessing.yaml")
    sr, num_samples = 16000, 64600
    if os.path.exists(prep_path):
        with open(prep_path) as f:
            prep = yaml.safe_load(f)
        sr = prep.get("sample_rate", sr)
        num_samples = prep.get("input_length_samples", num_samples)

    print(f"Collecting margins on VAL split ({device}) …")
    bon_val, spo_val = collect_margins(
        model, device, os.path.join(args.splits, "val.csv"), sr, num_samples)
    print(f"Collecting margins on TEST split …")
    bon_test, spo_test = collect_margins(
        model, device, os.path.join(args.splits, "test.csv"), sr, num_samples)

    # ── Fit theta + temperature on VAL only (test stays untouched) ──────────
    theta = float((np.median(bon_val) + np.median(spo_val)) / 2)
    spread = (np.percentile(spo_val, 25) - np.percentile(bon_val, 75)) / 2
    temperature = float(max(spread, 1e-3))

    def sigmoid(x):
        return 1.0 / (1.0 + np.exp(-(x - theta) / temperature))

    report = {
        "checkpoint": args.model,
        "checkpoint_tag": args.checkpoint_tag,
        "n_val": {"bonafide": int(len(bon_val)), "spoof": int(len(spo_val))},
        "n_test": {"bonafide": int(len(bon_test)), "spoof": int(len(spo_test))},
        "theta": round(theta, 4),
        "temperature": round(temperature, 4),
        "margin_stats": {
            "val_bonafide": {"median": round(float(np.median(bon_val)), 3),
                             "p25": round(float(np.percentile(bon_val, 25)), 3),
                             "p75": round(float(np.percentile(bon_val, 75)), 3)},
            "val_spoof": {"median": round(float(np.median(spo_val)), 3),
                          "p25": round(float(np.percentile(spo_val, 25)), 3),
                          "p75": round(float(np.percentile(spo_val, 75)), 3)},
        },
        "calibrated_test": {
            "acc_at_05": round(float(np.mean(
                (sigmoid(np.concatenate([bon_test, spo_test])) < 0.5)
                == np.concatenate([np.ones(len(bon_test)), np.zeros(len(spo_test))]))
            ), 4),
        },
        "val_margins_bonafide": [round(float(x), 3) for x in sorted(bon_val)],
        "val_margins_spoof": [round(float(x), 3) for x in sorted(spo_val)],
        "derived_on": __import__("datetime").datetime.now().isoformat(),
    }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'='*60}")
    print(f"DERIVED CALIBRATION (fit on VAL, reported on TEST)")
    print(f"  theta       = {theta:.4f}")
    print(f"  temperature = {temperature:.4f}")
    print(f"  calibrated test accuracy @0.5 = {report['calibrated_test']['acc_at_05']}")
    print(f"Saved → {args.out}")
    print(f"{'='*60}")
    print("\nPaste into backend/app/ml/aasist_detector.py:")
    print(f"        theta = {theta:.4f}")
    print(f"        temperature = {temperature:.4f}")


if __name__ == "__main__":
    main()
